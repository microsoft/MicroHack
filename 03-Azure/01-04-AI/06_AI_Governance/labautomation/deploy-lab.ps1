<#
.SYNOPSIS
    Deploys the Citadel Agentic Governance Hub (with integrated spoke sample)
    for the Belgium MicroHack.

.DESCRIPTION
    Called by the EMEA MicroHack platform once per attendee, in parallel.

    Provisions a complete Citadel hub-and-spoke architecture into a single
    platform-provided resource group using deterministic naming:

    Hub resources:
      - API Management (StandardV2) — unified AI gateway
      - Azure AI Foundry account + project (hub-scoped)
      - Log Analytics workspace + Application Insights (hub)
      - Cosmos DB (serverless, keyless) — usage tracking
      - Event Hub — event streaming pipeline
      - Key Vault — hub secrets
      - Storage Account + Logic App (if deployed) — usage ingestion

    Spoke resources (same RG, deterministic suffix):
      - Azure AI Foundry account + project (spoke-scoped)
      - Log Analytics workspace + Application Insights (spoke)
      - Key Vault (spoke) — spoke secrets
      - Azure Container Registry (spoke)

    RBAC is assigned per attendee across Foundry, Key Vault, Cosmos, monitoring, APIM
    (management-plane, for APIMClientTool) and ACR (AcrPush, for Notebook 7), so the
    unchanged Citadel notebooks work out-of-the-box with DefaultAzureCredential.

    The platform pre-sets the Az context to $SubscriptionId and pre-creates the
    resource group. Do NOT call Connect-AzAccount or New-AzResourceGroup.

.PARAMETER DeploymentType
    Deployment scope — passed in by the platform.
.PARAMETER SubscriptionId
    Azure subscription — passed in by the platform.
.PARAMETER ResourceGroupName
    Pre-created resource group — passed in by the platform.
.PARAMETER PreferredLocation
    Ordered list of preferred Azure regions — passed in by the platform.
.PARAMETER AllowedEntraUserIds
    Entra user object IDs for this lab — passed in by the platform.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = "Stop"

# Resolve effective values — honour $PreferredLocation, fall back across the list
$candidateRegions = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @("swedencentral", "westeurope", "norwayeast") }

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Prefer the pre-compiled ARM template. New-AzResourceGroupDeployment -TemplateFile *.bicep
# shells out to the standalone Bicep CLI, which is NOT guaranteed to exist on the platform
# deployment host (the az-CLI-bundled bicep in ~/.azure/bin is invisible to Az PowerShell).
# infra/resources.json is committed alongside the Bicep source precisely so deployment has no
# local toolchain dependency; fall back to the .bicep source only if it is missing.
$armFile   = Join-Path $scriptPath 'infra/resources.json'
$bicepSrc  = Join-Path $scriptPath 'infra/resources.bicep'

if (Test-Path $armFile) {
    $templateFile = $armFile
    $templateKind = 'compiled ARM (infra/resources.json)'
}
elseif (Test-Path $bicepSrc) {
    $templateFile = $bicepSrc
    $templateKind = 'Bicep source (infra/resources.bicep, requires Bicep CLI)'
}
else {
    throw "No deployment template found. Expected 'infra/resources.json' (preferred) or 'infra/resources.bicep' under '$scriptPath'."
}

# --- Resolve the resource group per the platform contract -------------------
# 'resourcegroup' / 'resourcegroup-with-subscriptionowner': the platform pre-created the
# RG and granted Owner on it, so we must NOT create it.
# 'subscription': the platform granted Owner on the subscription and created nothing —
# we create the RG ourselves under a deterministic per-lab name. lab-defaults.json pins
# this lab to 'resourcegroup', but the parameter contract allows all three values, so
# the subscription path is implemented rather than left to fail with an empty RG name.
if ($DeploymentType -eq 'subscription') {
    $hashInput = if ($AllowedEntraUserIds.Count -gt 0) { $AllowedEntraUserIds } else { @($SubscriptionId) }
    $rgHash = (Get-MhhStableHash $hashInput -Length 24).ToLower()
    $effectiveRG = "rg-citadel-microhack-$rgHash"
    Write-Host "[INFO]  Subscription-scoped lab — creating resource group '$effectiveRG' in '$($candidateRegions[0])'..."
    New-AzResourceGroup -Name $effectiveRG -Location $candidateRegions[0] -Force | Out-Null
}
else {
    $effectiveRG = $ResourceGroupName
    if ([string]::IsNullOrWhiteSpace($effectiveRG)) {
        throw "DeploymentType '$DeploymentType' requires the platform to pass a pre-created -ResourceGroupName, but it was empty."
    }
}

