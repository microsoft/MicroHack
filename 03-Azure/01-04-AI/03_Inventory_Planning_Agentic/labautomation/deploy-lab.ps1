<#
.SYNOPSIS
    Deploys the Azure AI Foundry project and model deployment for the
    Agentic Inventory Planning (hosted agents) MicroHack.

.DESCRIPTION
    Called by the EMEA MicroHack platform once per attendee, in parallel.
    Provisions standard Foundry resources plus a per-attendee governed data store,
    so it works out of the box with no facilitator pre-setup:

      - Azure AI Services account (AIServices kind — the Foundry account)
      - Azure AI Foundry project inside the account
      - gpt-5.4-mini model deployment (GlobalStandard)
      - Log Analytics workspace + Application Insights, connected to the Foundry
        account so the native agents' runs are traced server-side (Agents → Traces)
      - Azure Cosmos DB for NoSQL (serverless, keyless / local-auth disabled) with
        the 'inventory' database and containers pre-created — the governed data store
      - Data-plane RBAC for each attendee: on the Foundry account (Azure AI User +
        Cognitive Services User) to deploy hosted agents, and on the Cosmos account
        (Cosmos DB Built-in Data Contributor) to read/write the governed data

    The Zava data is seeded into Cosmos by the app on first run (idempotent, keyless
    via the attendee's identity). No keys or connection strings are ever used.

    Returns to the attendee dashboard:
      - Foundry project endpoint  (PROJECT_ENDPOINT in .env)
      - Model deployment name     (MODEL_DEPLOYMENT_NAME in .env)
      - Cosmos DB endpoint        (COSMOS_ENDPOINT in .env)
      - Resource group name

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

# ---------------------------------------------------------------------------
# ARM REST helper. Uses the full management.azure.com -Uri form (the -Path form
# silently drops the api-version on some PUT/PATCH calls, yielding a misleading
# MissingApiVersionParameter error) and — crucially — CHECKS the HTTP status so a
# failed control-plane call throws instead of printing a false "[OK] ... created".
# Pass -AllowNotFound for existence probes that may legitimately return 404.
# ---------------------------------------------------------------------------
function Invoke-MhhArm {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('GET','PUT','PATCH','POST','DELETE')][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,   # relative ARM path incl. ?api-version=
        [string]$Payload,
        [switch]$AllowNotFound
    )
    $uri = if ($Path -like 'https://*') { $Path } else { "https://management.azure.com$Path" }
    $params = @{ Method = $Method; Uri = $uri }
    if ($Payload) { $params.Payload = $Payload }
    $resp = Invoke-AzRestMethod @params
    if (($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) -or
        ($AllowNotFound -and $resp.StatusCode -eq 404)) {
        return $resp
    }
    throw "ARM $Method $uri failed with HTTP $($resp.StatusCode): $($resp.Content)"
}

# Resolve effective values — honour $PreferredLocation, fall back across the list
$candidateRegions  = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @("swedencentral", "westeurope", "norwayeast") }
$effectiveLocation = $candidateRegions[0]
$effectiveRG       = $ResourceGroupName
$stableHash        = (Get-MhhStableHash $AllowedEntraUserIds -Length 12).ToLower()

# Foundry account name = custom subdomain (must be globally unique + DNS-safe)
$foundryAccountName = "inv-$stableHash"
$foundryProjectName = "inventory-hack"
$modelDeployment    = "gpt-5.4-mini"

Write-Host "[INFO]  Deploying Foundry account '$foundryAccountName' in '$effectiveRG'..."

# ---------------------------------------------------------------------------
# Azure AI Services account (the Foundry account). Kind must be 'AIServices'.
# A system-assigned identity is required before a project can be created.
# ---------------------------------------------------------------------------
$existingAccount = Get-AzResource `
    -ResourceGroupName $effectiveRG `
    -ResourceType "Microsoft.CognitiveServices/accounts" `
    -Name $foundryAccountName `
    -ErrorAction SilentlyContinue

