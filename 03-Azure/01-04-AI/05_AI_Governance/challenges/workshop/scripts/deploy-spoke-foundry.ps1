[CmdletBinding()]
param(
    [string]$SpokeResourceGroupName = $env:SPOKE_RESOURCE_GROUP_NAME,
    [string]$SpokeSuffix = $env:SPOKE_SUFFIX,
    [string]$FoundryAccountName = $env:FOUNDRY_ACCOUNT_NAME,
    [string]$FoundryProjectName = $env:FOUNDRY_PROJECT_NAME,
    [string]$KeyVaultName = $env:KEY_VAULT_NAME,
    [string]$KeyVaultEnablePurgeProtection = $(if ($env:KEY_VAULT_ENABLE_PURGE_PROTECTION) { $env:KEY_VAULT_ENABLE_PURGE_PROTECTION } else { 'false' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$aiProjectManagerRoleId = 'eadc314b-1a2d-4efa-be10-5d325db5065e'
$keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
$acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
$foundryAppInsightsConnectionApiVersion = '2025-06-01'
$securityControlTag = 'SecurityControl=Ignore'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message"
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-AzdValue {
    param(
        [string]$Name,
        [switch]$Required
    )

    $value = (& azd env get-value $Name 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $value = $null
    }

    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        throw "Required azd environment value is missing: $Name. Run azd up/provision first, then rerun this script."
    }

    return ($value | Select-Object -First 1)
}

function ConvertTo-SafeNamePart {
    param([string]$Value)
    $name = $Value.ToLowerInvariant() -replace '[^a-z0-9-]', '-' -replace '-+', '-'
    $name = $name.Trim('-')
    if ([string]::IsNullOrWhiteSpace($name)) { return 'citadel' }
    return $name
}

function ConvertTo-CompactNamePart {
    param([string]$Value)
    $name = $Value.ToLowerInvariant() -replace '[^a-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($name)) { return 'citadel' }
    return $name
}

function ConvertTo-TrimmedCliOutput {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]($Value | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text.Trim()
}

function Invoke-NativeCommandQuietly {
    param([scriptblock]$Command)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command *> $null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Add-RoleAssignmentIfMissing {
    param(
        [string]$PrincipalId,
        [string]$PrincipalType,
        [string]$RoleId,
        [string]$RoleName,
        [string]$Scope
    )

    $assignmentId = $null
    try {
        $assignmentId = (& az role assignment list `
            --assignee-object-id $PrincipalId `
            --role $RoleId `
            --scope $Scope `
            --all `
            --fill-principal-name false `
            --fill-role-definition-name false `
            --query '[0].id' `
            -o tsv 2>$null)
    } catch { $assignmentId = $null }

    if (-not [string]::IsNullOrWhiteSpace($assignmentId)) {
        Write-Host "Role assignment already exists: $RoleName"
        return
    }

    & az role assignment create `
        --assignee-object-id $PrincipalId `
        --assignee-principal-type $PrincipalType `
        --role $RoleId `
        --scope $Scope `
        --only-show-errors `
        -o none
    Write-Host "Assigned role: $RoleName"
}

function Set-SecurityControlTag {
    param([string]$ResourceId)

    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return
    }

    & az tag update `
        --resource-id $ResourceId `
        --operation Merge `
        --tags $securityControlTag `
        --only-show-errors `
        -o none
}

Assert-Command az
Assert-Command azd

if ((Invoke-NativeCommandQuietly { & az account show }) -ne 0) {
    throw 'Azure CLI is not logged in. Run az login, then rerun this script.'
}

if ((Invoke-NativeCommandQuietly { & az cognitiveservices account project -h }) -ne 0) {
    throw 'This Azure CLI does not include az cognitiveservices account project. Update Azure CLI and rerun this script.'
}

$governanceResourceGroup = Get-AzdValue -Name 'AZURE_RESOURCE_GROUP' -Required
$location = Get-AzdValue -Name 'AZURE_LOCATION' -Required
$azdEnvName = Get-AzdValue -Name 'AZURE_ENV_NAME'
$subscriptionId = Get-AzdValue -Name 'AZURE_SUBSCRIPTION_ID'

if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
    & az account set --subscription $subscriptionId
} else {
    $subscriptionId = ConvertTo-TrimmedCliOutput (& az account show --query id -o tsv)
}

$seedSource = if ([string]::IsNullOrWhiteSpace($azdEnvName)) { $governanceResourceGroup } else { $azdEnvName }
$tagEnvName = if ([string]::IsNullOrWhiteSpace($azdEnvName)) { 'unknown' } else { $azdEnvName }
$baseNameSeed = ConvertTo-SafeNamePart $seedSource
$baseCompactSeed = ConvertTo-CompactNamePart $seedSource
$hasSpokeSuffix = -not [string]::IsNullOrWhiteSpace($SpokeSuffix)

if ($hasSpokeSuffix) {
    $spokeSuffixName = ConvertTo-SafeNamePart $SpokeSuffix
    $spokeSuffixCompact = ConvertTo-CompactNamePart $SpokeSuffix
    $nameSeed = "$baseNameSeed-spoke-$spokeSuffixName"
    $compactSeed = "${baseCompactSeed}spoke$spokeSuffixCompact"
    $defaultSpokeResourceGroupName = "$governanceResourceGroup-spoke-$spokeSuffixName"
} else {
    $nameSeed = $baseNameSeed
    $compactSeed = $baseCompactSeed
    $defaultSpokeResourceGroupName = "$governanceResourceGroup-spoke"
}

$subscriptionSuffix = ($subscriptionId -replace '-', '').Substring(0, 8)

if ([string]::IsNullOrWhiteSpace($SpokeResourceGroupName)) {
    $SpokeResourceGroupName = $defaultSpokeResourceGroupName
}
if ([string]::IsNullOrWhiteSpace($FoundryProjectName)) {
    $FoundryProjectName = 'citadel-agents-project'
}

if ([string]::IsNullOrWhiteSpace($FoundryAccountName)) {
    $FoundryAccountName = "aif-$nameSeed-$subscriptionSuffix"
    if ($FoundryAccountName.Length -gt 64) { $FoundryAccountName = $FoundryAccountName.Substring(0, 64).TrimEnd('-') }
}

if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    $KeyVaultName = "kv$compactSeed$subscriptionSuffix"
    if ($KeyVaultName.Length -gt 24) { $KeyVaultName = $KeyVaultName.Substring(0, 24) }
}

$logAnalyticsWorkspaceName = if ($env:SPOKE_LOG_ANALYTICS_NAME) { $env:SPOKE_LOG_ANALYTICS_NAME } else { "law-$nameSeed-$subscriptionSuffix" }
if ($logAnalyticsWorkspaceName.Length -gt 63) { $logAnalyticsWorkspaceName = $logAnalyticsWorkspaceName.Substring(0, 63).TrimEnd('-') }

$appInsightsName = if ($env:SPOKE_APP_INSIGHTS_NAME) { $env:SPOKE_APP_INSIGHTS_NAME } else { "appi-$nameSeed-$subscriptionSuffix" }
if ($appInsightsName.Length -gt 255) { $appInsightsName = $appInsightsName.Substring(0, 255).TrimEnd('-') }

$foundryAppInsightsConnectionName = if ($env:SPOKE_AI_FOUNDRY_APPINSIGHTS_CONNECTION_NAME) { $env:SPOKE_AI_FOUNDRY_APPINSIGHTS_CONNECTION_NAME } else { 'appinsights-connection' }

$currentUserObjectId = (& az ad signed-in-user show --query id -o tsv 2>$null)
if ([string]::IsNullOrWhiteSpace($currentUserObjectId)) {
    throw 'Could not resolve the signed-in user object ID. This script expects an interactive user login.'
}
$currentUserObjectId = ConvertTo-TrimmedCliOutput $currentUserObjectId

Write-Step 'Creating spoke resource group'
& az group create `
    --name $SpokeResourceGroupName `
    --location $location `
    --tags "azd-env-name=$tagEnvName" 'workload=citadel-spoke' `
    -o none

Write-Step 'Creating Azure AI Foundry account'
if ((Invoke-NativeCommandQuietly { & az cognitiveservices account show --name $FoundryAccountName --resource-group $SpokeResourceGroupName }) -ne 0) {
    & az cognitiveservices account create `
        --name $FoundryAccountName `
        --resource-group $SpokeResourceGroupName `
        --location $location `
        --kind AIServices `
        --sku S0 `
        --assign-identity `
        --custom-domain $FoundryAccountName `
        --allow-project-management true `
        --yes `
        --tags "azd-env-name=$tagEnvName" 'workload=citadel-spoke' $securityControlTag `
        -o none
} else {
    Write-Host "Foundry account already exists: $FoundryAccountName"
}

$foundryAccountId = ConvertTo-TrimmedCliOutput (& az cognitiveservices account show `
    --name $FoundryAccountName `
    --resource-group $SpokeResourceGroupName `
    --query id `
    -o tsv)
Set-SecurityControlTag -ResourceId $foundryAccountId

$foundryAccountPatchBody = @{
    properties = @{
        allowProjectManagement = $true
        disableLocalAuth = $true
        publicNetworkAccess = 'Enabled'
        networkAcls = @{
            defaultAction = 'Allow'
            ipRules = @()
            virtualNetworkRules = @()
        }
    }
} | ConvertTo-Json -Depth 5 -Compress

$foundryAccountPatchPath = Join-Path ([System.IO.Path]::GetTempPath()) ("foundry-account-patch-{0}.json" -f [System.Guid]::NewGuid().ToString('N'))
[System.IO.File]::WriteAllText($foundryAccountPatchPath, $foundryAccountPatchBody, [System.Text.UTF8Encoding]::new($false))

try {
    & az resource patch `
        --ids $foundryAccountId `
        --api-version 2025-06-01 `
        --properties "@$foundryAccountPatchPath" `
        --only-show-errors `
        -o none
}
finally {
    Remove-Item -Path $foundryAccountPatchPath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Creating Azure AI Foundry project'
if ((Invoke-NativeCommandQuietly { & az cognitiveservices account project show --name $FoundryAccountName --resource-group $SpokeResourceGroupName --project-name $FoundryProjectName }) -ne 0) {
    & az cognitiveservices account project create `
        --name $FoundryAccountName `
        --resource-group $SpokeResourceGroupName `
        --project-name $FoundryProjectName `
        --location $location `
        --assign-identity `
        --display-name $FoundryProjectName `
        --description 'Citadel workshop project for Foundry Agents.' `
        -o none
} else {
    Write-Host "Foundry project already exists: $FoundryProjectName"
}

$projectResourceId = "/subscriptions/$subscriptionId/resourceGroups/$SpokeResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$FoundryAccountName/projects/$FoundryProjectName"
Set-SecurityControlTag -ResourceId $projectResourceId

Write-Step 'Ensuring Application Insights CLI extension'
& az extension add --name application-insights --upgrade --only-show-errors *> $null

Write-Step 'Creating Log Analytics workspace'
if ((Invoke-NativeCommandQuietly { & az monitor log-analytics workspace show --resource-group $SpokeResourceGroupName --workspace-name $logAnalyticsWorkspaceName }) -ne 0) {
    & az monitor log-analytics workspace create `
        --resource-group $SpokeResourceGroupName `
        --workspace-name $logAnalyticsWorkspaceName `
        --location $location `
        --sku PerGB2018 `
        --tags "azd-env-name=$tagEnvName" 'workload=citadel-spoke' `
        -o none
} else {
    Write-Host "Log Analytics workspace already exists: $logAnalyticsWorkspaceName"
}

$logAnalyticsWorkspaceId = ConvertTo-TrimmedCliOutput (& az monitor log-analytics workspace show `
    --resource-group $SpokeResourceGroupName `
    --workspace-name $logAnalyticsWorkspaceName `
    --query id `
    -o tsv)

Write-Step 'Creating Application Insights'
if ((Invoke-NativeCommandQuietly { & az monitor app-insights component show --app $appInsightsName --resource-group $SpokeResourceGroupName }) -ne 0) {
    & az monitor app-insights component create `
        --app $appInsightsName `
        --location $location `
        --resource-group $SpokeResourceGroupName `
        --workspace $logAnalyticsWorkspaceId `
        --kind web `
        --application-type web `
        --tags "azd-env-name=$tagEnvName" 'workload=citadel-spoke' `
        -o none
} else {
    Write-Host "Application Insights already exists: $appInsightsName"
}

$appInsightsId = ConvertTo-TrimmedCliOutput (& az monitor app-insights component show `
    --app $appInsightsName `
    --resource-group $SpokeResourceGroupName `
    --query id `
    -o tsv)

$appInsightsConnectionString = ConvertTo-TrimmedCliOutput (& az monitor app-insights component show `
    --app $appInsightsName `
    --resource-group $SpokeResourceGroupName `
    --query connectionString `
    -o tsv)

$foundryConnectionBody = @{
    properties = @{
        category = 'AppInsights'
        target = $appInsightsId
        authType = 'ApiKey'
        credentials = @{
            key = $appInsightsConnectionString
        }
        metadata = @{
            ApiType = 'Azure'
            ResourceId = $appInsightsId
        }
        isSharedToAll = $true
    }
} | ConvertTo-Json -Depth 6 -Compress

$foundryConnectionBodyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("foundry-project-connection-{0}.json" -f [System.Guid]::NewGuid().ToString('N'))
[System.IO.File]::WriteAllText($foundryConnectionBodyPath, $foundryConnectionBody, [System.Text.UTF8Encoding]::new($false))

Write-Step 'Connecting Application Insights to Azure AI Foundry project'
# The cognitiveservices project connection wrapper currently rejects a valid
# App Insights payload, so use the ARM resource endpoint directly.
try {
    & az rest `
        --method PUT `
    --url "https://management.azure.com$projectResourceId/connections/${foundryAppInsightsConnectionName}?api-version=$foundryAppInsightsConnectionApiVersion" `
        --body "@$foundryConnectionBodyPath" `
        -o none
}
finally {
    Remove-Item -Path $foundryConnectionBodyPath -Force -ErrorAction SilentlyContinue
}

Write-Step 'Creating Key Vault'
if ((Invoke-NativeCommandQuietly { & az keyvault show --name $KeyVaultName --resource-group $SpokeResourceGroupName }) -ne 0) {
    $keyVaultCreateArgs = @(
        'keyvault', 'create',
        '--name', $KeyVaultName,
        '--resource-group', $SpokeResourceGroupName,
        '--location', $location,
        '--sku', 'standard',
        '--enable-rbac-authorization', 'true',
        '--public-network-access', 'Enabled',
        '--default-action', 'Allow',
        '--bypass', 'AzureServices',
        '--tags', "azd-env-name=$tagEnvName", 'workload=citadel-spoke', $securityControlTag,
        '-o', 'none'
    )
    if ([string]::Equals($KeyVaultEnablePurgeProtection, 'true', [System.StringComparison]::OrdinalIgnoreCase)) {
        $keyVaultCreateArgs += @('--enable-purge-protection', 'true')
    }
    & az @keyVaultCreateArgs
} else {
    Write-Host "Key Vault already exists: $KeyVaultName"
}

$existingKeyVaultPurgeProtection = ConvertTo-TrimmedCliOutput (& az keyvault show `
    --name $KeyVaultName `
    --resource-group $SpokeResourceGroupName `
    --query 'properties.enablePurgeProtection' `
    -o tsv)

if ($existingKeyVaultPurgeProtection -eq 'true') {
    Write-Warning 'Key Vault purge protection is enabled and cannot be disabled. Immediate purge will not be available for this vault.'
}

$keyVaultId = ConvertTo-TrimmedCliOutput (& az keyvault show `
    --name $KeyVaultName `
    --resource-group $SpokeResourceGroupName `
    --query id `
    -o tsv)
Set-SecurityControlTag -ResourceId $keyVaultId

Write-Step 'Assigning RBAC roles to the signed-in user'
Add-RoleAssignmentIfMissing -PrincipalId $currentUserObjectId -PrincipalType User -RoleId $aiProjectManagerRoleId -RoleName 'Azure AI Project Manager' -Scope $foundryAccountId
Add-RoleAssignmentIfMissing -PrincipalId $currentUserObjectId -PrincipalType User -RoleId $keyVaultSecretsUserRoleId -RoleName 'Key Vault Secrets User' -Scope $keyVaultId

# --- Azure Container Registry ---

$acrName = if ($env:SPOKE_ACR_NAME) { $env:SPOKE_ACR_NAME } else { "acr$compactSeed$subscriptionSuffix" }
$acrName = $acrName -replace '[^a-zA-Z0-9]', ''
if ($acrName.Length -gt 50) { $acrName = $acrName.Substring(0, 50) }

Write-Step 'Creating Azure Container Registry'
if ((Invoke-NativeCommandQuietly { & az acr show --name $acrName --resource-group $SpokeResourceGroupName }) -ne 0) {
    & az acr create `
        --name $acrName `
        --resource-group $SpokeResourceGroupName `
        --location $location `
        --sku Basic `
        --admin-enabled false `
        --tags "azd-env-name=$tagEnvName" 'workload=citadel-spoke' `
        -o none
} else {
    Write-Host "Container Registry already exists: $acrName"
}

$acrId = ConvertTo-TrimmedCliOutput (& az acr show `
    --name $acrName `
    --resource-group $SpokeResourceGroupName `
    --query id `
    -o tsv)

$acrLoginServer = ConvertTo-TrimmedCliOutput (& az acr show `
    --name $acrName `
    --resource-group $SpokeResourceGroupName `
    --query loginServer `
    -o tsv)

Write-Step 'Assigning AcrPull to Foundry project managed identity'
$foundryProjectMiObjectId = ConvertTo-TrimmedCliOutput (& az cognitiveservices account project show `
    --name $FoundryAccountName `
    --resource-group $SpokeResourceGroupName `
    --project-name $FoundryProjectName `
    --query 'identity.principalId' `
    -o tsv)

if (-not [string]::IsNullOrWhiteSpace($foundryProjectMiObjectId)) {
    Add-RoleAssignmentIfMissing -PrincipalId $foundryProjectMiObjectId -PrincipalType ServicePrincipal -RoleId $acrPullRoleId -RoleName 'AcrPull (Foundry project MI)' -Scope $acrId
} else {
    Write-Warning 'Could not resolve Foundry project managed identity. AcrPull role assignment skipped.'
}

Write-Step 'Saving spoke resource values to azd environment'
& azd env set SPOKE_RESOURCE_GROUP $SpokeResourceGroupName *> $null
& azd env set SPOKE_AI_FOUNDRY_ACCOUNT_NAME $FoundryAccountName *> $null
& azd env set SPOKE_AI_FOUNDRY_PROJECT_NAME $FoundryProjectName *> $null
& azd env set SPOKE_LOG_ANALYTICS_NAME $logAnalyticsWorkspaceName *> $null
& azd env set SPOKE_APP_INSIGHTS_NAME $appInsightsName *> $null
& azd env set SPOKE_APP_INSIGHTS_ID $appInsightsId *> $null
& azd env set SPOKE_AI_FOUNDRY_APPINSIGHTS_CONNECTION_NAME $foundryAppInsightsConnectionName *> $null
& azd env set SPOKE_KEY_VAULT_NAME $KeyVaultName *> $null
& azd env set SPOKE_ACR_NAME $acrName *> $null
& azd env set SPOKE_ACR_LOGIN_SERVER $acrLoginServer *> $null

Write-Host "`nSpoke resources are ready."
Write-Host "Resource group: $SpokeResourceGroupName"
Write-Host "Foundry account: $FoundryAccountName"
Write-Host "Foundry project: $FoundryProjectName"
Write-Host "Log Analytics workspace: $logAnalyticsWorkspaceName"
Write-Host "Application Insights: $appInsightsName"
Write-Host "Foundry App Insights connection: $foundryAppInsightsConnectionName"
Write-Host "Key Vault: $KeyVaultName"
Write-Host "`nAfter deleting these resources, purge soft-deleted names with:"
Write-Host "az cognitiveservices account purge --name `"$FoundryAccountName`" --resource-group `"$SpokeResourceGroupName`" --location `"$location`""
Write-Host "az keyvault purge --name `"$KeyVaultName`" --location `"$location`""