# Deterministic token for resource naming (subscription + RG based, so it is stable
# across region retries and re-runs). infra/resources.bicep derives EVERY hub and spoke
# resource name from this token — resource names must not be recomputed here, or the
# script and the template disagree about what was actually deployed.
$resourceToken = (Get-MhhStableHash "$SubscriptionId-$effectiveRG" -Length 13).ToLower()

$tags = @{ project = 'citadel-agentic-governance'; 'lab-deployment-type' = $DeploymentType }

# Guard: ALL participant data-plane RBAC is keyed off $AllowedEntraUserIds.
# An empty list leaves participants with ZERO data-plane roles, breaking notebook execution.
if ($AllowedEntraUserIds.Count -eq 0) {
    Write-Host "[WARN]  AllowedEntraUserIds is EMPTY — no participant will receive data-plane RBAC"
    Write-Host "[WARN]  (Azure AI User, Cognitive Services User, Cosmos DB Data Contributor)."
    Write-Host "[WARN]  Notebooks will fail. The platform normally sets this per lab; for manual runs,"
    Write-Host "[WARN]  pass -AllowedEntraUserIds <entraObjectId> (comma-separate ids for a team lab)."
}

Write-Host "[INFO]  Deploying Citadel Agentic Governance Hub + Spoke into RG '$effectiveRG'..."
Write-Host "[INFO]  Engine: $templateKind, resource-group-scoped."

$deployOutputs = $null
$effectiveLocation = $null

foreach ($region in $candidateRegions) {
    Write-Host "[INFO]  Deploying → RG '$effectiveRG' in '$region' (token '$resourceToken')..."
    try {
        $d = New-AzResourceGroupDeployment `
            -ResourceGroupName $effectiveRG `
            -TemplateFile $templateFile `
            -location $region `
            -resourceToken $resourceToken `
            -tags $tags `
            -ErrorAction Stop
        $deployOutputs = $d.Outputs
        $effectiveLocation = $region
        break
    }
    catch {
        # Only capacity/quota/region-availability failures are worth retrying elsewhere.
        # A template or permission bug fails identically in every region, so retrying it
        # just triples the runtime and buries the real error under the last region's message.
        $retryable = $true
        if (Get-Command Test-MhhDeploymentFailureRetryable -ErrorAction SilentlyContinue) {
            $retryable = [bool](Test-MhhDeploymentFailureRetryable -ErrorRecord $_)
        }
        if (-not $retryable) {
            throw "Deployment failed in '$region' with a non-retryable error (retrying other regions would fail the same way): $_"
        }
        Write-Host "[WARN]  Deployment failed in '$region': $_ — trying next region."
    }
}

if (-not $deployOutputs) {
    throw "Deployment failed in all candidate regions: $($candidateRegions -join ', ')"
}

Write-Host "[OK]    Provisioning complete in '$effectiveLocation' (resource group '$effectiveRG')."

# --- Deployment output helper (used by the RBAC block and the dashboard block) ---
# ARM does NOT preserve the casing of output names. A template output declared as
# APIM_GATEWAY_URL comes back from Azure as 'apiM_GATEWAY_URL' (ARM lowercases the leading
# run of capitals, keeping only the last one), and APPLICATIONINSIGHTS_CONNECTION_STRING
# comes back as 'applicationinsightS_CONNECTION_STRING'. The returned collection is a
# case-SENSITIVE dictionary, so a literal ContainsKey($Key) misses every single output —
# which silently blanks both participant RBAC and every dashboard credential.
# Normalising both sides to upper case is exact: mangling only ever changes letter casing.
function Get-OutVal {
    param($Outputs, [string]$Key)
    if (-not $Outputs) { return '' }

    if ($Outputs.ContainsKey($Key)) { return "$($Outputs[$Key].Value)" }

    $target = $Key.ToUpperInvariant()
    foreach ($k in $Outputs.Keys) {
        if ($k.ToUpperInvariant() -eq $target) { return "$($Outputs[$k].Value)" }
    }
    return ''
}

# --- Managed identity sanity check ---
# The hub and spoke Foundry accounts carry system-assigned identities that APIM and the
# notebooks depend on. The template exports their principal ids, so an empty value here
# means the account came up without an identity and downstream auth will fail.
foreach ($mi in @(
        @{ Label = 'hub Foundry';   Value = (Get-OutVal $deployOutputs 'HUB_FOUNDRY_MANAGED_IDENTITY_PRINCIPAL_ID') }
        @{ Label = 'spoke Foundry'; Value = (Get-OutVal $deployOutputs 'SPOKE_FOUNDRY_MANAGED_IDENTITY_PRINCIPAL_ID') }
    )) {
    if ([string]::IsNullOrWhiteSpace($mi.Value)) {
        Write-Host "[WARN]  The $($mi.Label) account reported no managed identity — agent tracing and backend auth may fail."
    }
}

