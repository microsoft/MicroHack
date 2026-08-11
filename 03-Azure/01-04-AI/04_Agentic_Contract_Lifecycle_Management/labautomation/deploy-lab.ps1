<#
  deploy-lab.ps1 — EMEA MicroHack platform entry point for the Foundry CLM microhack.

  The microsoft/MicroHack platform invokes THIS script (never deploy.ps1/.sh) to
  provision a team's environment. It passes the parameter block below verbatim and
  SILENTLY SKIPS the script if the contract does not match exactly. The platform:
    - has already set the Az context to $SubscriptionId  -> do NOT Connect-AzAccount
    - for 'resourcegroup' modes: pre-created the RG and granted Owner -> do NOT New-AzResourceGroup
    - for 'subscription' mode: granted Owner on the subscription -> we create the RG ourselves
      with a deterministic per-user name via Get-MhhStableHash
    - imported Az.Accounts and Az.Resources for us

  Provisioning engine:
    - Deploys infra/resources.bicep (resource-group-scoped) via
      New-AzResourceGroupDeployment. This is the path used by the platform and by `azd up`.

  Robustness:
    - Region fallback: the deployment is retried across $PreferredLocation (then
      swedencentral -> westeurope -> norwayeast) until one region succeeds.
    - Multi-user RBAC: every id in $AllowedEntraUserIds is granted the data-plane
      roles (not just the first), so team labs work for all members. Idempotent.
    - Grounding RBAC: the Foundry account AND project managed identities are granted
      Search Index Data Reader + Search Service Contributor so Foundry IQ agentic
      retrieval works. The Search identity receives Cognitive Services User on Foundry
      for query planning (all grants are idempotent and remediate older labs).
    - Console output: [INFO]/[OK]/[WARN] progress plus @{ HackboxCredential = ... }
      records that surface every endpoint / model name to the team dashboard.

  deploy.ps1 / deploy.sh remain the local/Codespaces path; this script is the platform path.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

# --- Helpers ----------------------------------------------------------------
function Get-OutVal {
    param($Outputs, [string]$Key)
    if ($Outputs -and $Outputs.ContainsKey($Key)) { return "$($Outputs[$Key].Value)" }
    return ''
}

function Grant-MhhRole {
    param([string]$ObjectId, [string]$RoleId, [string]$RoleName, [string]$Scope)
    if ([string]::IsNullOrWhiteSpace($ObjectId) -or [string]::IsNullOrWhiteSpace($Scope)) { return }
    $existing = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionId $RoleId -ErrorAction SilentlyContinue
    if ($existing) { Write-Host "[OK]    '$RoleName' already granted to $ObjectId."; return }
    try {
        New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionId $RoleId -Scope $Scope -ErrorAction Stop | Out-Null
        Write-Host "[OK]    Granted '$RoleName' to $ObjectId."
    }
    catch {
        Write-Host "[WARN]  Could not grant '$RoleName' to ${ObjectId}: $_"
    }
}

function Get-MhhIdentityPrincipalId {
    param([string]$ResourceId)
    if ([string]::IsNullOrWhiteSpace($ResourceId)) { return '' }
    try {
        $res = Get-AzResource -ResourceId $ResourceId -ExpandProperties -ErrorAction Stop
        return "$($res.Identity.PrincipalId)"
    }
    catch {
        Write-Host "[WARN]  Could not resolve managed identity for ${ResourceId}: $_"
        return ''
    }
}

# --- Region fallback list ---------------------------------------------------
# Honour the platform's ordered preference; fall back across regions that offer the
# gpt-5.4 / gpt-5.4-nano / gpt-5.6-sol deployments.
$candidateRegions = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @('swedencentral', 'westeurope', 'norwayeast') }

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$bicepFile  = Join-Path $scriptPath 'infra/resources.bicep'

# Primary RBAC principal — passed into the template (which grants the first user).
# The multi-user loop below covers every remaining member of a team lab.
$primaryPrincipalId = if ($AllowedEntraUserIds.Count -gt 0) { $AllowedEntraUserIds[0] } else { '' }
$tags = @{ project = 'foundry-clm-microhack'; 'lab-deployment-type' = $DeploymentType }

