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
$effectiveLocation = $candidateRegions[0]
$effectiveRG = $ResourceGroupName

# Deterministic token for resource naming (based on subscription + RG).
# Ensures hub and spoke resources don't collide and survive re-runs.
$stableHash = (Get-MhhStableHash $AllowedEntraUserIds -Length 12).ToLower()
$resourceToken = (Get-MhhStableHash "$SubscriptionId-$effectiveRG" -Length 13).ToLower()

# Resource naming
$hubFoundryAccountName = "aif-hub-$stableHash"
$hubFoundryProjectName = "citadel-hub-project"
$spokeFoundryAccountName = "aif-spoke-$stableHash"
$spokeFoundryProjectName = "citadel-agents-project"
$apimName = "apim-citadel-$stableHash"
$cosmosName = "cos-citadel-$stableHash"
$keyVaultName = "kv-hub-$stableHash"
$laName = "law-citadel-$stableHash"
$aiName = "appi-citadel-$stableHash"

Write-Host "[INFO]  Deploying Citadel Agentic Governance Hub + Spoke into RG '$effectiveRG'..."

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$bicepFile = Join-Path $scriptPath 'infra/resources.bicep'

if (-not (Test-Path $bicepFile)) {
    throw "Bicep template not found at '$bicepFile'. Ensure infra/resources.bicep exists."
}

$primaryPrincipalId = if ($AllowedEntraUserIds.Count -gt 0) { $AllowedEntraUserIds[0] } else { '' }
$tags = @{ project = 'citadel-agentic-governance'; 'lab-deployment-type' = $DeploymentType }

# Guard: ALL participant data-plane RBAC is keyed off $AllowedEntraUserIds.
# An empty list leaves participants with ZERO data-plane roles, breaking notebook execution.
if ($AllowedEntraUserIds.Count -eq 0) {
    Write-Host "[WARN]  AllowedEntraUserIds is EMPTY — no participant will receive data-plane RBAC"
    Write-Host "[WARN]  (Azure AI User, Cognitive Services User, Cosmos DB Data Contributor)."
    Write-Host "[WARN]  Notebooks will fail. The platform normally sets this per lab; for manual runs,"
    Write-Host "[WARN]  pass -AllowedEntraUserIds <entraObjectId> (comma-separate ids for a team lab)."
}

$deployOutputs = $null
$effectiveLocation = $null

Write-Host "[INFO]  Engine: Bicep (infra/resources.bicep), resource-group-scoped."

foreach ($region in $candidateRegions) {
    Write-Host "[INFO]  Deploying Bicep → RG '$effectiveRG' in '$region'..."
    try {
        $d = New-AzResourceGroupDeployment `
            -ResourceGroupName $effectiveRG `
            -TemplateFile $bicepFile `
            -location $region `
            -resourceToken $resourceToken `
            -principalId $primaryPrincipalId `
            -principalType 'User' `
            -tags $tags `
            -ErrorAction Stop
        $deployOutputs = $d.Outputs
        $effectiveLocation = $region
        break
    }
    catch {
        Write-Host "[WARN]  Bicep deployment failed in '$region': $_ — trying next region."
    }
}

if (-not $deployOutputs) {
    throw "Bicep deployment failed in all candidate regions: $($candidateRegions -join ', ')"
}

Write-Host "[OK]    Provisioning complete in '$effectiveLocation' (resource group '$effectiveRG')."

# --- Managed Identity Readiness Check ---
# Hub and Spoke Foundry accounts have system-assigned managed identities that may not be
# immediately available after creation. Wait for them to be readable before granting RBAC.
Write-Host "[INFO]  Verifying managed identity availability..."
$hubAccount = Get-AzResource `
    -ResourceGroupName $effectiveRG `
    -ResourceType 'Microsoft.CognitiveServices/accounts' `
    -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "aif-hub-*" } | Select-Object -First 1

$spokeAccount = Get-AzResource `
    -ResourceGroupName $effectiveRG `
    -ResourceType 'Microsoft.CognitiveServices/accounts' `
    -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "aif-spoke-*" } | Select-Object -First 1

$maxWaitSecs = 120
$waitInterval = 10
$elapsed = 0

while ($elapsed -lt $maxWaitSecs) {
    $hubMIReady = $false
    $spokeMIReady = $false

    if ($hubAccount) {
        $hubMI = Get-AzResource -ResourceId $hubAccount.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
        if ($hubMI -and $hubMI.Identity.PrincipalId) {
            $hubMIReady = $true
        }
    }

    if ($spokeAccount) {
        $spokeMI = Get-AzResource -ResourceId $spokeAccount.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
        if ($spokeMI -and $spokeMI.Identity.PrincipalId) {
            $spokeMIReady = $true
        }
    }

    if ($hubMIReady -and $spokeMIReady) {
        Write-Host "[OK]    Managed identities are ready."
        break
    }

    if ($elapsed -eq 0) {
        Write-Host "[INFO]  Waiting for managed identities to become available... (up to ${maxWaitSecs}s)"
    }

    Start-Sleep -Seconds $waitInterval
    $elapsed += $waitInterval
}

if ($hubAccount -and -not $hubMIReady) {
    Write-Host "[WARN]  Hub Foundry managed identity did not become ready within ${maxWaitSecs}s. RBAC grants may fail."
}