# ---------------------------------------------------------------------------
# Participant RBAC
#
# Scopes come from the template outputs, NOT from `Get-AzResource ... | Select -First 1`.
# This lab packs a hub AND a spoke of four resource types (Foundry account, Key Vault,
# Log Analytics workspace, Application Insights) into ONE resource group, so a
# first-match probe granted the participant access to only one of each pair and left
# notebooks 3, 4 and 7-9 failing at runtime with an authorization error.
#
# Grants flagged Required are the ones the core challenges (1-6) cannot run without.
# If any of them fails, the script throws at the end so the platform reports a failed
# provision instead of handing the attendee a lab whose notebooks break on first use.
# ---------------------------------------------------------------------------
$hubFoundryId   = Get-OutVal $deployOutputs 'HUB_FOUNDRY_ACCOUNT_RESOURCE_ID'
$spokeFoundryId = Get-OutVal $deployOutputs 'SPOKE_FOUNDRY_ACCOUNT_RESOURCE_ID'
$cosmosId       = Get-OutVal $deployOutputs 'COSMOS_ACCOUNT_RESOURCE_ID'
$hubKvId        = Get-OutVal $deployOutputs 'KEY_VAULT_RESOURCE_ID'
$spokeKvId      = Get-OutVal $deployOutputs 'SPOKE_KEY_VAULT_RESOURCE_ID'
$hubLaId        = Get-OutVal $deployOutputs 'LOG_ANALYTICS_WORKSPACE_RESOURCE_ID'
$spokeLaId      = Get-OutVal $deployOutputs 'SPOKE_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID'
$hubAiId        = Get-OutVal $deployOutputs 'APP_INSIGHTS_RESOURCE_ID'
$spokeAiId      = Get-OutVal $deployOutputs 'SPOKE_APP_INSIGHTS_RESOURCE_ID'
$apimResourceId = Get-OutVal $deployOutputs 'APIM_RESOURCE_ID'
$acrId          = Get-OutVal $deployOutputs 'SPOKE_ACR_RESOURCE_ID'

# RBAC role IDs (built-in). Matched by GUID, never by display name: Azure has since renamed
# 'Azure AI User' to 'Foundry User' and 'Azure AI Project Manager' to 'Foundry Project Manager'.
# The GUIDs are stable, so the grants still work — but expect the NEW names in the portal and
# in `az role assignment list` when verifying a participant's access.
$foundryRoles = [ordered]@{
    'Azure AI User'           = '53ca6127-db72-4b80-b1b0-d745d6d5456d'  # portal: 'Foundry User'
    'Cognitive Services User' = 'a97b65f3-24c7-4388-baec-2e87135dc908'
}

# The spoke is the attendee's own build space: challenges 7-9 create and manage Foundry
# agents, hosted-agent versions and project connections there. Those are project data-plane
# management operations, which RG-Owner does NOT cover (Owner grants actions:* but no
# dataActions). The original workshop grants the signed-in user 'Azure AI Project Manager'
# on the spoke account in deploy-spoke-foundry.ps1 for exactly this reason. Kept as its own
# Optional target so a tenant that restricts this role fails challenges 7-9 only, rather
# than failing the whole provision for the core challenges 1-6.
$spokeProjectMgmtRoles = [ordered]@{
    'Azure AI Project Manager' = 'eadc314b-1a2d-4efa-be10-5d325db5065e'  # portal: 'Foundry Project Manager'
}

