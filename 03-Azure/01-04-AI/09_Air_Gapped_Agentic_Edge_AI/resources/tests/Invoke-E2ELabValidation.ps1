#Requires -Version 7.0
<#
.SYNOPSIS
End-to-End Automated Validation Runner for Air-Gapped Agentic AI: Orchestrating Local SLMs and IoT on Edge Kubernetes.
.DESCRIPTION
Supports two validation modes:
  1. -Mode Offline (Default, <10 seconds, zero Azure cost):
     - Compiles resources/infra/main.bicep via 'az bicep build'
     - Validates PowerShell syntax on labautomation/*.ps1 and JSON schema on lab-defaults.json
     - Validates all relative Markdown links across challenges and walkthroughs
     - Runs the Python closed-loop simulation test suite (test-local-simulation.py)
  2. -Mode LiveAzure (Full unattended cloud deployment + Challenge 01-05 execution):
     - Registers required Azure Resource Providers
     - Deploys resources/infra/main.bicep (fast-k3s profile) into -ResourceGroupName
     - Uses 'az vm run-command invoke' to execute Challenges 01-05 unattended on the K3s VM
     - Optionally cleans up the test Resource Group when -CleanupOnSuccess is set
.EXAMPLE
./Invoke-E2ELabValidation.ps1 -Mode Offline
.EXAMPLE
./Invoke-E2ELabValidation.ps1 -Mode LiveAzure -SubscriptionId <sub-id> -ResourceGroupName rg-edgeai-e2e -Location eastus2 -CleanupOnSuccess
#>
[CmdletBinding()]
param(
    [ValidateSet('Offline', 'LiveAzure')]
    [string]$Mode = 'Offline',

    [string]$SubscriptionId,

    [string]$ResourceGroupName = 'rg-edgeai-e2e-validation',

    [string]$Location = 'swedencentral',

    [switch]$CleanupOnSuccess
)

$ErrorActionPreference = 'Stop'
$microHackRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Air-Gapped Agentic Edge AI — Automated Validation ($Mode Mode)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# Phase 1: Static & Offline Simulation Checks (Always Run)
# ----------------------------------------------------------------------------
Write-Host "`n[1/4] Compiling Bicep template (resources/infra/main.bicep)..." -ForegroundColor Yellow
$bicepFile = Join-Path $microHackRoot 'resources\infra\main.bicep'
az bicep build --file $bicepFile --stdout | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Bicep compilation failed for $bicepFile"
}
Write-Host "  -> Bicep template compiled with 0 errors." -ForegroundColor Green

Write-Host "`n[2/4] Validating PowerShell & JSON labautomation artifacts..." -ForegroundColor Yellow
$psFiles = @(
    Join-Path $microHackRoot 'labautomation\deploy-lab.ps1'
    Join-Path $microHackRoot 'labautomation\shared-deploy-lab.ps1'
)
foreach ($psFile in $psFiles) {
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($psFile, [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell syntax error in ${psFile}: $($parseErrors | Out-String)"
    }
}
$labDefaults = Get-Content (Join-Path $microHackRoot 'labautomation\lab-defaults.json') -Raw | ConvertFrom-Json
if ($labDefaults.deploymentType -ne 'resourcegroup-with-subscriptionowner') {
    throw "Expected deploymentType 'resourcegroup-with-subscriptionowner' in lab-defaults.json"
}
Write-Host "  -> PowerShell scripts & lab-defaults.json valid." -ForegroundColor Green

Write-Host "`n[3/5] Checking all relative Markdown links & PR file-structure compliance..." -ForegroundColor Yellow
$mdFiles = Get-ChildItem -Path $microHackRoot -Recurse -Filter *.md
$brokenLinks = @()
foreach ($md in $mdFiles) {
    $content = Get-Content $md.FullName -Raw
    $matches = [regex]::Matches($content, '\[[^\]]+\]\(([^)#]+)(?:#[^)]*)?\)')
    foreach ($m in $matches) {
        $target = $m.Groups[1].Value.Trim()
        if ($target -notmatch '^(https?|mailto):') {
            $resolved = Join-Path $md.DirectoryName $target
            if (-not (Test-Path $resolved)) {
                $brokenLinks += "$($md.Name) -> $target"
            }
        }
    }
}
if ($brokenLinks.Count -gt 0) {
    throw "Broken Markdown links detected:`n$($brokenLinks -join "`n")"
}
$repoRoot = Resolve-Path (Join-Path $microHackRoot '..\..\..')
$complianceScript = Join-Path $repoRoot '.github\scripts\check_file_structure.py'
if (Test-Path $complianceScript) {
    $env:PYTHONIOENCODING = 'utf-8'
    $relFiles = Get-ChildItem -Path $microHackRoot -Recurse -File | ForEach-Object {
        [System.IO.Path]::GetRelativePath($repoRoot.Path, $_.FullName).Replace('\', '/')
    }
    $relFiles | python $complianceScript | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Repository PR compliance check (check_file_structure.py) failed."
    }
    $resultsReport = Join-Path (Get-Location).Path 'structure-check-results.md'
    if (Test-Path $resultsReport) { Remove-Item $resultsReport -Force }
}
Write-Host "  -> All relative links across $($mdFiles.Count) Markdown files & PR structure compliance verified." -ForegroundColor Green

Write-Host "`n[4/5] Running Closed-Loop Edge Agent + SAT Auth + SOP Simulation Suite..." -ForegroundColor Yellow
$pyTestScript = Join-Path $PSScriptRoot 'test-local-simulation.py'
python $pyTestScript
if ($LASTEXITCODE -ne 0) {
    throw "Python closed-loop simulation test suite failed."
}
Write-Host "  -> Closed-loop simulation tests passed!" -ForegroundColor Green

if ($Mode -eq 'Offline') {
    Write-Host "`nSUCCESS: All Offline & Closed-Loop Simulation checks passed!" -ForegroundColor Green
    return
}

# ----------------------------------------------------------------------------
# Phase 2: Live Azure Unattended E2E Provisioning & Challenge Runner
# ----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $SubscriptionId = (az account show --query id -o tsv)
}
Write-Host "`n[LiveAzure 1/4] Setting subscription $SubscriptionId and creating RG $ResourceGroupName in $Location..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
az group create --name $ResourceGroupName --location $Location --output none

$adminPassword = "EdgeAiLab!$(Get-Random -Minimum 100000 -Maximum 999999)aA"
Write-Host "[LiveAzure 2/4] Deploying resources/infra/main.bicep (fast-k3s profile, deployBastion=false for unattended speed)..." -ForegroundColor Yellow
$deployJson = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepFile `
    --parameters edgeProfile=fast-k3s deployBastion=false adminPasswordOrKey=$adminPassword `
    --query "properties.outputs" -o json | ConvertFrom-Json

$vmName = $deployJson.edgeVmName.value
$arcClusterName = $deployJson.arcClusterSuggestedName.value
$storageName = $deployJson.schemaStorageAccountName.value
$uamiClientId = $deployJson.userAssignedIdentityClientId.value

Write-Host "  -> Provisioned VM: $vmName | Suggested Arc Cluster: $arcClusterName | Storage: $storageName" -ForegroundColor Green

$clOid = az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv 2>$null

Write-Host "[LiveAzure 3/4] Uploading manifests & executing unattended Challenge 01-05 verification inside $vmName..." -ForegroundColor Yellow
$e2eShellScript = (Get-Content (Join-Path $PSScriptRoot 'run-challenges-e2e.sh') -Raw) -replace "`r`n", "`n"
$lfTempScript = Join-Path $env:TEMP 'run-challenges-e2e-lf.sh'
[System.IO.File]::WriteAllText($lfTempScript, $e2eShellScript, [System.Text.UTF8Encoding]::new($false))

$runResult = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $vmName `
    --command-id RunShellScript `
    --scripts "@$lfTempScript" `
    --parameters "SUBSCRIPTION_ID=$SubscriptionId" "RESOURCE_GROUP=$ResourceGroupName" "ARC_LOCATION=westeurope" "CLUSTER_NAME=$arcClusterName" "SCHEMA_STORAGE_ACCOUNT=$storageName" "UAMI_CLIENT_ID=$uamiClientId" "CUSTOM_LOCATIONS_OID=$clOid" `
    --query "value[0].message" -o tsv

Write-Host $runResult
if ($runResult -notmatch 'E2E_ALL_CHALLENGES_PASSED') {
    throw "LiveAzure E2E challenge execution did not report E2E_ALL_CHALLENGES_PASSED."
}

if ($CleanupOnSuccess) {
    Write-Host "[LiveAzure 4/4] Cleaning up Resource Group $ResourceGroupName (--no-wait)..." -ForegroundColor Yellow
    az group delete --name $ResourceGroupName --yes --no-wait
}

Write-Host "`nSUCCESS: LiveAzure End-to-End MicroHack validation passed!" -ForegroundColor Green