# Guard: ALL participant data-plane RBAC is keyed off $AllowedEntraUserIds — both the
# template's first-user grant (via principalId) and the multi-user loop after provisioning.
# An empty list therefore leaves participants with ZERO data-plane roles, so Challenge 1
# corpus seeding fails on BOTH paths: the SharePoint indexer and the local-PDF fallback each
# need 'Search Index Data Contributor'. The MicroHack platform always passes the lab's
# participant object id(s) here (one job per lab); warn loudly if a manual/misconfigured run
# did not, since the deploy otherwise "succeeds" while leaving the user unable to seed.
if ($AllowedEntraUserIds.Count -eq 0) {
    Write-Host "[WARN]  AllowedEntraUserIds is EMPTY — no participant will receive data-plane RBAC"
    Write-Host "[WARN]  (Search Index Data Contributor, Azure AI Developer, Cognitive Services User,"
    Write-Host "[WARN]  Search Service Contributor). Challenge 1 corpus seeding will fail for BOTH the"
    Write-Host "[WARN]  SharePoint indexer and the local-PDF fallback until a user holds those roles."
    Write-Host "[WARN]  The platform normally sets this per lab; for a manual run pass"
    Write-Host "[WARN]  -AllowedEntraUserIds <entraObjectId> (comma-separate ids for a team lab)."
}

$deployOutputs          = $null
$effectiveResourceGroup = $null
$effectiveLocation      = $null

# --- Deploy the resource-group-scoped Bicep template ------------------------
Write-Host "[INFO]  Engine: Bicep (infra/resources.bicep), resource-group-scoped."

# Resolve / create the resource group per the platform contract (once).
if ($DeploymentType -eq 'subscription') {
    $hashInput = if ($AllowedEntraUserIds.Count -gt 0) { $AllowedEntraUserIds } else { @($SubscriptionId) }
    $stableHash = Get-MhhStableHash $hashInput -Length 24
    $effectiveResourceGroup = "rg-clm-microhack-$stableHash"
    New-AzResourceGroup -Name $effectiveResourceGroup -Location $candidateRegions[0] -Force | Out-Null
}
else {
    # 'resourcegroup' / 'resourcegroup-with-subscriptionowner': RG pre-created, we hold Owner.
    $effectiveResourceGroup = $ResourceGroupName
}

# Deterministic token for globally-unique resource names (RG-name based, so it is
# stable across region retries). resources.bicep names Search/Foundry as clm*${token}.
$resourceToken = (Get-MhhStableHash "$SubscriptionId-$effectiveResourceGroup" -Length 13).ToLower()

foreach ($region in $candidateRegions) {
    Write-Host "[INFO]  Deploying Bicep -> RG '$effectiveResourceGroup' in '$region' (token '$resourceToken')..."
    try {
        $d = New-AzResourceGroupDeployment `
            -ResourceGroupName $effectiveResourceGroup `
            -TemplateFile $bicepFile `
            -location $region `
            -resourceToken $resourceToken `
            -principalId $primaryPrincipalId `
            -principalType 'User' `
            -deploySql 'false' `
            -deployBing 'false' `
            -tags $tags `
            -ErrorAction Stop
        $deployOutputs     = $d.Outputs
        $effectiveLocation = $region
        break
    }
    catch {
        Write-Host "[WARN]  Bicep deployment failed in '$region': $_ — trying next region."
    }
}
if (-not $deployOutputs) { throw "Bicep deployment failed in all candidate regions: $($candidateRegions -join ', ')" }

Write-Host "[OK]    Provisioning complete in '$effectiveLocation' (resource group '$effectiveResourceGroup')."