$keyVaultRoles = [ordered]@{
    # Verified against the live built-in role definition. Do not "correct" this GUID by hand:
    # the suffix is ...155cd7, NOT ...155090 (an earlier typo here silently failed every
    # Key Vault grant with RoleDefinitionDoesNotExist).
    'Key Vault Secrets Officer' = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

$monitoringRoles = [ordered]@{
    'Monitoring Reader' = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
}

# APIMClientTool (used by notebooks 3-7, 9) is an ARM control-plane client — it needs
# a management-plane role on the APIM resource, not just a gateway subscription key,
# to list APIs/subscriptions and to create products/subscriptions dynamically.
# 'API Management Service Contributor' is the least-privileged BUILT-IN role that covers
# both the service and its entities (APIs, products, subscriptions, policies).
# 'API Management Service Operator Role' only manages the service itself (not entities),
# and 'API Management Service Reader Role' is read-only — neither supports the
# create/update-product/subscription flows the notebooks perform.
$apimRoles = [ordered]@{
    'API Management Service Contributor' = '312a565d-c81f-4fd8-895a-4e21e48d571c'
}

# Notebook 7 pushes container images to the spoke ACR — AcrPush is the least-privileged
# built-in role for that (data-plane push/pull only, no control-plane permissions).
$acrRoles = [ordered]@{
    'AcrPush' = '8311e382-0749-4cb8-b61a-304f252e45ec'
}

# Required = a core challenge (1-6) breaks without it.
# Optional = only an observability view or a follow-on challenge (7-9) is affected.
$rbacTargets = @(
    @{ Label = 'hub Foundry account';   Scope = $hubFoundryId;   Roles = $foundryRoles;    Required = $true }
    @{ Label = 'spoke Foundry account'; Scope = $spokeFoundryId; Roles = $foundryRoles;    Required = $true }
    @{ Label = 'spoke Foundry account (project management, challenges 7-9)'; Scope = $spokeFoundryId; Roles = $spokeProjectMgmtRoles; Required = $false }
    @{ Label = 'hub Key Vault';         Scope = $hubKvId;        Roles = $keyVaultRoles;   Required = $true }
    @{ Label = 'spoke Key Vault';       Scope = $spokeKvId;      Roles = $keyVaultRoles;   Required = $true }
    @{ Label = 'APIM service';          Scope = $apimResourceId; Roles = $apimRoles;       Required = $true }
    @{ Label = 'hub Log Analytics';     Scope = $hubLaId;        Roles = $monitoringRoles; Required = $false }
    @{ Label = 'spoke Log Analytics';   Scope = $spokeLaId;      Roles = $monitoringRoles; Required = $false }
    @{ Label = 'hub App Insights';      Scope = $hubAiId;        Roles = $monitoringRoles; Required = $false }
    @{ Label = 'spoke App Insights';    Scope = $spokeAiId;      Roles = $monitoringRoles; Required = $false }
    @{ Label = 'spoke ACR';             Scope = $acrId;          Roles = $acrRoles;        Required = $false }
)

$rbacFailures = New-Object System.Collections.Generic.List[string]

function Grant-MhhRole {
    param([string]$ObjectId, [string]$RoleName, [string]$RoleId, [string]$Scope, [string]$Label)

    $existing = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionId $RoleId -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[OK]    '$RoleName' already granted to $ObjectId on the $Label."
        return $true
    }
    try {
        New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionId $RoleId -Scope $Scope -ErrorAction Stop | Out-Null
        Write-Host "[OK]    Granted '$RoleName' to $ObjectId on the $Label."
        return $true
    }
    catch {
        Write-Host "[WARN]  Could not grant '$RoleName' to $ObjectId on the ${Label}: $_"
        return $false
    }
}

function Grant-MhhCosmosDataRole {
    param([string]$ObjectId, [string]$CosmosResourceId)

    $cosmosApi = '2024-11-15'
    $roleDefinitionId = "$CosmosResourceId/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"  # Built-in Data Contributor

    $list = Invoke-AzRestMethod -Method GET -Path "$CosmosResourceId/sqlRoleAssignments?api-version=$cosmosApi" -ErrorAction SilentlyContinue
    if ($list -and $list.StatusCode -eq 200) {
        $already = ($list.Content | ConvertFrom-Json).value | Where-Object {
            $_.properties.principalId -eq $ObjectId -and $_.properties.roleDefinitionId -like '*000000000002'
        }
        if ($already) {
            Write-Host "[OK]    Cosmos DB data role already granted to $ObjectId."
            return $true
        }
    }

    $body = @{ properties = @{
            roleDefinitionId = $roleDefinitionId
            principalId      = $ObjectId
            scope            = $CosmosResourceId
        }
    } | ConvertTo-Json -Depth 5

    $assignId = [guid]::NewGuid().ToString()
    try {
        $resp = Invoke-AzRestMethod -Method PUT -Path "$CosmosResourceId/sqlRoleAssignments/${assignId}?api-version=$cosmosApi" -Payload $body -ErrorAction Stop
    }
    catch {
        Write-Host "[WARN]  Could not grant the Cosmos DB data role to ${ObjectId}: $_"
        return $false
    }

    # Invoke-AzRestMethod does NOT throw on an HTTP error status, so it must be checked
    # explicitly — otherwise a 403/404 was reported to the coach as a successful grant.
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
        Write-Host "[OK]    Cosmos DB data-plane role granted to $ObjectId."
        return $true
    }

    Write-Host "[WARN]  Cosmos DB role assignment for $ObjectId failed with HTTP $($resp.StatusCode): $($resp.Content)"
    return $false
}

