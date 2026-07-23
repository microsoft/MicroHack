<#
.SYNOPSIS
    Deploys the Azure AI Foundry project and model deployment for the
    Agentic Inventory Planning MicroHack.

.DESCRIPTION
    Called by the EMEA MicroHack platform once per attendee, in parallel.
    Provisions:
      - Azure AI Services account (AIServices kind — this is the Foundry account)
      - Azure AI Foundry project inside the account
      - gpt-5.4-mini model deployment (capacity 100 GlobalStandard = 100K TPM)
      - A per-attendee Fabric F2 capacity, with the attendee set as capacity admin
    
    Each attendee gets their OWN Fabric capacity (no shared backend, no shared
    Spark contention). The attendee then creates a workspace, assigns it to their
    capacity, and Run All's the setup notebook themselves (Challenge 1) to load the
    data and publish their own Fabric Data Agent.

    Returns to the attendee dashboard:
      - Foundry project endpoint (format: https://{name}.services.ai.azure.com/api/projects/{proj})
      - Model deployment name
      - The name of their Fabric F2 capacity (used when they create their workspace)

    The platform pre-sets the Az context to $SubscriptionId. For 'resourcegroup'
    deployments it also pre-creates the resource group; for 'subscription'
    deployments this script creates the resource group itself. Do NOT call
    Connect-AzAccount.

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

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ErrorActionPreference = "Stop"

# Resolve effective values — honour $PreferredLocation, fall back across the list
$candidateRegions   = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @("swedencentral", "westeurope", "norwayeast") }
$effectiveLocation  = $candidateRegions[0]
$effectiveRG        = $ResourceGroupName
$stableHash         = (Get-MhhStableHash $AllowedEntraUserIds -Length 12).ToLower()

# For 'subscription' deployments the platform does NOT pre-create a resource group
# ($ResourceGroupName arrives empty). Create one ourselves with a deterministic,
# per-attendee name so the rest of this (RG-scoped) script works unchanged.
if ([string]::IsNullOrWhiteSpace($effectiveRG)) {
    $effectiveRG = "rg-inv-hack-$stableHash"
    if (-not (Get-AzResourceGroup -Name $effectiveRG -ErrorAction SilentlyContinue)) {
        New-AzResourceGroup -Name $effectiveRG -Location $effectiveLocation | Out-Null
        Write-Host "[OK]    Created resource group '$effectiveRG' (subscription deployment)."
    }
}

# Foundry account name = custom subdomain name (must be globally unique)
# Pattern: inv-{12-char hash} keeps it short and DNS-safe (Get-MhhStableHash minimum length is 12)
$foundryAccountName = "inv-$stableHash"
$foundryProjectName = "inventory-hack"
$modelDeployment    = "gpt-5.4-mini"

# Per-attendee Fabric F2 capacity name (lowercase alphanumeric, 3-63 chars).
$fabricCapacityName = "invcap$stableHash"

Write-Host "[INFO]  Deploying Foundry account '$foundryAccountName' in '$effectiveRG'..."

# ---------------------------------------------------------------------------
# Azure AI Services account (this is the Foundry Hub)
# Kind must be 'AIServices' — 'AIFoundry' is not a valid kind.
# customSubDomainName = account name → enables {name}.services.ai.azure.com endpoint
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
        # A system-assigned identity is REQUIRED before a project can be created
        # ("To create projects, you must enable a managed identity on your resource").
        $accountBody = @{
            kind     = "AIServices"
            sku      = @{ name = "S0" }
            location = $region
            identity = @{ type = "SystemAssigned" }
            properties = @{
                customSubDomainName = $foundryAccountName
                publicNetworkAccess = "Enabled"
                allowProjectManagement = $true
            }
        } | ConvertTo-Json -Depth 5

        $accountUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
            "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
            "?api-version=2025-04-01-preview"

        # Invoke-AzRestMethod does NOT throw on non-2xx — inspect the status code.
        $resp = Invoke-AzRestMethod -Method PUT -Path $accountUri -Payload $accountBody

        # A soft-deleted account (48h retention) reserves the subdomain globally and
        # blocks re-creation with HTTP 409 CustomDomainInUse. This is common when a lab
        # is torn down and re-provisioned for the same attendee. Purge it and retry.
        if ($resp.StatusCode -eq 409 -and $resp.Content -match 'CustomDomainInUse') {
            Write-Warning "Subdomain '$foundryAccountName' is held by a soft-deleted account — purging and retrying."
            $listResp = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/deletedAccounts?api-version=2025-04-01-preview"
            if ($listResp.StatusCode -eq 200) {
                foreach ($d in (($listResp.Content | ConvertFrom-Json).value | Where-Object { $_.name -eq $foundryAccountName })) {
                    $delRg = if ($d.id -match '/resourceGroups/([^/]+)/deletedAccounts/') { $Matches[1] } else { $effectiveRG }
                    Invoke-AzRestMethod -Method DELETE -Path "/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$($d.location)/resourceGroups/$delRg/deletedAccounts/${foundryAccountName}?api-version=2025-04-01-preview" | Out-Null
                }
                Start-Sleep -Seconds 5
            }
            $resp = Invoke-AzRestMethod -Method PUT -Path $accountUri -Payload $accountBody
        }

        if ($resp.StatusCode -ge 400) {
            Write-Warning "Region '$region' rejected the account create (HTTP $($resp.StatusCode)): $($resp.Content) — trying next region."
            continue
        }

        # Wait for provisioning (AIServices accounts can take several minutes).
        $timeout = 300; $elapsed = 0; $acct = $null
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
# Foundry project
# ---------------------------------------------------------------------------
$projectUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "/projects/${foundryProjectName}?api-version=2025-04-01-preview"

