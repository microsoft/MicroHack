<#
.SYNOPSIS
Prepare tools inside Azure Cloud Shell and deploy into the participant's existing project.
.DESCRIPTION
Requires Cloud Shell PowerShell and its existing Azure CLI/Python sign-in.
Does not install software on the participant's computer, assign roles, or provision infrastructure.
#>
#Requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [string]$SubscriptionId,
    [uri]$ProjectEndpoint,
    [string]$FabricIQConnectionName,
    [string]$DemandAgentName = 'demand-sensing-agent',
    [string]$OptimisationAgentName = 'inventory-optimisation-agent',
    [string]$ReplenishmentAgentName = 'replenishment-action-agent',
    [string]$EnvironmentName = 'inventory-hosted',
    [switch]$VerifyHosted,
    [switch]$ConfigureOnly
)
$ErrorActionPreference = 'Stop'
if (-not $IsLinux) { throw 'Run this bootstrap in Azure Cloud Shell (PowerShell), not on your computer.' }
if ($VerifyHosted -and $ConfigureOnly) { throw '-VerifyHosted cannot be combined with -ConfigureOnly.' }
foreach ($tool in @('az', 'python3', 'bash')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is missing from this Cloud Shell. Use a supported Azure Cloud Shell session."
    }
}
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}
$subscription = az account show --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $subscription) {
    throw 'Cannot read the Cloud Shell subscription. Sign in to Cloud Shell with the lab account and rerun.'
}
if (-not $SubscriptionId) { $SubscriptionId = $subscription }
if ($subscription -ne $SubscriptionId) {
    throw 'Select the assigned lab subscription with az account set before continuing.'
}
if (-not $ProjectEndpoint) {
    $projects = @(az resource list --resource-group $ResourceGroupName `
        --resource-type Microsoft.CognitiveServices/accounts/projects --query '[].name' -o tsv)
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot list Foundry projects in resource group '$ResourceGroupName'. Check the name on your lab dashboard."
    }
    $projects = @($projects | Where-Object { $_ })
    if ($projects.Count -ne 1) {
        throw "Expected exactly one Foundry project in '$ResourceGroupName' but found $($projects.Count). Pass -ProjectEndpoint from your lab dashboard."
    }
    $found = "$($projects[0])" -split '/'
    $ProjectEndpoint = [uri]"https://$($found[0]).services.ai.azure.com/api/projects/$($found[1])"
}
if ($ProjectEndpoint.AbsoluteUri.TrimEnd('/') -notmatch '^https://(?<Account>[a-z0-9-]+)\.services\.ai\.azure\.com/api/projects/(?<Project>[a-zA-Z0-9_-]+)$') {
    throw 'Use the FoundryProjectEndpoint supplied by the lab dashboard.'
}
$accountName, $projectName = $Matches.Account, $Matches.Project
$accountId = az resource list --resource-group $ResourceGroupName `
    --resource-type Microsoft.CognitiveServices/accounts --query "[?name=='$accountName'].id | [0]" -o tsv
if ($LASTEXITCODE -ne 0 -or -not $accountId) {
    throw 'The dashboard project account was not found in the supplied lab resource group.'
}
$projectId = az resource show --ids "$accountId/projects/$projectName" --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $projectId) { throw 'Cannot read the existing lab Foundry project.' }
if (-not $FabricIQConnectionName) {
    $connections = @(az rest --method get --url "$($ProjectEndpoint.AbsoluteUri.TrimEnd('/'))/connections" `
        --uri-parameters api-version=v1 --resource https://ai.azure.com `
        --query "value[?metadata.type=='fabric_iq_preview'].name" -o tsv)
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot list the project connections. Pass -FabricIQConnectionName (the name shown next to Fabric IQ under Tools on your agents).'
    }
    $connections = @($connections | Where-Object { $_ })
    if ($connections.Count -eq 0) {
        throw 'No Fabric IQ connection found in your project. Add Fabric IQ to your demand-sensing-agent in Challenge 2, save it, and rerun.'
    }
    if ($connections.Count -gt 1) {
        throw "More than one Fabric IQ connection found: $($connections -join ', '). Rerun with -FabricIQConnectionName '<one of these>'."
    }
    $FabricIQConnectionName = $connections[0]
}
Write-Host "Project: $($ProjectEndpoint.AbsoluteUri.TrimEnd('/'))"
Write-Host "Fabric IQ connection: $FabricIQConnectionName"

