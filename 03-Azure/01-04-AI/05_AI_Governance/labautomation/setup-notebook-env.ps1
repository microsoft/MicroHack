<#
.SYNOPSIS
    Bootstraps a local azd environment so the unchanged Citadel workshop
    notebooks (under challenges/workshop) can keep calling
    `azd env get-value <KEY>` unmodified.

.DESCRIPTION
    The workshop notebooks were written against `azd up` and read their
    configuration exclusively via `azd env get-value`. This MicroHack lab
    provisions the same resources via deploy-lab.ps1 (PowerShell/Bicep, not
    azd), so there is no azd environment for the notebooks to read from.

    This script closes that gap: it creates (or selects) a local azd
    environment and sets exactly the keys the notebooks expect, using the
    values from the attendee's HackboxCredential dashboard.

    `azd` resolves the "current" environment by searching upward from the
    working directory for the nearest `azure.yaml` (its project-root marker),
    the same way git finds `.git`. The workshop's `azure.yaml` lives at:

        challenges/azure.yaml

    ...one level above the `workshop/` folder that contains the notebooks.
    For `azd env get-value` calls made *inside* a notebook (cwd = workshop/)
    to resolve the same environment this script sets, every `azd env ...`
    command below is run with that azd project root as its working
    directory.

.PARAMETER AzdEnvironmentName
    Name of the local azd environment to create/select. Defaults to
    'citadel-microhack'.
.PARAMETER ResourceGroup
    Value of the HackboxCredential 'ResourceGroup' / 'SpokeResourceGroup'
    (single-RG deployment: hub and spoke share one resource group).
.PARAMETER Location
    Value of the HackboxCredential 'Location'.
.PARAMETER SubscriptionId
    Value of the HackboxCredential 'SubscriptionId'.
.PARAMETER LlmBackendConfig
    Value of the HackboxCredential 'LlmBackendConfig' (base64 JSON).
.PARAMETER SpokeKeyVaultName
    Value of the HackboxCredential 'SpokeKeyVaultName'.
.PARAMETER SpokeAiFoundryAccountName
    Value of the HackboxCredential 'SpokeAiFoundryAccountName' (alias of
    'SpokeFoundryAccountName').
.PARAMETER SpokeAiFoundryProjectName
    Value of the HackboxCredential 'SpokeAiFoundryProjectName' (alias of
    'SpokeFoundryProjectName').
.PARAMETER SpokeAcrName
    Value of the HackboxCredential 'SpokeAcrName'.
.PARAMETER SpokeAcrLoginServer
    Value of the HackboxCredential 'SpokeAcrLoginServer'.

.EXAMPLE
    ./setup-notebook-env.ps1 `
        -ResourceGroup "rg-citadel-abc123" `
        -Location "swedencentral" `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -LlmBackendConfig "<value from dashboard>" `
        -SpokeKeyVaultName "kv-spoke-abc123" `
        -SpokeAiFoundryAccountName "aif-spoke-abc123" `
        -SpokeAiFoundryProjectName "citadel-agents-project" `
        -SpokeAcrName "acrspokeabc123" `
        -SpokeAcrLoginServer "acrspokeabc123.azurecr.io"

    Then open any workshop notebook and run its `azd env get-value` cell —
    no notebook changes required.
#>
param(
    [string]$AzdEnvironmentName = "citadel-microhack",

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$LlmBackendConfig = "",

    [string]$SpokeKeyVaultName = "",

    [string]$SpokeAiFoundryAccountName = "",

    [string]$SpokeAiFoundryProjectName = "",

    [string]$SpokeAcrName = "",

    [string]$SpokeAcrLoginServer = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command azd -ErrorAction SilentlyContinue)) {
    throw "azd (Azure Developer CLI) is not installed or not on PATH. Install it first: https://aka.ms/azd-install"
}

# The workshop's azure.yaml (azd project root) lives one level above workshop/,
# where all the notebooks live. azd resolves its environment by searching
# upward from cwd for this marker, so we must run every azd command from
# here (or a descendant of it) for notebooks to see the same environment.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$azdProjectRoot = Resolve-Path (Join-Path $scriptRoot "../challenges") -ErrorAction SilentlyContinue

if (-not $azdProjectRoot) {
    throw "Could not resolve the azd project root at '../challenges' relative to this script. Ensure the challenges folder exists."
}

$azureYaml = Join-Path $azdProjectRoot "azure.yaml"
if (-not (Test-Path $azureYaml)) {
    throw "azure.yaml not found at '$azureYaml'. The notebooks resolve their azd environment relative to this file — cannot continue."
}

Write-Host "[INFO]  Bootstrapping azd environment '$AzdEnvironmentName' for notebook use..."
Write-Host "[INFO]  azd project root: $azdProjectRoot"

Push-Location $azdProjectRoot
try {
    $existingEnvs = (& azd env list --output json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue)
    $envExists = $existingEnvs | Where-Object { $_.Name -eq $AzdEnvironmentName }

    if ($envExists) {
        Write-Host "[OK]    azd environment '$AzdEnvironmentName' already exists — selecting it."
        & azd env select $AzdEnvironmentName
        if ($LASTEXITCODE -ne 0) { throw "azd env select '$AzdEnvironmentName' failed." }
    } else {
        Write-Host "[INFO]  Creating azd environment '$AzdEnvironmentName'..."
        & azd env new $AzdEnvironmentName --location $Location --subscription $SubscriptionId
        if ($LASTEXITCODE -ne 0) { throw "azd env new '$AzdEnvironmentName' failed." }
        Write-Host "[OK]    azd environment '$AzdEnvironmentName' created."
    }

    function Set-AzdValue {
        param([string]$Key, [string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) {
            Write-Host "[WARN]  No value supplied for $Key — skipping (notebook cells needing it will fail)."
            return
        }
        & azd env set $Key $Value | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "azd env set $Key failed." }
        Write-Host "[OK]    Set $Key"
    }

    # Exact key set the workshop notebooks read via azd env get-value.
    Set-AzdValue -Key "AZURE_RESOURCE_GROUP"          -Value $ResourceGroup
    Set-AzdValue -Key "AZURE_LOCATION"                -Value $Location
    Set-AzdValue -Key "AZURE_SUBSCRIPTION_ID"         -Value $SubscriptionId
    Set-AzdValue -Key "LLM_BACKEND_CONFIG"            -Value $LlmBackendConfig
    Set-AzdValue -Key "SPOKE_RESOURCE_GROUP"          -Value $ResourceGroup   # single-RG deployment: spoke == hub RG
    Set-AzdValue -Key "SPOKE_KEY_VAULT_NAME"          -Value $SpokeKeyVaultName
    Set-AzdValue -Key "SPOKE_AI_FOUNDRY_ACCOUNT_NAME" -Value $SpokeAiFoundryAccountName
    Set-AzdValue -Key "SPOKE_AI_FOUNDRY_PROJECT_NAME" -Value $SpokeAiFoundryProjectName
    Set-AzdValue -Key "SPOKE_ACR_NAME"                -Value $SpokeAcrName
    Set-AzdValue -Key "SPOKE_ACR_LOGIN_SERVER"        -Value $SpokeAcrLoginServer

    Write-Host "[OK]    azd environment '$AzdEnvironmentName' is ready. Notebooks in workshop/ can now call 'azd env get-value <KEY>' unmodified."
}
finally {
    Pop-Location
}