# --- Multi-user data-plane RBAC ---
# Grant Foundry and Cosmos DB access to all attendees so team labs work for every member.
if ($AllowedEntraUserIds.Count -gt 0 -and $effectiveRG) {
    $account = $hubAccount

    $cosmos = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.DocumentDB/databaseAccounts' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $keyVault = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.KeyVault/vaults' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $appInsightsRes = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.Insights/components' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $logAnalyticsRes = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.OperationalInsights/workspaces' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $apim = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.ApiManagement/service' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $acr = Get-AzResource `
        -ResourceGroupName $effectiveRG `
        -ResourceType 'Microsoft.ContainerRegistry/registries' `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    # RBAC role IDs (built-in)
    $foundryRoles = [ordered]@{
        'Azure AI User'           = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
        'Cognitive Services User' = 'a97b65f3-24c7-4388-baec-2e87135dc908'
    }

    $cosmosDataRole = '00000000-0000-0000-0000-000000000002'  # Cosmos DB Built-in Data Contributor

    $keyVaultRoles = [ordered]@{
        'Key Vault Secrets Officer' = 'b86a8fe4-44ce-4948-aee5-eccb2c155090'
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

    foreach ($userId in $AllowedEntraUserIds) {
        # Foundry data-plane RBAC
        if ($account) {
            foreach ($roleName in $foundryRoles.Keys) {
                $roleId = $foundryRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $account.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on Foundry."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $account.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on Foundry."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        }

        # Cosmos DB data-plane RBAC (via REST because Az.CosmosDB module is complex)
        if ($cosmos) {
            $cosmosBase = $cosmos.ResourceId
            $cosmosApi = "2024-11-15"
            $cosmosRoleUri = "$cosmosBase/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002?api-version=$cosmosApi"
            $existingRAs = Invoke-AzRestMethod -Method GET -Path "$cosmosBase/sqlRoleAssignments?api-version=$cosmosApi" -ErrorAction SilentlyContinue
            $raList = if ($existingRAs.StatusCode -eq 200) { ($existingRAs.Content | ConvertFrom-Json).value } else { @() }

            $already = $raList | Where-Object { $_.properties.principalId -eq $userId -and $_.properties.roleDefinitionId -like "*000000000002" }
            if ($already) {
                Write-Host "[OK]    Cosmos DB data role already granted to $userId."
                continue
            }

            try {
                $assignId = [guid]::NewGuid().ToString()
                $raBody = @{ properties = @{
                    roleDefinitionId = $cosmosRoleUri
                    principalId = $userId
                    scope = $cosmosBase
                } } | ConvertTo-Json -Depth 5
                Invoke-AzRestMethod -Method PUT -Path "$cosmosBase/sqlRoleAssignments/${assignId}?api-version=$cosmosApi" -Payload $raBody -ErrorAction Stop | Out-Null
                Write-Host "[OK]    Cosmos DB data-plane role granted to $userId."
            } catch {
                Write-Host "[WARN]  Could not grant Cosmos DB role to ${userId}: $_"
            }
        }

        # Key Vault RBAC
        if ($keyVault) {
            foreach ($roleName in $keyVaultRoles.Keys) {
                $roleId = $keyVaultRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $keyVault.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on Key Vault."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $keyVault.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on Key Vault."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        }

        # Monitoring RBAC (Log Analytics + App Insights)
        if ($logAnalyticsRes) {
            foreach ($roleName in $monitoringRoles.Keys) {
                $roleId = $monitoringRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $logAnalyticsRes.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on Log Analytics."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $logAnalyticsRes.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on Log Analytics."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        }

        if ($appInsightsRes) {
            foreach ($roleName in $monitoringRoles.Keys) {
                $roleId = $monitoringRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $appInsightsRes.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on Application Insights."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $appInsightsRes.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on Application Insights."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        }

        # APIM management RBAC (APIMClientTool: list APIs/subscriptions, create/update
        # products/subscriptions dynamically — notebooks 3-7, 9)
        if ($apim) {
            foreach ($roleName in $apimRoles.Keys) {
                $roleId = $apimRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $apim.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on APIM."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $apim.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on APIM."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        } else {
            Write-Host "[WARN]  No APIM resource found in RG '$effectiveRG' — skipping APIM management RBAC."
        }

        # ACR RBAC (optional — required only for Notebook 7's container publishing)
        if ($acr) {
            foreach ($roleName in $acrRoles.Keys) {
                $roleId = $acrRoles[$roleName]
                $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $acr.ResourceId -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
                if ($existing) {
                    Write-Host "[OK]    '$roleName' already granted to $userId on ACR."
                    continue
                }
                try {
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $acr.ResourceId -ErrorAction Stop | Out-Null
                    Write-Host "[OK]    Granted '$roleName' to $userId on ACR."
                } catch {
                    Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
                }
            }
        } else {
            Write-Host "[WARN]  No ACR found in RG '$effectiveRG' — Notebook 7 (container publishing) will be blocked."
        }
    }
}

# --- Return credentials to the attendee dashboard ---
Write-Host "[OK]    Lab provisioning complete."

function Get-OutVal {
    param($Outputs, [string]$Key)
    if ($Outputs -and $Outputs.ContainsKey($Key)) { return "$($Outputs[$Key].Value)" }
    return ''
}

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
    @{ HackboxCredential = @{ name = 'LlmBackendConfig'; value = $llmBackendConfig; note = 'Base64-encoded LLM backend routing config. Maps to notebook azd env key LLM_BACKEND_CONFIG' } }
}

if ($spokeFoundryAccountNameOut) {
    @{ HackboxCredential = @{ name = 'SpokeFoundryAccountName'; value = $spokeFoundryAccountNameOut; note = 'Spoke Foundry account name (Notebooks 7-9)' } }
    @{ HackboxCredential = @{ name = 'SpokeAiFoundryAccountName'; value = $spokeFoundryAccountNameOut; note = 'Alias of SpokeFoundryAccountName. Maps to notebook azd env key SPOKE_AI_FOUNDRY_ACCOUNT_NAME' } }
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
