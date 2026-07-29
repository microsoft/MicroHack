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

  Provisioning engine (both options are supported):
    - DEFAULT: deploys infra/resources.bicep (resource-group-scoped) via
      New-AzResourceGroupDeployment. This is the path used by the platform and by `azd up`.
    - -UseArm: deploys the equivalent ARM template infra/azuredeploy.json
      (subscription-scoped) via New-AzSubscriptionDeployment. Because that template
      creates its own resource group, -UseArm is only honoured in 'subscription' mode
      (or manual runs); in 'resourcegroup' modes it falls back to Bicep to respect the
      pre-created RG contract.

  Robustness:
    - Region fallback: the deployment is retried across $PreferredLocation (then
      swedencentral -> westeurope -> norwayeast) until one region succeeds.
    - Claude quota preflight: before each region attempt, Anthropic GlobalStandard
      quota for claude-opus-4-8 is probed; deployClaudeModel is set to 'false' when the
      region lacks the model or quota, so a Claude-less subscription still gets GPT +
      full infra instead of failing the entire deploy. Override with env
      DEPLOY_CLAUDE_MODEL=true|false.
    - Multi-user RBAC: every id in $AllowedEntraUserIds is granted the data-plane
      roles (not just the first), so team labs work for all members. Idempotent.
    - Grounding RBAC: the Foundry account AND project managed identities are granted
      Search Index Data Reader + Search Service Contributor so Foundry IQ agentic
      retrieval works (both identities, idempotent — also remediates older labs).
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

    [string[]]$AllowedEntraUserIds = @(),

    # Opt into the ARM (azuredeploy.json) engine instead of Bicep. Subscription-scoped;
    # see the header for the resourcegroup-mode fallback behaviour.
    [switch]$UseArm
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

function Get-MhhClaudeDeployFlag {
    <#
      Claude (Anthropic) quota preflight. Returns the STRING 'true'/'false' for the
      template's deployClaudeModel param, decided per-region.

      Why: claude-opus-4-8 is only offered in a subset of regions (e.g. swedencentral,
      NOT francecentral/norwayeast) and many lab subscriptions have ZERO Anthropic
      quota. Hardcoding deployClaudeModel=true made the ENTIRE deployment fail (quota
      preflight / "model not found") even though GPT + all other infra would have
      succeeded — and the region-fallback loop then failed everywhere. The Bicep/ARM
      templates already fall the drafting agent back to the GPT orchestrator when
      Claude is skipped (Clause & Risk keeps its own gpt-5.6-sol deployment), so gating on real quota here
      makes the deploy "just work" for every attendee: they get GPT + full infra, and
      Claude only when their subscription can actually host it.

      Signal: Cognitive Services usages expose a per-model quota family named
      'AIServices.GlobalStandard.claude-opus-4-8'. limit=0 (or < the requested
      capacity) means the deployment would fail -> skip Claude.

      Override: set env DEPLOY_CLAUDE_MODEL=true|false to force the decision and skip
      the probe (mirrors deploy.sh / deploy.ps1). Any probe/API failure fails SAFE to
      'false' so a transient error never sinks the whole deployment.
    #>
    param([string]$Region, [string]$SubscriptionId, [int]$RequiredCapacity = 20)

    $modelName   = 'claude-opus-4-8'
    $quotaFamily = "AIServices.GlobalStandard.$modelName"

    $override = $env:DEPLOY_CLAUDE_MODEL
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        $o = $override.Trim().ToLower()
        if ($o -in @('true', 'false')) {
            Write-Host "[INFO]  Claude preflight: DEPLOY_CLAUDE_MODEL override='$o' (skipping quota probe)."
            return $o
        }
        Write-Host "[WARN]  Claude preflight: ignoring unrecognised DEPLOY_CLAUDE_MODEL='$override' (expected true/false)."
    }

    try {
        $uri  = "/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Region/usages?api-version=2024-10-01"
        $resp = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction Stop
        if ($resp.StatusCode -ne 200) { throw "usages query returned HTTP $($resp.StatusCode)" }
        $usages = ($resp.Content | ConvertFrom-Json).value

        $entry = $usages | Where-Object { $_.name.value -eq $quotaFamily } | Select-Object -First 1
        if (-not $entry) {
            $entry = $usages |
                Where-Object { $_.name.value -match [regex]::Escape($modelName) } |
                Sort-Object { [double]$_.limit } -Descending |
                Select-Object -First 1
        }

        if (-not $entry) {
            Write-Host "[WARN]  Claude preflight: no Anthropic quota entry for '$modelName' in '$Region' -> deploying GPT-only (deployClaudeModel=false)."
            return 'false'
        }

        $limit     = [double]$entry.limit
        $used      = [double]$entry.currentValue
        $available = $limit - $used
        if ($limit -le 0 -or $available -lt $RequiredCapacity) {
            Write-Host "[WARN]  Claude preflight: insufficient Anthropic quota in '$Region' (limit=$limit, used=$used, need=$RequiredCapacity) -> deploying GPT-only (deployClaudeModel=false)."
            return 'false'
        }

        Write-Host "[OK]    Claude preflight: '$modelName' deployable in '$Region' (quota limit=$limit, used=$used, free=$available)."
        return 'true'
    }
    catch {
        Write-Host "[WARN]  Claude preflight: quota probe failed for '$Region' ($($_.Exception.Message)) -> deploying GPT-only (deployClaudeModel=false) to stay resilient."
        return 'false'
    }
}