$bootstrap = Join-Path $PSScriptRoot '.azure/bootstrap'
$bin = Join-Path $bootstrap 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$env:PATH = "$bin$([IO.Path]::PathSeparator)$env:PATH"
$env:AZD_CONFIG_DIR = Join-Path $bootstrap 'azd-config'
$azd = Get-Command azd -ErrorAction SilentlyContinue
$version = if ($azd) { azd version } else { '' }
if ($azd -and $LASTEXITCODE -ne 0) { throw 'Cannot read the installed azd version.' }
$match = [regex]::Match(($version -join "`n"), '\d+\.\d+\.\d+')
if (-not $match.Success -or [version]$match.Value -lt [version]'1.34.2') {
    $installer = Join-Path $bootstrap 'install-azd.sh'
    Invoke-WebRequest 'https://aka.ms/install-azd.sh' -OutFile $installer
    Invoke-Checked 'bash' @($installer, '--version', '1.34.2', '--install-folder', $bin, '--symlink-folder', $bin)
}
Invoke-Checked 'azd' @('config', 'set', 'auth.useAzCliAuth', 'true')
$extensions = azd extension list --output json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect azd extensions.' }
$installed = $extensions | ConvertFrom-Json
foreach ($required in @(
    @{ Id = 'azure.ai.agents'; Version = '1.0.0-beta.19' },
    @{ Id = 'azure.ai.projects'; Version = '1.0.0-beta.13' }
)) {
    $current = ($installed | Where-Object id -eq $required.Id).installedVersion
    if (-not $current -or [System.Management.Automation.SemanticVersion]$current -lt [System.Management.Automation.SemanticVersion]$required.Version) {
        Invoke-Checked 'azd' @('extension', 'install', $required.Id, '--version', $required.Version)
    }
}
azd auth login --check-status
if ($LASTEXITCODE -ne 0) {
    throw 'Cloud Shell Azure CLI authentication is unavailable. Reopen Cloud Shell under the assigned lab account and refresh its sign-in, then rerun. No TAP belongs in this script or terminal.'
}

Invoke-Checked 'python3' @('-c', 'import sys; assert sys.version_info >= (3, 10), "Cloud Shell Python 3.10+ is required"')
$venv = Join-Path $PSScriptRoot '.venv-tools'
$python = Join-Path $venv 'bin/python'
if (-not (Test-Path -LiteralPath $python)) { Invoke-Checked 'python3' @('-m', 'venv', $venv) }
$requirements = Join-Path $PSScriptRoot 'requirements-tools.txt'
$marker = Join-Path $venv 'requirements.sha256'
$hash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash
if (-not (Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne $hash) {
    Invoke-Checked $python @('-m', 'pip', 'install', '-r', $requirements)
    Set-Content -LiteralPath $marker -Value $hash
}
$env:FOUNDRY_PROJECT_ENDPOINT = $ProjectEndpoint.AbsoluteUri.TrimEnd('/')
$env:DEMAND_AGENT_NAME = $DemandAgentName
$env:OPTIMISATION_AGENT_NAME = $OptimisationAgentName
$env:REPLENISHMENT_AGENT_NAME = $ReplenishmentAgentName
$raw = & $python (Join-Path $PSScriptRoot 'configure_specialists.py') --resolve-only
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve the latest saved specialist versions.' }
$pins = ($raw -join "`n") | ConvertFrom-Json
$parameters = @{
    SubscriptionId = $SubscriptionId
    ProjectResourceId = $projectId.Trim()
    ProjectEndpoint = $ProjectEndpoint
    FabricIQConnectionName = $FabricIQConnectionName
    PythonExecutable = $python
    EnvironmentName = $EnvironmentName
    DemandAgentName = $DemandAgentName
    DemandAgentVersion = $pins.DEMAND_AGENT_VERSION
    OptimisationAgentName = $OptimisationAgentName
    OptimisationAgentVersion = $pins.OPTIMISATION_AGENT_VERSION
    ReplenishmentAgentName = $ReplenishmentAgentName
    ReplenishmentAgentVersion = $pins.REPLENISHMENT_AGENT_VERSION
    Deploy = -not $ConfigureOnly
    VerifyHosted = $VerifyHosted
}
Write-Host "Using saved specialist versions: demand $($pins.DEMAND_AGENT_VERSION), optimisation $($pins.OPTIMISATION_AGENT_VERSION), replenishment $($pins.REPLENISHMENT_AGENT_VERSION)."
& (Join-Path $PSScriptRoot 'Deploy-Orchestrator.ps1') @parameters