$existingProject = Invoke-AzRestMethod -Method GET -Path $projectUri -ErrorAction SilentlyContinue
if ($existingProject.StatusCode -ne 200) {
    $projectBody = @{
        location   = $effectiveLocation
        properties = @{ description = "Agentic Inventory Planning MicroHack" }
    } | ConvertTo-Json -Depth 3

    Invoke-AzRestMethod -Method PUT -Path $projectUri -Payload $projectBody | Out-Null

    $elapsed = 0
    do { Start-Sleep -Seconds 8; $elapsed += 8
         $r = Invoke-AzRestMethod -Method GET -Path $projectUri -ErrorAction SilentlyContinue
    } while (($r.StatusCode -ne 200) -and ($elapsed -lt 90))

    Write-Host "[OK]    Foundry project '$foundryProjectName' created."
} else {
    Write-Host "[OK]    Foundry project already exists — skipping."
}

# ---------------------------------------------------------------------------
# gpt-5.4-mini model deployment (ACCOUNT-scoped, GlobalStandard capacity 100).
# Matches the pro-code inventory hack: a low-cost GPT-5 model whose Foundry model
# card confirms Functions/Tools + Structured Outputs, on GlobalStandard in EU
# regions, with the longest support horizon among the low-cost models
# (retires 2027-03-18; gpt-4o-mini / gpt-4.1-mini retire Oct 2026).
#
# gpt-5.4-mini is a GPT-5 *reasoning* model. In the Foundry tool picker the Fabric
# Data Agent tool may show "Not supported by the selected model" - that flag is
# cosmetic; the tool still runs via the Responses API. If an agent skips the
# Fabric tool, set tool choice = required in the run settings (the challenge
# instructions carry an "IMPORTANT - tool use" block for exactly this).
#
# Capacity 100 = 100K TPM per attendee. Keep labsPerSubscription x 100 <= the
# region's GlobalStandard quota (~1,000) - 4 labs/subscription fits comfortably.
# Model deployments are ACCOUNT-scoped (not project-scoped): the ARM path is
# .../accounts/{account}/deployments/{deployment} - there is no /projects/ segment.
# ---------------------------------------------------------------------------
$deploymentUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
    "/providers/Microsoft.CognitiveServices/accounts/$foundryAccountName" +
    "/deployments/$modelDeployment" +
    "?api-version=2025-04-01-preview"

$existingDeploy = Invoke-AzRestMethod -Method GET -Path $deploymentUri -ErrorAction SilentlyContinue
if ($existingDeploy.StatusCode -ne 200) {
    $deploymentBody = @{
        sku        = @{ name = "GlobalStandard"; capacity = 100 }
        properties = @{
            model = @{ format = "OpenAI"; name = "gpt-5.4-mini"; version = "2026-03-17" }
        }
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-AzRestMethod -Method PUT -Path $deploymentUri -Payload $deploymentBody | Out-Null
        Write-Host "[OK]    Model deployment '$modelDeployment' initiated."
    } catch {
        Write-Host "[WARN]  Model deployment: $_ — may already exist, continuing."
    }
} else {
    Write-Host "[OK]    Model deployment already exists — skipping."
}