# --- Region fallback list ---------------------------------------------------
# Honour the platform's ordered preference; fall back across regions that offer the
# gpt-5.4 / gpt-5-mini deployments and the Anthropic Claude Opus 4.8 marketplace offer.
$candidateRegions = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @('swedencentral', 'westeurope', 'norwayeast') }

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$bicepFile  = Join-Path $scriptPath 'infra/resources.bicep'
$armFile    = Join-Path $scriptPath 'infra/azuredeploy.json'

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

# --- Choose the engine ------------------------------------------------------
$armRequested = $UseArm.IsPresent
if ($armRequested -and $DeploymentType -ne 'subscription') {
    Write-Host "[WARN]  -UseArm uses the subscription-scoped ARM template (creates its own resource group), which conflicts with '$DeploymentType' mode (RG pre-created). Falling back to the resource-group-scoped Bicep template."
    $armRequested = $false
}

$deployOutputs          = $null
$effectiveResourceGroup = $null
$effectiveLocation      = $null

if ($armRequested) {
    # ---- ARM path: subscription-scoped azuredeploy.json, region fallback ----
    Write-Host "[INFO]  Engine: ARM (infra/azuredeploy.json), subscription-scoped."
    foreach ($region in $candidateRegions) {
        Write-Host "[INFO]  Deploying ARM template in '$region'..."
        $wantClaude = Get-MhhClaudeDeployFlag -Region $region -SubscriptionId $SubscriptionId
        try {
            $d = New-AzSubscriptionDeployment `
                -Location $region `
                -TemplateFile $armFile `
                -environmentName 'clm-microhack' `
                -location $region `
                -principalId $primaryPrincipalId `
                -principalType 'User' `
                -deployClaudeModel $wantClaude `
                -deploySql 'false' `
                -deployBing 'false' `
                -ErrorAction Stop
            $deployOutputs     = $d.Outputs
            $effectiveLocation = $region
            break
        }
        catch {
            Write-Host "[WARN]  ARM deployment failed in '$region': $_ — trying next region."
        }
    }
    if (-not $deployOutputs) { throw "ARM deployment failed in all candidate regions: $($candidateRegions -join ', ')" }
    $effectiveResourceGroup = Get-OutVal $deployOutputs 'AZURE_RESOURCE_GROUP'
}
else {
    # ---- Bicep path (default): resource-group-scoped resources.bicep --------
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
        $wantClaude = Get-MhhClaudeDeployFlag -Region $region -SubscriptionId $SubscriptionId
        try {
            $d = New-AzResourceGroupDeployment `
                -ResourceGroupName $effectiveResourceGroup `
                -TemplateFile $bicepFile `
                -location $region `
                -resourceToken $resourceToken `
                -principalId $primaryPrincipalId `
                -principalType 'User' `
                -deployClaudeModel $wantClaude `
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
}

Write-Host "[OK]    Provisioning complete in '$effectiveLocation' (resource group '$effectiveResourceGroup')."

# --- Multi-user data-plane RBAC ---------------------------------------------
# The template grants roles to the first user; re-granting is idempotent and — by
# looping every id — extends access to the whole team. Resources are discovered from
# the RG so this works identically for the Bicep and ARM engines.
if ($AllowedEntraUserIds.Count -gt 0 -and $effectiveResourceGroup) {
    $account = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.CognitiveServices/accounts' -ErrorAction SilentlyContinue | Select-Object -First 1
    $search  = Get-AzResource -ResourceGroupName $effectiveResourceGroup -ResourceType 'Microsoft.Search/searchServices' -ErrorAction SilentlyContinue | Select-Object -First 1

    # Built-in role definition ids (match infra/resources.bicep).
    $accountRoles = [ordered]@{
        'Azure AI Developer'      = '64702f94-c441-49e6-a78b-ef80e0188fee'
        'Cognitive Services User' = 'a97b65f3-24c7-4388-baec-2e87135dc908'
    }
    $searchRoles = [ordered]@{
        'Search Index Data Contributor' = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
        'Search Service Contributor'    = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    }

    foreach ($userId in $AllowedEntraUserIds) {
        if ($account) {
            foreach ($roleName in $accountRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $accountRoles[$roleName] -RoleName $roleName -Scope $account.ResourceId }
        }
        if ($search) {
            foreach ($roleName in $searchRoles.Keys) { Grant-MhhRole -ObjectId $userId -RoleId $searchRoles[$roleName] -RoleName $roleName -Scope $search.ResourceId }
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
        }
    }
}

# --- Return credentials / endpoints to the user dashboard -------------------
# The platform captures every @{ HackboxCredential = ... } written to the output stream.
$projectEndpoint = Get-OutVal $deployOutputs 'AZURE_AI_PROJECT_ENDPOINT'
$searchEndpoint  = Get-OutVal $deployOutputs 'AZURE_SEARCH_ENDPOINT'
$searchIndex     = Get-OutVal $deployOutputs 'AZURE_SEARCH_INDEX'
$modelOrch       = Get-OutVal $deployOutputs 'MODEL_ORCHESTRATOR'
$modelDraft      = Get-OutVal $deployOutputs 'MODEL_DRAFTING'
$modelClauseRisk = Get-OutVal $deployOutputs 'MODEL_CLAUSE_RISK'
$modelRenewal    = Get-OutVal $deployOutputs 'MODEL_RENEWAL'

Write-Host ""
Write-Host "==================== Your CLM microhack environment ===================="
Write-Host "  Resource group          : $effectiveResourceGroup ($effectiveLocation)"
Write-Host "  Foundry project endpoint: $projectEndpoint"
Write-Host "  Azure AI Search endpoint: $searchEndpoint (index '$searchIndex')"
Write-Host "  Models                  : orchestrator=$modelOrch, drafting=$modelDraft, clause-risk=$modelClauseRisk, renewal=$modelRenewal"
Write-Host "  Next                    : paste these into the repo-root .env (see Challenge 1)."
Write-Host "========================================================================"

# Surface the Claude preflight outcome from the template's authoritative output:
# MODEL_DRAFTING is claude-opus-4-8 when Claude deployed, else the GPT orchestrator.
if ($modelDraft -and $modelDraft -notmatch 'claude') {
    Write-Host "[WARN]  Claude was not deployed in '$effectiveLocation' (no Anthropic quota / model not offered). The Drafting agent runs on '$modelDraft' instead (Clause & Risk stays on '$modelClauseRisk'). Grant Anthropic quota (or set DEPLOY_CLAUDE_MODEL=true) and redeploy to enable the Claude bake-off in Challenge 3."
}

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