# --- Multi-user data-plane RBAC ---
# Every id in $AllowedEntraUserIds is granted every role, so team labs work for all members.
foreach ($userId in $AllowedEntraUserIds) {
    foreach ($target in $rbacTargets) {
        if ([string]::IsNullOrWhiteSpace($target.Scope)) {
            $message = "the $($target.Label) was not returned by the deployment, so its roles were skipped"
            if ($target.Required) { $rbacFailures.Add("$userId : $message") }
            else { Write-Host "[WARN]  Skipping the $($target.Label) — the deployment returned no resource id for it." }
            continue
        }

        foreach ($roleName in $target.Roles.Keys) {
            $granted = Grant-MhhRole -ObjectId $userId -RoleName $roleName -RoleId $target.Roles[$roleName] -Scope $target.Scope -Label $target.Label
            if (-not $granted -and $target.Required) {
                $rbacFailures.Add("$userId is missing '$roleName' on the $($target.Label)")
            }
        }
    }

    # Cosmos DB data-plane RBAC (REST — the data roles are not ARM role assignments)
    if ([string]::IsNullOrWhiteSpace($cosmosId)) {
        $rbacFailures.Add("$userId is missing the Cosmos DB data role (the deployment returned no Cosmos account id)")
    }
    elseif (-not (Grant-MhhCosmosDataRole -ObjectId $userId -CosmosResourceId $cosmosId)) {
        $rbacFailures.Add("$userId is missing 'Cosmos DB Built-in Data Contributor' on the usage-tracking account")
    }
}

# Fail loudly rather than reporting a green provision over a broken lab.
if ($rbacFailures.Count -gt 0) {
    Write-Host "[ERROR] Provisioning finished, but required participant access is incomplete:"
    foreach ($failure in $rbacFailures) { Write-Host "[ERROR]   - $failure" }
    throw "Required participant RBAC could not be applied ($($rbacFailures.Count) grant(s) failed). Resources exist in '$effectiveRG', but the notebooks would fail at runtime, so this lab is reported as failed."
}

# --- Return credentials to the attendee dashboard ---
Write-Host "[OK]    Lab provisioning complete."

# Extract outputs from Bicep deployment
$hubFoundryEndpoint = Get-OutVal $deployOutputs 'HUB_FOUNDRY_PROJECT_ENDPOINT'
$spokeFoundryEndpoint = Get-OutVal $deployOutputs 'SPOKE_FOUNDRY_PROJECT_ENDPOINT'
$apimGatewayUrl = Get-OutVal $deployOutputs 'APIM_GATEWAY_URL'
$cosmosEndpoint = Get-OutVal $deployOutputs 'COSMOS_ENDPOINT'
$cosmosDatabase = Get-OutVal $deployOutputs 'COSMOS_DATABASE'
$keyVaultUrl = Get-OutVal $deployOutputs 'KEY_VAULT_URL'
$keyVaultName = Get-OutVal $deployOutputs 'KEY_VAULT_NAME'
$laWorkspaceId = Get-OutVal $deployOutputs 'LOG_ANALYTICS_WORKSPACE_ID'
$laWorkspaceName = Get-OutVal $deployOutputs 'LOG_ANALYTICS_WORKSPACE_NAME'
$laResourceId = Get-OutVal $deployOutputs 'LOG_ANALYTICS_WORKSPACE_RESOURCE_ID'
$appInsightsConnStr = Get-OutVal $deployOutputs 'APPLICATIONINSIGHTS_CONNECTION_STRING'
$appInsightsKey = Get-OutVal $deployOutputs 'APPLICATIONINSIGHTS_INSTRUMENTATION_KEY'
$eventHubNamespace = Get-OutVal $deployOutputs 'EVENT_HUB_NAMESPACE'
$eventHubConnStr = Get-OutVal $deployOutputs 'EVENT_HUB_CONNECTION_STRING'
$storageAccountName = Get-OutVal $deployOutputs 'STORAGE_ACCOUNT_NAME'
$storageConnStr = Get-OutVal $deployOutputs 'STORAGE_ACCOUNT_CONNECTION_STRING'
$apimName = Get-OutVal $deployOutputs 'APIM_NAME'
$spokeConnStr = Get-OutVal $deployOutputs 'SPOKE_APP_INSIGHTS_CONNECTION_STRING'

