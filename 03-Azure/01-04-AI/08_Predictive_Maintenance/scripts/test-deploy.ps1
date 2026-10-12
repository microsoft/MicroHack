#!/usr/bin/env pwsh
# =============================================================================
# LOCAL DEVELOPMENT / TESTING ONLY
# =============================================================================
# Simulates the Hackbox platform runner in a local PowerShell environment.
# Deploys main.bicep and executes the automatic data seeding logic.
#
# This harness is intended solely for local authoring validation and is NOT
# invoked by the Hack Console platform.
# =============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroupName = "rg-pdm-localtest",

    [Parameter()]
    [string]$Location = "swedencentral",

    [Parameter()]
    [string]$SubscriptionId = "",

    [Parameter()]
    [hashtable]$Tag = @{}
)

$ErrorActionPreference = "Stop"

# 1. Verify Azure CLI login
$accountJson = az account show 2>$null
if (-not $accountJson) {
    Write-Host "Please log in to Azure with 'az login' before running this test." -ForegroundColor Yellow
    az login --use-device-code
}

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $SubscriptionId = (az account show --query id -o tsv).Trim()
}

$userObjectId = (az ad signed-in-user show --query id -o tsv 2>$null)
if (-not $userObjectId) {
    # If signed in as Service Principal or guest, fetch current user ID or fallback
    $userObjectId = (az account show --query "user.name" -o tsv).Trim()
}

$script:additionalTags = $Tag

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Testing deploy-lab.ps1 locally" -ForegroundColor Cyan
Write-Host "Subscription:   $SubscriptionId" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Location:       $Location" -ForegroundColor Cyan
Write-Host "User Object ID: $userObjectId" -ForegroundColor Cyan
if ($Tag.Count -gt 0) {
    $tagSummary = ($Tag.Keys | ForEach-Object { "$_=$($Tag[$_])" }) -join ', '
    Write-Host "Extra RG Tags:  $tagSummary" -ForegroundColor Cyan
}
Write-Host "==================================================" -ForegroundColor Cyan

# 2. Mock Get-MhhStablehash if not provided by platform module
if (-not (Get-Command Get-MhhStablehash -ErrorAction SilentlyContinue)) {
    function Get-MhhStablehash {
        param(
            [Parameter(Mandatory=$true)]
            [string[]]$Value,
            [int]$Length = 12
        )
        $raw = ($Value -join ',').ToLowerInvariant()
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
        $hashBytes = $md5.ComputeHash($bytes)
        $hex = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
        if ($Length -gt $hex.Length) { return $hex }
        return $hex.Substring(0, $Length)
    }
}

# 3. Mock Invoke-MhhDeploymentWithRegionFallback using Azure CLI
if (-not (Get-Command Invoke-MhhDeploymentWithRegionFallback -ErrorAction SilentlyContinue)) {
    function Invoke-MhhDeploymentWithRegionFallback {
        param(
            [string[]]$PreferredLocations,
            [string]$ResourceGroupName,
            [string[]]$RgOwnerEntraObjectIds,
            [hashtable]$Tag,
            [string]$TemplateFile,
            [hashtable]$TemplateParameterObject
        )
        
        $chosenLocation = if ($PreferredLocations.Count -gt 0) { $PreferredLocations[0] } else { "swedencentral" }

        # Merge tags passed in by deploy-lab.ps1 (e.g. CostControl/SecurityControl)
        # with any additional tags supplied to test-deploy.ps1 via -Tag, so local
        # runs can add tags required by subscription policies (e.g. policy exemptions).
        $mergedTags = @{}
        foreach ($k in $Tag.Keys) { $mergedTags[$k] = $Tag[$k] }
        foreach ($k in $script:additionalTags.Keys) { $mergedTags[$k] = $script:additionalTags[$k] }

        Write-Host "Creating/Ensuring Resource Group '$ResourceGroupName' in '$chosenLocation'..." -ForegroundColor Green
        if ($mergedTags.Count -gt 0) {
            $tagArgs = $mergedTags.Keys | ForEach-Object { "$_=$($mergedTags[$_])" }
            Write-Host "Applying tags: $($tagArgs -join ', ')" -ForegroundColor Green
            az group create --name $ResourceGroupName --location $chosenLocation --tags $tagArgs --output none
        } else {
            az group create --name $ResourceGroupName --location $chosenLocation --output none
        }
        
        # Build parameter arguments for az deployment
        $paramArgs = @()
        foreach ($k in $TemplateParameterObject.Keys) {
            $val = $TemplateParameterObject[$k]
            $paramArgs += "$k=$val"
        }
        
        $deploymentName = "mhh-test-" + (Get-Date -Format "yyyyMMddHHmmss")
        Write-Host "Deploying Bicep template '$TemplateFile' as '$deploymentName'..." -ForegroundColor Green
        
        $jsonResult = az deployment group create `
            --resource-group $ResourceGroupName `
            --name $deploymentName `
            --template-file $TemplateFile `
            --parameters $paramArgs `
            --query "{outputs: properties.outputs}" `
            --output json
            
        $parsed = $jsonResult | ConvertFrom-Json
        
        # Flatten outputs: { "name": { "value": "val" } } -> { "name": "val" }
        $flatOutputs = @{}
        if ($parsed.outputs) {
            foreach ($prop in $parsed.outputs.PSObject.Properties) {
                $flatOutputs[$prop.Name] = $prop.Value.value
            }
        }
        
        return @{
            Success = $true
            LocationUsed = $chosenLocation
            DeploymentName = $deploymentName
            Outputs = $flatOutputs
        }
    }
}

# 4. Invoke deploy-lab.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$deployLabScript = Join-Path (Resolve-Path (Join-Path $scriptDir "..\labautomation")) "deploy-lab.ps1"

Write-Host "Executing deploy-lab.ps1 at '$deployLabScript'..." -ForegroundColor Green

# Append a synthetic second entry derived from -ResourceGroupName to the hash
# input. Get-MhhStablehash hashes the whole array to compute globally-unique
# resource names, but only $AllowedEntraUserIds[0] (the real user object ID) is
# used for RBAC/portal access. This lets repeated local test runs target a new
# resource group without colliding on already-provisioned globally-unique
# resource names (storage account, AI Search, Cognitive Services subdomain)
# left over from a previous test resource group.
$testNamingSeed = "test-seed-$ResourceGroupName"

& $deployLabScript `
    -DeploymentType "resourcegroup" `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -PreferredLocation @($Location) `
    -AllowedEntraUserIds @($userObjectId, $testNamingSeed)

Write-Host "`n✅ Local deployment & data seeding simulation completed!" -ForegroundColor Green