# --- Multi-user data-plane RBAC ---------------------------------------------
# The template grants roles to the first user; re-granting is idempotent and — by
# looping every id — extends access to the whole team. Resources are discovered from
# the RG so this works identically for the Bicep and ARM engines.
if ($AllowedEntraUserIds.Count -gt 0 -and $effectiveResourceGroup) {
    $account = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.CognitiveServices/accounts' -ErrorAction SilentlyContinue | Select-Object -First 1
    $search  = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.Search/searchServices' -ErrorAction SilentlyContinue | Select-Object -First 1
    $appInsightsRes  = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.Insights/components' -ErrorAction SilentlyContinue | Select-Object -First 1
    $logAnalyticsRes = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.OperationalInsights/workspaces' -ErrorAction SilentlyContinue | Select-Object -First 1

    # Built-in role definition ids (match infra/resources.bicep).
    $accountRoles = [ordered]@{
        'Azure AI Developer'      = '64702f94-c441-49e6-a78b-ef80e0188fee'
        'Cognitive Services User' = 'a97b65f3-24c7-4388-baec-2e87135dc908'
    }
    $searchRoles = [ordered]@{
        'Search Index Data Contributor' = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
        'Search Service Contributor'    = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    }
    # Monitoring read access so the Foundry portal Monitor dashboard (Challenge 3)
    # passes its "Verifying access" check. Missing before → users saw a permanent
    # "Setup incomplete" banner even though App Insights was connected.
    $monitorAppInsightsRoles = [ordered]@{
        'Monitoring Reader' = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
    }
    $monitorLogAnalyticsRoles = [ordered]@{
        'Log Analytics Reader' = '73c42c96-874c-492b-b04d-ab87d138a893'
    }

    foreach ($userId in $AllowedEntraUserIds) {
        if ($account) {
            foreach ($roleName in $accountRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $accountRoles[$roleName] -RoleName $roleName -Scope $account.ResourceId }
        }
        if ($search) {
            foreach ($roleName in $searchRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $searchRoles[$roleName] -RoleName $roleName -Scope $search.ResourceId }
        }
        if ($appInsightsRes) {
            foreach ($roleName in $monitorAppInsightsRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $monitorAppInsightsRoles[$roleName] -RoleName $roleName -Scope $appInsightsRes.ResourceId }
        }
        if ($logAnalyticsRes) {
            foreach ($roleName in $monitorLogAnalyticsRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $monitorLogAnalyticsRoles[$roleName] -RoleName $roleName -Scope $logAnalyticsRes.ResourceId }
        }
    }
}