# Phase 4: per-scenario APIM subscription keys/IDs
$salesAssistantKey = Get-OutVal $deployOutputs 'SALES_ASSISTANT_SUBSCRIPTION_KEY'
$salesAssistantId = Get-OutVal $deployOutputs 'SALES_ASSISTANT_SUBSCRIPTION_ID'
$hrChatAgentKey = Get-OutVal $deployOutputs 'HR_CHATAGENT_SUBSCRIPTION_KEY'
$hrChatAgentId = Get-OutVal $deployOutputs 'HR_CHATAGENT_SUBSCRIPTION_ID'
$supportBotKey = Get-OutVal $deployOutputs 'SUPPORT_BOT_SUBSCRIPTION_KEY'
$supportBotId = Get-OutVal $deployOutputs 'SUPPORT_BOT_SUBSCRIPTION_ID'
$universalLlmTestKey = Get-OutVal $deployOutputs 'UNIVERSAL_LLM_TEST_SUBSCRIPTION_KEY'
$universalLlmTestId = Get-OutVal $deployOutputs 'UNIVERSAL_LLM_TEST_SUBSCRIPTION_ID'
$unifiedAiTestKey = Get-OutVal $deployOutputs 'UNIFIED_AI_TEST_SUBSCRIPTION_KEY'
$unifiedAiTestId = Get-OutVal $deployOutputs 'UNIFIED_AI_TEST_SUBSCRIPTION_ID'
$piiMaskingKey = Get-OutVal $deployOutputs 'PII_MASKING_SUBSCRIPTION_KEY'
$piiMaskingId = Get-OutVal $deployOutputs 'PII_MASKING_SUBSCRIPTION_ID'
$piiBlockingKey = Get-OutVal $deployOutputs 'PII_BLOCKING_SUBSCRIPTION_KEY'
$piiBlockingId = Get-OutVal $deployOutputs 'PII_BLOCKING_SUBSCRIPTION_ID'
$piiAnalyticsKey = Get-OutVal $deployOutputs 'PII_ANALYTICS_SUBSCRIPTION_KEY'
$piiAnalyticsId = Get-OutVal $deployOutputs 'PII_ANALYTICS_SUBSCRIPTION_ID'
$llmBackendConfig = Get-OutVal $deployOutputs 'LLM_BACKEND_CONFIG'

# Phase 4: spoke Foundry / Key Vault / ACR
$spokeFoundryAccountNameOut = Get-OutVal $deployOutputs 'SPOKE_FOUNDRY_ACCOUNT_NAME'
$spokeFoundryProjectNameOut = Get-OutVal $deployOutputs 'SPOKE_FOUNDRY_PROJECT_NAME'
$spokeKeyVaultNameOut = Get-OutVal $deployOutputs 'SPOKE_KEY_VAULT_NAME'
$spokeAcrNameOut = Get-OutVal $deployOutputs 'SPOKE_ACR_NAME'
$spokeAcrLoginServerOut = Get-OutVal $deployOutputs 'SPOKE_ACR_LOGIN_SERVER'

Write-Host ""
Write-Host "==================== Your Citadel Lab Environment ===================="
Write-Host "  Resource group          : $effectiveRG ($effectiveLocation)"
if ($hubFoundryEndpoint) { Write-Host "  Hub Foundry project     : $hubFoundryEndpoint" }
if ($spokeFoundryEndpoint) { Write-Host "  Spoke Foundry project   : $spokeFoundryEndpoint" }
if ($apimGatewayUrl) { Write-Host "  APIM gateway URL        : $apimGatewayUrl" }
if ($cosmosEndpoint) { Write-Host "  Cosmos DB endpoint      : $cosmosEndpoint" }
if ($keyVaultUrl) { Write-Host "  Key Vault URL           : $keyVaultUrl" }
Write-Host "  Next                    : paste these into your notebook environment."
Write-Host "========================================================================"

@{ HackboxCredential = @{ name = 'ResourceGroup'; value = $effectiveRG; note = 'Resource group holding Citadel lab resources. Maps to notebook azd env key AZURE_RESOURCE_GROUP' } }
@{ HackboxCredential = @{ name = 'Location'; value = $effectiveLocation; note = 'Deployed Azure region. Maps to notebook azd env key AZURE_LOCATION' } }
@{ HackboxCredential = @{ name = 'SubscriptionId'; value = $SubscriptionId; note = 'Azure subscription ID. Maps to notebook azd env key AZURE_SUBSCRIPTION_ID' } }
@{ HackboxCredential = @{ name = 'SpokeResourceGroup'; value = $effectiveRG; note = 'Single-RG deployment: same as ResourceGroup. Maps to notebook azd env key SPOKE_RESOURCE_GROUP' } }