if ($existingAccount) {
    $effectiveLocation = $existingAccount.Location
    Write-Host "[OK]    Foundry account already exists in '$effectiveLocation' — skipping."
} else {
    $accountCreated = $false
    foreach ($region in $candidateRegions) {
        Write-Host "[INFO]  Attempting Foundry account in '$region'..."
        $accountBody = @{
            kind     = "AIServices"
            sku      = @{ name = "S0" }
            location = $region
            identity = @{ type = "SystemAssigned" }
            properties = @{
                customSubDomainName    = $foundryAccountName
                publicNetworkAccess    = "Enabled"
                allowProjectManagement = $true
            }
        } | ConvertTo-Json -Depth 5

        $accountUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
            "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
            "?api-version=2025-04-01-preview"

        try {
            Invoke-MhhArm -Method PUT -Path $accountUri -Payload $accountBody | Out-Null
        } catch {
            Write-Warning "Region '$region' rejected the account create: $_ — trying next region."
            continue
        }

        $timeout = 120; $elapsed = 0; $acct = $null
        do {
            Start-Sleep -Seconds 10; $elapsed += 10
            $acct = Get-AzResource -ResourceGroupName $effectiveRG -ResourceType "Microsoft.CognitiveServices/accounts" -Name $foundryAccountName -ErrorAction SilentlyContinue
        } while (($acct.Properties.provisioningState -ne "Succeeded") -and ($elapsed -lt $timeout))

        if ($acct.Properties.provisioningState -eq "Succeeded") {
            $effectiveLocation = $region
            $accountCreated = $true
            Write-Host "[OK]    Foundry account created in '$region'."
            break
        }
        Write-Warning "Provisioning did not succeed in '$region' within ${timeout}s — trying next region."
    }
    if (-not $accountCreated) {
        throw "Could not create the Foundry account in any preferred region: $($candidateRegions -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# Ensure project management is enabled on the account. This is REQUIRED before a
# project can be created, and is not reliably honoured from the account-create
# body — so we set it explicitly and confirm it reads back before continuing.
# ---------------------------------------------------------------------------
$accountArm = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "?api-version=2025-04-01-preview"
$acctProps = (Invoke-MhhArm -Method GET -Path $accountArm).Content | ConvertFrom-Json
if (-not $acctProps.properties.allowProjectManagement) {
    Invoke-MhhArm -Method PATCH -Path $accountArm `
        -Payload (@{ properties = @{ allowProjectManagement = $true } } | ConvertTo-Json) | Out-Null
    $elapsed = 0
    do {
        Start-Sleep -Seconds 8; $elapsed += 8
        $acctProps = (Invoke-MhhArm -Method GET -Path $accountArm).Content | ConvertFrom-Json
    } while ((-not $acctProps.properties.allowProjectManagement) -and ($elapsed -lt 90))
    if (-not $acctProps.properties.allowProjectManagement) {
        throw "Could not enable allowProjectManagement on '$foundryAccountName'."
    }
    Write-Host "[OK]    Project management enabled on '$foundryAccountName'."
}

# ---------------------------------------------------------------------------
# Foundry project
# ---------------------------------------------------------------------------
$projectUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "/projects/${foundryProjectName}?api-version=2025-04-01-preview"

$existingProject = Invoke-MhhArm -Method GET -Path $projectUri -AllowNotFound
if ($existingProject.StatusCode -ne 200) {
    # The project body MUST include an identity block, or the API rejects it with
    # "you must enable a managed identity on your resource".
    $projectBody = @{
        location   = $effectiveLocation
        identity   = @{ type = "SystemAssigned" }
        properties = @{ description = "Agentic Inventory Planning MicroHack" }
    } | ConvertTo-Json -Depth 3

    Invoke-MhhArm -Method PUT -Path $projectUri -Payload $projectBody | Out-Null

    $elapsed = 0
    do { Start-Sleep -Seconds 8; $elapsed += 8
         $r = Invoke-MhhArm -Method GET -Path $projectUri -AllowNotFound
    } while (($r.StatusCode -ne 200) -and ($elapsed -lt 90))
    if ($r.StatusCode -ne 200) { throw "Foundry project '$foundryProjectName' did not become ready." }

    Write-Host "[OK]    Foundry project '$foundryProjectName' created."
} else {
    Write-Host "[OK]    Foundry project already exists — skipping."
}

# ---------------------------------------------------------------------------
# gpt-5.4-mini model deployment (ACCOUNT-scoped, GlobalStandard capacity 100).
# Chosen deliberately: a low-cost GPT-5 model whose Foundry model card confirms
# Functions/Tools + Structured Outputs (both required by these agents), available
# on GlobalStandard in EU regions, with the longest support horizon among the
# low-cost GPT-5 models (retires 2027-03-18). Do NOT fall back to gpt-4o-mini or
# gpt-4.1-mini here — both are already deprecated (retire Oct 2026).
#
# Capacity 100 = 100K TPM per attendee — ample for one person running the loop,
# and it lets ~8 labs share the default 1,000-unit regional GlobalStandard quota
# (8 x 100 = 800, leaving headroom). Keep this in sync with labsPerSubscription in
# lab-defaults.json: labsPerSubscription x capacity must stay <= the region quota.
# ---------------------------------------------------------------------------
$deploymentUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "/deployments/$modelDeployment" +
    "?api-version=2025-04-01-preview"

$existingDeploy = Invoke-MhhArm -Method GET -Path $deploymentUri -AllowNotFound
if ($existingDeploy.StatusCode -ne 200) {
    $deploymentBody = @{
        sku        = @{ name = "GlobalStandard"; capacity = 100 }
        properties = @{
            model = @{ format = "OpenAI"; name = "gpt-5.4-mini"; version = "2026-03-17" }
        }
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-MhhArm -Method PUT -Path $deploymentUri -Payload $deploymentBody | Out-Null
        Write-Host "[OK]    Model deployment '$modelDeployment' initiated."
    } catch {
        Write-Host "[WARN]  Model deployment: $_ — may already exist, continuing."
    }
} else {
    Write-Host "[OK]    Model deployment already exists — skipping."
}

# ---------------------------------------------------------------------------
# Observability: Log Analytics workspace + Application Insights, connected to the
# Foundry account. This turns on **server-side agent tracing** — the native agents'
# runs appear in the portal's Agents -> Traces tab (model call, tool calls, tool
# responses, final generation). No app code changes are needed; Foundry auto-exports
# traces once the AppInsights connection exists. The app's agents are created with the
# new azure-ai-projects 2.x agents API, so they are traceable (classic assistants are
# not) and show natively in the portal.
# ---------------------------------------------------------------------------
$laName = "inv-log-$stableHash"
$aiName = "inv-appi-$stableHash"
$laId   = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.OperationalInsights/workspaces/$laName"
$aiId   = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.Insights/components/$aiName"

if ((Invoke-MhhArm -Method GET -Path "${laId}?api-version=2022-10-01" -AllowNotFound).StatusCode -ne 200) {
    $laBody = @{ location = $effectiveLocation; properties = @{ sku = @{ name = "PerGB2018" }; retentionInDays = 30 } } | ConvertTo-Json -Depth 5
    Invoke-MhhArm -Method PUT -Path "${laId}?api-version=2022-10-01" -Payload $laBody | Out-Null
    $elapsed = 0
    do { Start-Sleep -Seconds 8; $elapsed += 8
         $la = ($laResp = Invoke-MhhArm -Method GET -Path "${laId}?api-version=2022-10-01" -AllowNotFound).Content | ConvertFrom-Json
    } while ($la.properties.provisioningState -ne "Succeeded" -and $elapsed -lt 120)
    Write-Host "[OK]    Log Analytics workspace '$laName' created."
} else {
    Write-Host "[OK]    Log Analytics workspace already exists — skipping."
}

if ((Invoke-MhhArm -Method GET -Path "${aiId}?api-version=2020-02-02" -AllowNotFound).StatusCode -ne 200) {
    $aiBody = @{ location = $effectiveLocation; kind = "web"; properties = @{ Application_Type = "web"; WorkspaceResourceId = $laId } } | ConvertTo-Json -Depth 5
    Invoke-MhhArm -Method PUT -Path "${aiId}?api-version=2020-02-02" -Payload $aiBody | Out-Null
    Write-Host "[OK]    Application Insights '$aiName' created."
} else {
    Write-Host "[OK]    Application Insights already exists — skipping."
}

# Connect App Insights to the Foundry account (this is what enables the Traces tab).
$aiConnString = ((Invoke-MhhArm -Method GET -Path "${aiId}?api-version=2020-02-02").Content | ConvertFrom-Json).properties.ConnectionString
$connUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "/connections/$foundryAccountName-appinsights?api-version=2025-04-01-preview"
$connBody = @{ properties = @{
    category      = "AppInsights"
    target        = $aiId
    authType      = "ApiKey"
    isSharedToAll = $true
    credentials   = @{ key = $aiConnString }
    metadata      = @{ ApiType = "Azure"; ResourceId = $aiId }
} } | ConvertTo-Json -Depth 6
Invoke-MhhArm -Method PUT -Path $connUri -Payload $connBody | Out-Null
Write-Host "[OK]    Application Insights connected to '$foundryAccountName' — server-side tracing enabled."

# ---------------------------------------------------------------------------
# Governed data store: per-attendee Azure Cosmos DB for NoSQL (serverless).
# Keyless — local auth is disabled; the agents connect with the attendee's identity
# via data-plane RBAC. The database and containers are created here (control-plane);
# the app seeds the documents on first run (data-plane). Uses ARM REST so there is
# no dependency on the Az.CosmosDB module.
# ---------------------------------------------------------------------------
$cosmosName = "inv-cos-$stableHash"      # 3-44 chars, lowercase alphanumeric + hyphens
$cosmosDb   = "inventory"
$cosmosApi  = "2024-11-15"
$cosmosBase = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.DocumentDB/databaseAccounts/$cosmosName"

# ---------------------------------------------------------------------------
# MCAPS policy accommodation. The demo/attendee subscriptions this hack runs on
# are Microsoft-internal (MCAPS) subscriptions, which inherit a management-group
# 'Modify' policy that forces every new Cosmos DB account to
# publicNetworkAccess = Disabled. The app runs on the attendee's own machine and
# reaches Cosmos over its public endpoint, so a disabled endpoint breaks the lab.
# The standard MCAPS exemption is the resource-group tag SecurityControl=Ignore,
# so we merge it onto the RG (preserving any existing tags) before creating the
# account. Security is unchanged: the account is keyless (disableLocalAuth=true),
# so the reachable endpoint still requires an Entra token carrying the data role.
# On non-MCAPS subscriptions this tag is simply a harmless no-op.
# ---------------------------------------------------------------------------
$rgTagUri  = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.Resources/tags/default?api-version=2021-04-01"
$rgTagBody = @{ operation = "Merge"; properties = @{ tags = @{ SecurityControl = "Ignore" } } } | ConvertTo-Json -Depth 4
Invoke-MhhArm -Method PATCH -Path $rgTagUri -Payload $rgTagBody | Out-Null
Write-Host "[OK]    Resource group tagged 'SecurityControl=Ignore' (MCAPS Cosmos public-access exemption)."

$cosmosBody = @{
    kind     = "GlobalDocumentDB"
    location = $effectiveLocation
    tags     = @{ SecurityControl = "Ignore" }
    properties = @{
        databaseAccountOfferType = "Standard"
        disableLocalAuth         = $true
        publicNetworkAccess      = "Enabled"
        capabilities             = @(@{ name = "EnableServerless" })
        locations                = @(@{ locationName = $effectiveLocation; failoverPriority = 0 })
    }
} | ConvertTo-Json -Depth 6

$existingCosmos = Invoke-MhhArm -Method GET -Path "${cosmosBase}?api-version=$cosmosApi" -AllowNotFound
if ($existingCosmos.StatusCode -ne 200) {
    Invoke-MhhArm -Method PUT -Path "${cosmosBase}?api-version=$cosmosApi" -Payload $cosmosBody | Out-Null
    Write-Host "[INFO]  Cosmos account '$cosmosName' creating (serverless, keyless)..."

    $timeout = 600; $elapsed = 0; $state = "Creating"
    do {
        Start-Sleep -Seconds 15; $elapsed += 15
        $c = Invoke-MhhArm -Method GET -Path "${cosmosBase}?api-version=$cosmosApi" -AllowNotFound
        if ($c.StatusCode -eq 200) { $state = ($c.Content | ConvertFrom-Json).properties.provisioningState }
    } while (($state -ne "Succeeded") -and ($elapsed -lt $timeout))
    if ($state -ne "Succeeded") { throw "Cosmos account '$cosmosName' did not provision within ${timeout}s." }
    Write-Host "[OK]    Cosmos account '$cosmosName' ready."
} else {
    Write-Host "[OK]    Cosmos account already exists — skipping."
    # Reconcile (best-effort): if a prior run (or the MCAPS policy) left the
    # endpoint disabled, re-enable it now that the exemption tag is in place.
    # Wait for any in-flight operation to settle, then PUT (a bare PATCH can hit
    # an ETag 412); retry transient "operation in progress" 412s. Never abort the
    # run on this — a fresh account is already created reachable above.
    $curProps = ($existingCosmos.Content | ConvertFrom-Json).properties
    if ($curProps.publicNetworkAccess -ne "Enabled") {
        $waited = 0
        while ($curProps.provisioningState -ne "Succeeded" -and $waited -lt 180) {
            Start-Sleep -Seconds 10; $waited += 10
            $curProps = (Invoke-MhhArm -Method GET -Path "${cosmosBase}?api-version=$cosmosApi").Content |
                ConvertFrom-Json | Select-Object -ExpandProperty properties
        }
        $reconciled = $false
        for ($try = 1; $try -le 6 -and -not $reconciled; $try++) {
            $rec = Invoke-AzRestMethod -Method PUT `
                -Uri "https://management.azure.com${cosmosBase}?api-version=$cosmosApi" -Payload $cosmosBody
            if ($rec.StatusCode -ge 200 -and $rec.StatusCode -lt 300) {
                $reconciled = $true
                Write-Host "[OK]    Re-enabled public network access on existing Cosmos account."
            } elseif ($rec.StatusCode -eq 412) {
                Start-Sleep -Seconds 15   # exclusive lock held by another operation — retry
            } else {
                Write-Host "[WARN]  Could not re-enable Cosmos public access (HTTP $($rec.StatusCode)); continuing."
                break
            }
        }
        if (-not $reconciled) { Write-Host "[WARN]  Cosmos public access still not reconciled after retries; continuing." }
    }
}

