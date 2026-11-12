<#
.SYNOPSIS
Deploy the optional hosted assistant into the caller's EXISTING lab project.
.DESCRIPTION
Does not provision a replacement Foundry account, model or Fabric capacity.
Verify the specialist versions and their Fabric IQ access before running.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ProjectResourceId,
    [Parameter(Mandatory)][uri]$ProjectEndpoint,
    [Parameter(Mandatory)][string]$DemandAgentName,
    [Parameter(Mandatory)][string]$DemandAgentVersion,
    [Parameter(Mandatory)][string]$OptimisationAgentName,
    [Parameter(Mandatory)][string]$OptimisationAgentVersion,
    [Parameter(Mandatory)][string]$ReplenishmentAgentName,
    [Parameter(Mandatory)][string]$ReplenishmentAgentVersion,
    [string]$EnvironmentName = 'inventory-hosted',
    [string]$PythonExecutable,
    [string]$FabricIQConnectionName,
    [switch]$Deploy,
    [switch]$VerifyHosted
)
$ErrorActionPreference = 'Stop'
if (-not $PythonExecutable) {
    $relativePython = if ($IsWindows) { '.venv\Scripts\python.exe' } else { '.venv/bin/python' }
    $PythonExecutable = Join-Path $PSScriptRoot $relativePython
}
if ($ProjectEndpoint.Scheme -ne 'https') { throw 'ProjectEndpoint must use HTTPS.' }
$prefix = "/subscriptions/$SubscriptionId/resourceGroups/"
if (-not $ProjectResourceId.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ProjectResourceId does not belong to the requested subscription.'
}
if ($ProjectResourceId -notmatch '/providers/Microsoft\.CognitiveServices/accounts/(?<Account>[^/]+)/projects/(?<Project>[^/]+)$') {
    throw 'ProjectResourceId must identify an existing Foundry account project.'
}
$expectedEndpoint = "https://$($Matches.Account).services.ai.azure.com/api/projects/$($Matches.Project)"
if ($ProjectEndpoint.AbsoluteUri.TrimEnd('/') -ne $expectedEndpoint) {
    throw 'ProjectEndpoint does not match ProjectResourceId.'
}
if ($VerifyHosted -and -not $Deploy) { throw '-VerifyHosted requires -Deploy.' }
if (($Deploy -or $FabricIQConnectionName) -and -not (Test-Path -LiteralPath $PythonExecutable -PathType Leaf)) {
    throw 'Run Start-ParticipantDeployment.ps1 in Cloud Shell, or pass a prepared -PythonExecutable.'
}
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}
$subscription = az account show --query id -o tsv
if ($LASTEXITCODE -ne 0 -or $subscription -ne $SubscriptionId) {
    throw 'Sign in manually and select the requested Azure subscription before running this script.'
}
$accountId = $ProjectResourceId -replace '/projects/[^/]+$', ''
$location = az resource show --ids $accountId --query location -o tsv
if ($LASTEXITCODE -ne 0 -or -not $location) {
    throw 'Cannot resolve the existing Foundry account location required for code deployment.'
}
Invoke-Checked 'azd' @('auth', 'login', '--check-status')
$environments = azd env list --output json --cwd $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Cannot list azd environments.' }
if (-not (($environments | ConvertFrom-Json) | Where-Object Name -eq $EnvironmentName)) {
    Invoke-Checked 'azd' @('env', 'new', $EnvironmentName, '--no-prompt', '--cwd', $PSScriptRoot)
}
$values = @{
    AZURE_SUBSCRIPTION_ID = $SubscriptionId
    AZURE_LOCATION = $location.Trim()
    FOUNDRY_PROJECT_ENDPOINT = $ProjectEndpoint.AbsoluteUri.TrimEnd('/')
    AZURE_AI_PROJECT_ENDPOINT = $ProjectEndpoint.AbsoluteUri.TrimEnd('/')
    AZURE_AI_PROJECT_ID = $ProjectResourceId
    DEMAND_AGENT_NAME = $DemandAgentName
    DEMAND_AGENT_VERSION = $DemandAgentVersion
    OPTIMISATION_AGENT_NAME = $OptimisationAgentName
    OPTIMISATION_AGENT_VERSION = $OptimisationAgentVersion
    REPLENISHMENT_AGENT_NAME = $ReplenishmentAgentName
    REPLENISHMENT_AGENT_VERSION = $ReplenishmentAgentVersion
}
if ($FabricIQConnectionName) {
    foreach ($key in $values.Keys) { Set-Item -LiteralPath "Env:$key" -Value $values[$key] }
    $pins = & $PythonExecutable (Join-Path $PSScriptRoot 'configure_specialists.py') `
        --connection-name $FabricIQConnectionName
    if ($LASTEXITCODE -ne 0) { throw 'Fabric IQ specialist configuration failed. No deployment attempted.' }
    $configured = ($pins -join "`n") | ConvertFrom-Json
    foreach ($property in $configured.PSObject.Properties) {
        $values[$property.Name] = [string]$property.Value
    }
}
foreach ($key in $values.Keys) {
    Invoke-Checked 'azd' @('env', 'set', $key, $values[$key], '-e', $EnvironmentName, '--cwd', $PSScriptRoot)
}
Write-Host 'Configured the existing project. No resources have been provisioned.'
if ($Deploy) {
    if (-not $values.ContainsKey('TOOLBOX_ENDPOINT')) {
        $existingToolbox = azd env get-value TOOLBOX_ENDPOINT -e $EnvironmentName --cwd $PSScriptRoot 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $existingToolbox) {
            throw 'No Fabric IQ toolbox is configured. Run once with -FabricIQConnectionName.'
        }
        $values.TOOLBOX_ENDPOINT = "$existingToolbox".Trim()
    }
    foreach ($key in $values.Keys) { Set-Item -LiteralPath "Env:$key" -Value $values[$key] }
    Invoke-Checked $PythonExecutable @((Join-Path $PSScriptRoot 'verify_configuration.py'))
    Invoke-Checked $PythonExecutable @((Join-Path $PSScriptRoot 'configure_specialists.py'), '--export-specialists')
    Invoke-Checked 'azd' @('deploy', 'inventory-planning-assistant', '--no-prompt',
        '-e', $EnvironmentName, '--cwd', $PSScriptRoot)
    if ($VerifyHosted) {
        $version = azd env get-value AGENT_INVENTORY_PLANNING_ASSISTANT_VERSION `
            -e $EnvironmentName --cwd $PSScriptRoot
        if ($LASTEXITCODE -ne 0 -or -not $version) { throw 'Cannot resolve the deployed hosted version.' }
        $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
        $evidence = Join-Path $PSScriptRoot ".azure\$EnvironmentName\hosted-check-$stamp.json"
        Invoke-Checked $PythonExecutable @((Join-Path $PSScriptRoot 'verify_hosted.py'),
            '--endpoint', $values.FOUNDRY_PROJECT_ENDPOINT, '--version', $version.Trim(),
            '--output', $evidence)
    }
    Write-Host 'Deployed. Complete the remaining live/channel checks before committing or publishing.'
}