# ---------------------------------------------------------------------------
# Per-attendee Fabric F2 capacity (ARM REST — no az CLI / Fabric extension needed).
# The attendee is set as capacity ADMIN so they can create a workspace, assign it
# to this capacity, and Run All the setup notebook themselves (Challenge 1).
# F2 = 2 CU; a 512-CU subscription supports ~256 attendees.
#
# Capacity admin members must be UPNs (or service principals) — bare object IDs are
# rejected — so resolve each attendee object ID to a UPN with the platform helper
# Get-MhhLabUser. It is served from a platform-seeded cache (no Microsoft Graph
# permission needed on the deploying service principal) and falls back to
# Get-AzADUser transparently when run locally.
# ---------------------------------------------------------------------------
$fabricCapacityRegion = $null
$adminUpns = @()
foreach ($uid in $AllowedEntraUserIds) {
    try {
        $u = Get-MhhLabUser -UserId $uid -ErrorAction Stop
        if ($u.UserPrincipalName) { $adminUpns += $u.UserPrincipalName }
    } catch {
        Write-Warning "Could not resolve attendee object ID '$uid' to a UPN via Get-MhhLabUser: $_"
    }
}

if ($adminUpns.Count -eq 0) {
    Write-Warning "No attendee UPNs resolved — skipping Fabric capacity creation. Create the F2 capacity manually and set the attendee as capacity admin, or re-run once the lab-user cache is available."
} else {
    # Ensure the Microsoft.Fabric resource provider is registered (idempotent).
    $prov = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$SubscriptionId/providers/Microsoft.Fabric?api-version=2021-04-01"
    if ($prov.StatusCode -eq 200 -and ($prov.Content | ConvertFrom-Json).registrationState -ne "Registered") {
        Invoke-AzRestMethod -Method POST -Path "/subscriptions/$SubscriptionId/providers/Microsoft.Fabric/register?api-version=2021-04-01" | Out-Null
    }

    $capExists = Get-AzResource -ResourceGroupName $effectiveRG -ResourceType "Microsoft.Fabric/capacities" -Name $fabricCapacityName -ErrorAction SilentlyContinue
    if ($capExists) {
        $fabricCapacityRegion = $capExists.Location
        Write-Host "[OK]    Fabric capacity '$fabricCapacityName' already exists in '$fabricCapacityRegion' — skipping."
    } else {
        foreach ($region in $candidateRegions) {
            Write-Host "[INFO]  Creating Fabric F2 capacity '$fabricCapacityName' in '$region'..."
            $capBody = @{
                location   = $region
                sku        = @{ name = "F2"; tier = "Fabric" }
                properties = @{ administration = @{ members = @($adminUpns) } }
            } | ConvertTo-Json -Depth 6
            $capUri = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG" +
                "/providers/Microsoft.Fabric/capacities/$fabricCapacityName" +
                "?api-version=2023-11-01"
            $capResp = Invoke-AzRestMethod -Method PUT -Path $capUri -Payload $capBody
            if ($capResp.StatusCode -ge 400) {
                Write-Warning "Fabric capacity create in '$region' failed (HTTP $($capResp.StatusCode)): $($capResp.Content) — trying next region."
                continue
            }
            $elapsed = 0; $cap = $null
            do {
                Start-Sleep -Seconds 10; $elapsed += 10
                $cap = Get-AzResource -ResourceGroupName $effectiveRG -ResourceType "Microsoft.Fabric/capacities" -Name $fabricCapacityName -ErrorAction SilentlyContinue
            } while (($cap.Properties.provisioningState -ne "Succeeded") -and ($elapsed -lt 180))
            if ($cap.Properties.provisioningState -eq "Succeeded") {
                $fabricCapacityRegion = $region
                Write-Host "[OK]    Fabric F2 capacity '$fabricCapacityName' created in '$region'."
                break
            }
            Write-Warning "Fabric capacity provisioning did not succeed in '$region' — trying next region."
        }
        if (-not $fabricCapacityRegion) {
            Write-Warning "Could not create the Fabric capacity in any preferred region (check Fabric F-SKU quota). The attendee can still do the Foundry steps; provision Fabric manually."
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
    note  = "Open ai.azure.com → select this project OR use as SDK endpoint"
} }

@{ HackboxCredential = @{
    name  = "ModelDeploymentName"
    value = $modelDeployment
    note  = "Select this model when creating agents in the Foundry portal"
} }

@{ HackboxCredential = @{
    name  = "FabricCapacityName"
    value = $fabricCapacityName
    note  = "Your own Fabric F2 capacity. In Challenge 1 you create a workspace and assign it to this capacity, then Run All the setup notebook to publish your Data Agent."
} }

@{ HackboxCredential = @{
    name  = "ResourceGroupName"
    value = $effectiveRG
    note  = "The resource group containing your Foundry account and Fabric capacity — find your resources here in the Azure portal"
} }