# Database
$dbUri = "$cosmosBase/sqlDatabases/${cosmosDb}?api-version=$cosmosApi"
if ((Invoke-MhhArm -Method GET -Path $dbUri -AllowNotFound).StatusCode -ne 200) {
    $dbBody = @{ properties = @{ resource = @{ id = $cosmosDb } } } | ConvertTo-Json -Depth 5
    Invoke-MhhArm -Method PUT -Path $dbUri -Payload $dbBody | Out-Null
    Write-Host "[OK]    Cosmos database '$cosmosDb' created."
}

# Containers (name -> partition key path)
$containers = [ordered]@{
    products = "/productId"; stores = "/storeId"; suppliers = "/supplierId";
    signals  = "/signalId";  inventory = "/productId"; demand = "/productId"; orders = "/orderId"
}
foreach ($cName in $containers.Keys) {
    $cUri = "$cosmosBase/sqlDatabases/$cosmosDb/containers/${cName}?api-version=$cosmosApi"
    if ((Invoke-MhhArm -Method GET -Path $cUri -AllowNotFound).StatusCode -ne 200) {
        $cBody = @{ properties = @{ resource = @{
            id           = $cName
            partitionKey = @{ paths = @($containers[$cName]); kind = "Hash" }
        } } } | ConvertTo-Json -Depth 6
        Invoke-MhhArm -Method PUT -Path $cUri -Payload $cBody | Out-Null
        Write-Host "[OK]    Cosmos container '$cName' created."
    }
}