if ($hubFoundryEndpoint) {
    @{ HackboxCredential = @{ name = 'HubFoundryProjectEndpoint'; value = $hubFoundryEndpoint; note = 'Hub Foundry project endpoint (Notebooks 1, 3, 6)' } }
}

if ($spokeFoundryEndpoint) {
    @{ HackboxCredential = @{ name = 'SpokeFoundryProjectEndpoint'; value = $spokeFoundryEndpoint; note = 'Spoke Foundry project endpoint for your agents (Notebooks 7–9)' } }
}

if ($apimGatewayUrl) {
    @{ HackboxCredential = @{ name = 'ApimGatewayUrl'; value = $apimGatewayUrl; note = 'APIM unified inference gateway (all notebooks)' } }
}

if ($cosmosEndpoint) {
    @{ HackboxCredential = @{ name = 'CosmosEndpoint'; value = $cosmosEndpoint; note = 'Cosmos DB endpoint for usage analytics (Notebook 2)' } }
}

if ($cosmosDatabase) {
    @{ HackboxCredential = @{ name = 'CosmosDatabase'; value = $cosmosDatabase; note = 'Cosmos DB database name' } }
}

if ($keyVaultUrl) {
    @{ HackboxCredential = @{ name = 'KeyVaultUrl'; value = $keyVaultUrl; note = 'Key Vault for credential retrieval (all notebooks)' } }
}

if ($keyVaultName) {
    @{ HackboxCredential = @{ name = 'KeyVaultName'; value = $keyVaultName; note = 'Key Vault name for DefaultAzureCredential' } }
}

if ($laWorkspaceId) {
    @{ HackboxCredential = @{ name = 'LogAnalyticsWorkspaceId'; value = $laWorkspaceId; note = 'Log Analytics workspace ID (Challenge 3)' } }
}

if ($laWorkspaceName) {
    @{ HackboxCredential = @{ name = 'LogAnalyticsWorkspaceName'; value = $laWorkspaceName; note = 'Log Analytics workspace name' } }
}

if ($appInsightsConnStr) {
    @{ HackboxCredential = @{ name = 'AppInsightsConnectionString'; value = $appInsightsConnStr; note = 'Application Insights connection string (Challenge 3, agent tracing)' } }
}

if ($appInsightsKey) {
    @{ HackboxCredential = @{ name = 'AppInsightsInstrumentationKey'; value = $appInsightsKey; note = 'Application Insights instrumentation key' } }
}

if ($eventHubNamespace) {
    @{ HackboxCredential = @{ name = 'EventHubNamespace'; value = $eventHubNamespace; note = 'Event Hub namespace for usage pipeline' } }
}

if ($storageAccountName) {
    @{ HackboxCredential = @{ name = 'StorageAccountName'; value = $storageAccountName; note = 'Storage account for Logic App state' } }
}

if ($apimName) {
    @{ HackboxCredential = @{ name = 'ApimName'; value = $apimName; note = 'API Management service name' } }
}

if ($salesAssistantKey) {
    @{ HackboxCredential = @{ name = 'SalesAssistantSubscriptionKey'; value = $salesAssistantKey; note = 'APIM subscription key for the Sales Assistant scenario' } }
}
if ($salesAssistantId) {
    @{ HackboxCredential = @{ name = 'SalesAssistantSubscriptionId'; value = $salesAssistantId; note = 'APIM subscription ID for the Sales Assistant scenario' } }
}

if ($hrChatAgentKey) {
    @{ HackboxCredential = @{ name = 'HrChatAgentSubscriptionKey'; value = $hrChatAgentKey; note = 'APIM subscription key for the HR ChatAgent scenario' } }
}
if ($hrChatAgentId) {
    @{ HackboxCredential = @{ name = 'HrChatAgentSubscriptionId'; value = $hrChatAgentId; note = 'APIM subscription ID for the HR ChatAgent scenario' } }
}

if ($supportBotKey) {
    @{ HackboxCredential = @{ name = 'SupportBotSubscriptionKey'; value = $supportBotKey; note = 'APIM subscription key for the Support Bot scenario' } }
}
if ($supportBotId) {
    @{ HackboxCredential = @{ name = 'SupportBotSubscriptionId'; value = $supportBotId; note = 'APIM subscription ID for the Support Bot scenario' } }
}

if ($universalLlmTestKey) {
    @{ HackboxCredential = @{ name = 'UniversalLlmTestSubscriptionKey'; value = $universalLlmTestKey; note = 'APIM subscription key for the Universal LLM Test scenario' } }
}
if ($universalLlmTestId) {
    @{ HackboxCredential = @{ name = 'UniversalLlmTestSubscriptionId'; value = $universalLlmTestId; note = 'APIM subscription ID for the Universal LLM Test scenario' } }
}