# --- Grounding managed-identity RBAC (Foundry IQ agentic retrieval) ----------
# Foundry agentic retrieval runs under the Foundry account AND/OR project managed
# identity and needs BOTH Search Index Data Reader (query the index) and Search
# Service Contributor (read the index / semantic-config definition). The template
# grants these at deploy time; re-granting here is idempotent and — critically —
# remediates labs provisioned before this fix WITHOUT a full redeploy. A missing
# grant surfaces at runtime as:
#   400 tool_user_error ... Access denied, check managed identity access to search service
if ($effectiveResourceGroup) {
    $account = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.CognitiveServices/accounts' -ErrorAction SilentlyContinue | Select-Object -First 1
    $project = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.CognitiveServices/accounts/projects' -ErrorAction SilentlyContinue | Select-Object -First 1
    $search  = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.Search/searchServices' -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($search) {
        $searchMiRoles = [ordered]@{
            'Search Index Data Reader'   = '1407120a-92aa-4202-b7e9-c0e197c71c8f'
            'Search Service Contributor' = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
        }
        $groundingPrincipals = @()
        if ($account) { $groundingPrincipals += Get-MhhIdentityPrincipalId $account.ResourceId }
        if ($project) { $groundingPrincipals += Get-MhhIdentityPrincipalId $project.ResourceId }

        foreach ($mi in ($groundingPrincipals | Where-Object { $_ })) {
            foreach ($roleName in $searchMiRoles.Keys) {
                Grant-MhhRole -ObjectId $mi -RoleId $searchMiRoles[$roleName] -RoleName $roleName -Scope $search.ResourceId
            }

            if ($account) {
                $searchPrincipalId = Get-MhhIdentityPrincipalId $search.ResourceId
                Grant-MhhRole -ObjectId $searchPrincipalId `
                    -RoleId 'a97b65f3-24c7-4388-baec-2e87135dc908' `
                    -RoleName 'Cognitive Services User' `
                    -Scope $account.ResourceId
            }
        }
    }
}

# --- Return credentials / endpoints to the user dashboard -------------------
# The platform captures every @{ HackboxCredential = ... } written to the output stream.
$projectEndpoint = Get-OutVal $deployOutputs 'AZURE_AI_PROJECT_ENDPOINT'
$searchEndpoint  = Get-OutVal $deployOutputs 'AZURE_SEARCH_ENDPOINT'
$searchIndex     = Get-OutVal $deployOutputs 'AZURE_SEARCH_INDEX'
$iqSource        = Get-OutVal $deployOutputs 'FOUNDRY_IQ_KNOWLEDGE_SOURCE'
$iqBase          = Get-OutVal $deployOutputs 'FOUNDRY_IQ_KNOWLEDGE_BASE'
$iqConnection    = Get-OutVal $deployOutputs 'FOUNDRY_IQ_CONNECTION_NAME'
$iqApiVersion    = Get-OutVal $deployOutputs 'FOUNDRY_IQ_API_VERSION'
$modelOrch       = Get-OutVal $deployOutputs 'MODEL_ORCHESTRATOR'
$modelDraft      = Get-OutVal $deployOutputs 'MODEL_DRAFTING'
$modelClauseRisk = Get-OutVal $deployOutputs 'MODEL_CLAUSE_RISK'
$modelRenewal    = Get-OutVal $deployOutputs 'MODEL_RENEWAL'
$appInsights     = Get-OutVal $deployOutputs 'APPLICATIONINSIGHTS_CONNECTION_STRING'

Write-Host ""
Write-Host "==================== Your CLM microhack environment ===================="
Write-Host "  Resource group          : $effectiveResourceGroup ($effectiveLocation)"
Write-Host "  Foundry project endpoint: $projectEndpoint"
Write-Host "  Azure AI Search endpoint: $searchEndpoint (index '$searchIndex')"
Write-Host "  Foundry IQ              : source=$iqSource, knowledge-base=$iqBase, connection=$iqConnection"
Write-Host "  Models                  : orchestrator=$modelOrch, drafting=$modelDraft, clause-risk=$modelClauseRisk, renewal=$modelRenewal"
Write-Host "  App Insights            : $(if ($appInsights) { 'connection string ready' } else { '(none)' })"
Write-Host "  Next                    : paste these into the repo-root .env (see Challenge 1)."
Write-Host "========================================================================"

@{ HackboxCredential = @{ name = 'ResourceGroup'; value = $effectiveResourceGroup; note = 'Resource group holding your CLM microhack resources' } }

if ($projectEndpoint) {
    @{ HackboxCredential = @{ name = 'FoundryProjectEndpoint'; value = $projectEndpoint; note = 'Microsoft Foundry project endpoint -> AZURE_AI_PROJECT_ENDPOINT in .env' } }
}
if ($searchEndpoint) {
    @{ HackboxCredential = @{ name = 'SearchEndpoint'; value = $searchEndpoint; note = 'Azure AI Search endpoint -> AZURE_SEARCH_ENDPOINT in .env' } }
}
if ($searchIndex) {
    @{ HackboxCredential = @{ name = 'SearchIndex'; value = $searchIndex; note = 'Azure AI Search index name -> AZURE_SEARCH_INDEX in .env' } }
}
if ($iqSource) {
    @{ HackboxCredential = @{ name = 'FoundryIQKnowledgeSource'; value = $iqSource; note = 'Created by seed_corpus.py -> FOUNDRY_IQ_KNOWLEDGE_SOURCE in .env' } }
}
if ($iqBase) {
    @{ HackboxCredential = @{ name = 'FoundryIQKnowledgeBase'; value = $iqBase; note = 'Foundry IQ knowledge base -> FOUNDRY_IQ_KNOWLEDGE_BASE in .env' } }
}
if ($iqConnection) {
    @{ HackboxCredential = @{ name = 'FoundryIQConnection'; value = $iqConnection; note = 'Foundry project RemoteTool connection -> FOUNDRY_IQ_CONNECTION_NAME in .env' } }
}
if ($iqApiVersion) {
    @{ HackboxCredential = @{ name = 'FoundryIQApiVersion'; value = $iqApiVersion; note = 'Azure AI Search knowledge API -> FOUNDRY_IQ_API_VERSION in .env' } }
}
if ($modelOrch) {
    @{ HackboxCredential = @{ name = 'ModelOrchestrator'; value = $modelOrch; note = 'Orchestrator model deployment -> MODEL_ORCHESTRATOR in .env' } }
}
if ($modelDraft) {
    @{ HackboxCredential = @{ name = 'ModelDrafting'; value = $modelDraft; note = 'Drafting model deployment -> MODEL_DRAFTING in .env' } }
}
if ($modelClauseRisk) {
    @{ HackboxCredential = @{ name = 'ModelClauseRisk'; value = $modelClauseRisk; note = 'Clause & Risk model deployment -> MODEL_CLAUSE_RISK in .env' } }
}
if ($modelRenewal) {
    @{ HackboxCredential = @{ name = 'ModelRenewal'; value = $modelRenewal; note = 'Renewal model deployment -> MODEL_RENEWAL in .env' } }
}
if ($appInsights) {
    @{ HackboxCredential = @{ name = 'AppInsightsConnectionString'; value = $appInsights; note = 'Application Insights connection string -> APPLICATIONINSIGHTS_CONNECTION_STRING in .env (Challenge 3)' } }
}