# Data-plane RBAC: Cosmos DB Built-in Data Contributor (…0002) per attendee.
$cosmosDataRole = "$cosmosBase/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
$existingRAs = Invoke-MhhArm -Method GET -Path "$cosmosBase/sqlRoleAssignments?api-version=$cosmosApi" -AllowNotFound
$raList = if ($existingRAs.StatusCode -eq 200) { ($existingRAs.Content | ConvertFrom-Json).value } else { @() }
foreach ($userId in $AllowedEntraUserIds) {
    $already = $raList | Where-Object { $_.properties.principalId -eq $userId -and $_.properties.roleDefinitionId -like "*000000000002" }
    if ($already) { Write-Host "[OK]    Cosmos data role already granted to $userId."; continue }
    $assignId = [guid]::NewGuid().ToString()
    $raBody = @{ properties = @{
        roleDefinitionId = $cosmosDataRole
        principalId      = $userId
        scope            = $cosmosBase
    } } | ConvertTo-Json -Depth 5
    Invoke-MhhArm -Method PUT -Path "$cosmosBase/sqlRoleAssignments/${assignId}?api-version=$cosmosApi" -Payload $raBody | Out-Null
    Write-Host "[OK]    Cosmos data-plane role granted to $userId."
}

# ---------------------------------------------------------------------------
# Grant attendees data-plane access so they can create + deploy hosted agents
# from their Codespace. Standard RBAC on the Foundry account — no deviation.
#   Azure AI User          (53ca6127-db72-4b80-b1b0-d745d6d5456d) — agent CRUD / project data plane
#   Cognitive Services User (a97b65f3-24c7-4388-baec-2e87135dc908) — inference calls
# ---------------------------------------------------------------------------
$accountScope = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName"