if ($unifiedAiTestKey) {
    @{ HackboxCredential = @{ name = 'UnifiedAiTestSubscriptionKey'; value = $unifiedAiTestKey; note = 'APIM subscription key for the Unified AI Test scenario' } }
}
if ($unifiedAiTestId) {
    @{ HackboxCredential = @{ name = 'UnifiedAiTestSubscriptionId'; value = $unifiedAiTestId; note = 'APIM subscription ID for the Unified AI Test scenario' } }
}

if ($piiMaskingKey) {
    @{ HackboxCredential = @{ name = 'PiiMaskingSubscriptionKey'; value = $piiMaskingKey; note = 'APIM subscription key for the PII Masking scenario' } }
}
if ($piiMaskingId) {
    @{ HackboxCredential = @{ name = 'PiiMaskingSubscriptionId'; value = $piiMaskingId; note = 'APIM subscription ID for the PII Masking scenario' } }
}

if ($piiBlockingKey) {
    @{ HackboxCredential = @{ name = 'PiiBlockingSubscriptionKey'; value = $piiBlockingKey; note = 'APIM subscription key for the PII Blocking scenario' } }
}
if ($piiBlockingId) {
    @{ HackboxCredential = @{ name = 'PiiBlockingSubscriptionId'; value = $piiBlockingId; note = 'APIM subscription ID for the PII Blocking scenario' } }
}

if ($piiAnalyticsKey) {
    @{ HackboxCredential = @{ name = 'PiiAnalyticsSubscriptionKey'; value = $piiAnalyticsKey; note = 'APIM subscription key for the PII Analytics scenario' } }
}
if ($piiAnalyticsId) {
    @{ HackboxCredential = @{ name = 'PiiAnalyticsSubscriptionId'; value = $piiAnalyticsId; note = 'APIM subscription ID for the PII Analytics scenario' } }
}

if ($llmBackendConfig) {
    @{ HackboxCredential = @{ name = 'LlmBackendConfig'; value = $llmBackendConfig; note = 'LLM backend routing config as raw JSON. Maps to notebook azd env key LLM_BACKEND_CONFIG' } }
}

if ($spokeFoundryAccountNameOut) {
    @{ HackboxCredential = @{ name = 'SpokeFoundryAccountName'; value = $spokeFoundryAccountNameOut; note = 'Spoke Foundry account name (Notebooks 7-9)' } }
    @{ HackboxCredential = @{ name = 'SpokeAiFoundryAccountName'; value = $spokeFoundryAccountNameOut; note = 'Alias of SpokeFoundryAccountName. Maps to notebook azd env key SPOKE_AI_FOUNDRY_ACCOUNT_NAME' } }
    @{ HackboxCredential = @{ name = 'A2aFoundryAccountName'; value = $spokeFoundryAccountNameOut; note = 'Agent-hosting Foundry account for Challenge 8. Maps to notebook env key A2A_FOUNDRY_ACCOUNT_NAME' } }
}
if ($spokeFoundryProjectNameOut) {
    @{ HackboxCredential = @{ name = 'SpokeFoundryProjectName'; value = $spokeFoundryProjectNameOut; note = 'Spoke Foundry project name (Notebooks 7-9)' } }
    @{ HackboxCredential = @{ name = 'SpokeAiFoundryProjectName'; value = $spokeFoundryProjectNameOut; note = 'Alias of SpokeFoundryProjectName. Maps to notebook azd env key SPOKE_AI_FOUNDRY_PROJECT_NAME' } }
}
if ($spokeKeyVaultNameOut) {
    @{ HackboxCredential = @{ name = 'SpokeKeyVaultName'; value = $spokeKeyVaultNameOut; note = 'Spoke Key Vault name for DefaultAzureCredential. Maps to notebook azd env key SPOKE_KEY_VAULT_NAME' } }
}
if ($spokeAcrNameOut) {
    @{ HackboxCredential = @{ name = 'SpokeAcrName'; value = $spokeAcrNameOut; note = 'Spoke Azure Container Registry name. Maps to notebook azd env key SPOKE_ACR_NAME' } }
}
if ($spokeAcrLoginServerOut) {
    @{ HackboxCredential = @{ name = 'SpokeAcrLoginServer'; value = $spokeAcrLoginServerOut; note = 'Spoke Azure Container Registry login server. Maps to notebook azd env key SPOKE_ACR_LOGIN_SERVER' } }
}