$roleIds = @{
    "Azure AI User"           = "53ca6127-db72-4b80-b1b0-d745d6d5456d"
    "Cognitive Services User" = "a97b65f3-24c7-4388-baec-2e87135dc908"
}

foreach ($userId in $AllowedEntraUserIds) {
    foreach ($roleName in $roleIds.Keys) {
        $roleId = $roleIds[$roleName]
        $existing = Get-AzRoleAssignment -ObjectId $userId -Scope $accountScope -RoleDefinitionId $roleId -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "[OK]    '$roleName' already assigned to $userId."
            continue
        }
        try {
            New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roleId -Scope $accountScope -ErrorAction Stop | Out-Null
            Write-Host "[OK]    Granted '$roleName' to $userId."
        } catch {
            Write-Host "[WARN]  Could not grant '$roleName' to ${userId}: $_"
        }
    }
}

# ---------------------------------------------------------------------------
# Return credentials to the attendee dashboard
# ---------------------------------------------------------------------------
$projectEndpoint = "https://$foundryAccountName.services.ai.azure.com/api/projects/$foundryProjectName"

Write-Host "[OK]    Lab provisioning complete."

@{ HackboxCredential = @{
    name  = "FoundryProjectEndpoint"
    value = $projectEndpoint
    note  = "Paste into src/.env as PROJECT_ENDPOINT (Challenge 0)"
} }

@{ HackboxCredential = @{
    name  = "ModelDeploymentName"
    value = $modelDeployment
    note  = "Paste into src/.env as MODEL_DEPLOYMENT_NAME"
} }

@{ HackboxCredential = @{
    name  = "CosmosEndpoint"
    value = "https://$cosmosName.documents.azure.com:443/"
    note  = "Paste into src/.env as COSMOS_ENDPOINT (the governed data store)"
} }

@{ HackboxCredential = @{
    name  = "ResourceGroupName"
    value = $effectiveRG
    note  = "The resource group containing your Foundry account"
} }
