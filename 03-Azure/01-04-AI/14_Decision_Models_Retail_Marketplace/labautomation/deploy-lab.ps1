<#
.SYNOPSIS
    Deploys the per-attendee lab for "Decision Models for a Retail Marketplace".

.DESCRIPTION
    Called by the EMEA MicroHack platform once per attendee, in parallel.

    Provisions, in one Foundry (AIServices) resource:
      - Microsoft-Decision-1.1  deployment "decision"        (the gate's decision model, and the
                                                              judge in Foundry evaluations)
      - gpt-6-luna              deployment "gpt-6-luna"      (Decisions API + generative baseline)
      - a Foundry project, so attendees can open the models in the Foundry portal
      - RBAC for each attendee: Cognitive Services User (inference) + Foundry User (evaluations)
    and, for the browser-only experience:
      - the Launch Day console (the Listing Gate) as an Azure web app (App Service B1, Linux), built from ../src,
        calling the models with its managed identity; attendees open it with an access code
    and, for the optional Build track:
      - a storage account with a 'cloudshell' file share, so Azure Cloud Shell keeps attendees'
        files when the session times out

    The resource is keyless (disableLocalAuth = true): attendees and the web app use Entra ID.

    The script fails loudly instead of publishing a half-working lab. It only returns dashboard
    credentials after every deployment reports Succeeded, a live call to each API (including
    an image, as the challenges send photos) has returned a valid typed answer, AND the web app
    has answered a health check that calls Microsoft-Decision-1.1 with its own identity.

    The platform pre-sets the Az context to $SubscriptionId and pre-creates the resource group.
    Do NOT call Connect-AzAccount or New-AzResourceGroup.

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
# Sizing. One capacity unit = 1 request/min + 1,000 tokens/min for every model here.
# Data Zone quota is shared by every lab in the subscription, so keep
# labsPerSubscription (lab-defaults.json) x capacity <= the subscription quota:
#   gpt-6-luna           DataZoneStandard quota 333  -> 8 labs x 40  = 320
#   Microsoft-Decision-1.1 DataZoneStandard quota 4500 -> 8 labs x 500 = 4000
# Azure's rate limiter counts request SIZE (a base64 photo counts in full), so the gate's
# image requests cost ~4-5K tokens of rate limit each; 500 units ~= 100 listings/min.
# (Microsoft-Decision-1, the preview model, retires on 4 Feb 2027 and is no longer needed:
# Microsoft-Decision-1.1 works as the evaluation judge with azure-ai-evaluation 1.18.11+.)
# ---------------------------------------------------------------------------
$models = @(
    @{ deployment = "decision";       name = "Microsoft-Decision-1.1"; format = "Microsoft"; version = "1";          capacity = 500; quota = "AIServices.DataZoneStandard.Microsoft-Decision-1.1" },
    @{ deployment = "gpt-6-luna";     name = "gpt-6-luna";             format = "OpenAI";    version = "2026-09-22"; capacity = 40;  quota = "OpenAI.DataZoneStandard.gpt-6-luna" }
)
$skuName     = "DataZoneStandard"
$projectName = "marketplace-gate"
$apiVersion  = "2025-04-01-preview"
$webApiVersion = "2024-04-01"
$scriptPath  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$appSource   = Join-Path (Split-Path -Parent $scriptPath) "src"

# ---------------------------------------------------------------------------
# ARM REST helper: full management.azure.com URI form, and THROWS on any non-2xx so a
# failed control-plane call never prints a false "[OK]". -AllowNotFound for existence probes.
# ---------------------------------------------------------------------------
function Invoke-MhhArm {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('GET','PUT','PATCH','POST','DELETE')][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,
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

function Get-PlainToken([string]$ResourceUrl) {
    $t = (Get-AzAccessToken -ResourceUrl $ResourceUrl).Token
    if ($t -is [System.Security.SecureString]) { $t = ConvertFrom-SecureString -SecureString $t -AsPlainText }
    return $t
}

function Get-TokenObjectId([string]$Token) {
    $payload = $Token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) { 2 { $payload += '==' } 3 { $payload += '=' } }
    return ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json).oid
}

$candidateRegions = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @("swedencentral", "westeurope", "germanywestcentral") }
$effectiveRG      = $ResourceGroupName
$stableHash       = (Get-MhhStableHash $AllowedEntraUserIds -Length 12).ToLower()
$accountName      = "dm-$stableHash"
$accountBase      = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG/providers/Microsoft.CognitiveServices/accounts/$accountName"

# ---------------------------------------------------------------------------
# 1. Pick a region that offers all three models on DataZoneStandard AND has quota left.
#    An existing account keeps its region.
# ---------------------------------------------------------------------------
$existing = Invoke-MhhArm -Method GET -Path "${accountBase}?api-version=$apiVersion" -AllowNotFound
if ($existing.StatusCode -eq 200) {
    $effectiveLocation = ($existing.Content | ConvertFrom-Json).location
    Write-Host "[OK]    Foundry resource '$accountName' already exists in '$effectiveLocation'."
} else {
    $effectiveLocation = $null
    foreach ($region in $candidateRegions) {
        $catalog = (Invoke-MhhArm -Method GET -Path "/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$region/models?api-version=$apiVersion").Content | ConvertFrom-Json
        $usages  = (Invoke-MhhArm -Method GET -Path "/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$region/usages?api-version=$apiVersion").Content | ConvertFrom-Json
        $problems = @()
        foreach ($m in $models) {
            $offered = $catalog.value | Where-Object {
                $_.kind -eq "AIServices" -and $_.model.name -eq $m.name -and $_.model.version -eq $m.version -and
                ($_.model.skus.name -contains $skuName)
            }
            if (-not $offered) { $problems += "$($m.name) $skuName not offered"; continue }
            $u = $usages.value | Where-Object { $_.name.value -eq $m.quota }
            if ($u -and (($u.limit - $u.currentValue) -lt $m.capacity)) {
                $problems += "$($m.name): only $($u.limit - $u.currentValue) of $($m.capacity) quota left"
            }
        }
        if ($problems.Count -eq 0) { $effectiveLocation = $region; break }
        Write-Warning "Region '$region' skipped: $($problems -join '; ')"
    }
    if (-not $effectiveLocation) {
        throw "No preferred region ($($candidateRegions -join ', ')) offers all models with enough DataZoneStandard quota. Lower labsPerSubscription or request quota."
    }
    Write-Host "[INFO]  Using region '$effectiveLocation'."
}

# ---------------------------------------------------------------------------
# 2. Foundry (AIServices) resource: keyless, public endpoint, project management enabled.
#    Resource-group tag SecurityControl=Ignore is the standard exemption on Microsoft-internal
#    (MCAPS) subscriptions whose policies would otherwise disable public network access.
#    Security is unchanged: local auth is disabled, so callers need an Entra token + a data role.
# ---------------------------------------------------------------------------
$rgTagBody = @{ operation = "Merge"; properties = @{ tags = @{ SecurityControl = "Ignore" } } } | ConvertTo-Json -Depth 4
Invoke-MhhArm -Method PATCH -Path "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG/providers/Microsoft.Resources/tags/default?api-version=2021-04-01" -Payload $rgTagBody | Out-Null

$accountBody = @{
    kind     = "AIServices"
    sku      = @{ name = "S0" }
    location = $effectiveLocation
    identity = @{ type = "SystemAssigned" }
    tags     = @{ SecurityControl = "Ignore" }
    properties = @{
        customSubDomainName    = $accountName
        publicNetworkAccess    = "Enabled"
        disableLocalAuth       = $true
        allowProjectManagement = $true
    }
} | ConvertTo-Json -Depth 5
Invoke-MhhArm -Method PUT -Path "${accountBase}?api-version=$apiVersion" -Payload $accountBody | Out-Null

$elapsed = 0
do {
    Start-Sleep -Seconds 10; $elapsed += 10
    $acct = ((Invoke-MhhArm -Method GET -Path "${accountBase}?api-version=$apiVersion").Content | ConvertFrom-Json).properties
} while ($acct.provisioningState -notin @("Succeeded", "Failed") -and $elapsed -lt 300)
if ($acct.provisioningState -ne "Succeeded") { throw "Foundry resource '$accountName' is '$($acct.provisioningState)' after ${elapsed}s." }
if ($acct.publicNetworkAccess -ne "Enabled") { throw "Foundry resource '$accountName' has publicNetworkAccess '$($acct.publicNetworkAccess)' (a policy may have changed it)." }
Write-Host "[OK]    Foundry resource '$accountName' ready (keyless, public endpoint)."

# ---------------------------------------------------------------------------
# 3. Foundry project (portal access to the deployments; optional logging of evaluations).
# ---------------------------------------------------------------------------
$projectUri = "$accountBase/projects/${projectName}?api-version=$apiVersion"
if ((Invoke-MhhArm -Method GET -Path $projectUri -AllowNotFound).StatusCode -ne 200) {
    $projectBody = @{ location = $effectiveLocation; identity = @{ type = "SystemAssigned" };
                      properties = @{ description = "Decision Models for a Retail Marketplace MicroHack" } } | ConvertTo-Json -Depth 3
    Invoke-MhhArm -Method PUT -Path $projectUri -Payload $projectBody | Out-Null
    $elapsed = 0
    do { Start-Sleep -Seconds 8; $elapsed += 8
         $r = Invoke-MhhArm -Method GET -Path $projectUri -AllowNotFound
    } while ($r.StatusCode -ne 200 -and $elapsed -lt 120)
    if ($r.StatusCode -ne 200) { throw "Foundry project '$projectName' did not become ready." }
}
Write-Host "[OK]    Foundry project '$projectName' ready."

# ---------------------------------------------------------------------------
# 4. Model deployments, one at a time (an account accepts one deployment operation at once).
#    Re-runs repair a failed or wrongly sized deployment.
# ---------------------------------------------------------------------------
foreach ($m in $models) {
    $depUri = "$accountBase/deployments/$($m.deployment)?api-version=$apiVersion"
    $cur = Invoke-MhhArm -Method GET -Path $depUri -AllowNotFound
    $curObj = if ($cur.StatusCode -eq 200) { $cur.Content | ConvertFrom-Json } else { $null }
    if ($curObj -and $curObj.properties.provisioningState -eq "Succeeded" -and $curObj.sku.capacity -eq $m.capacity) {
        Write-Host "[OK]    Deployment '$($m.deployment)' already ready."
        continue
    }
    $depBody = @{
        sku        = @{ name = $skuName; capacity = $m.capacity }
        properties = @{ model = @{ format = $m.format; name = $m.name; version = $m.version } }
    } | ConvertTo-Json -Depth 5
    $attempt = 0
    while ($true) {
        $attempt++
        $put = Invoke-AzRestMethod -Method PUT -Uri "https://management.azure.com$depUri" -Payload $depBody
        if ($put.StatusCode -ge 200 -and $put.StatusCode -lt 300) { break }
        # 409 = another operation on the account is still running; retry briefly.
        if ($put.StatusCode -eq 409 -and $attempt -lt 12) { Start-Sleep -Seconds 15; continue }
        throw "Deployment '$($m.deployment)' ($($m.name) $skuName x$($m.capacity)) was rejected, HTTP $($put.StatusCode): $($put.Content)"
    }
    $elapsed = 0
    do {
        Start-Sleep -Seconds 10; $elapsed += 10
        $state = ((Invoke-MhhArm -Method GET -Path $depUri).Content | ConvertFrom-Json).properties.provisioningState
    } while ($state -notin @("Succeeded", "Failed", "Canceled") -and $elapsed -lt 600)
    if ($state -ne "Succeeded") { throw "Deployment '$($m.deployment)' is '$state' after ${elapsed}s." }
    Write-Host "[OK]    Deployment '$($m.deployment)' ($($m.name), $skuName x$($m.capacity)) ready."
}

# ---------------------------------------------------------------------------
# 5. RBAC. Attendees: Cognitive Services User (call the models) + Foundry User, formerly
#    "Azure AI User" (evaluations with a decision-model judge need it on the resource).
#    The deployer also gets Cognitive Services User, only so step 6 can prove the lab works.
# ---------------------------------------------------------------------------
$roles = @{
    "Cognitive Services User" = "a97b65f3-24c7-4388-baec-2e87135dc908"
    "Foundry User"            = "53ca6127-db72-4b80-b1b0-d745d6d5456d"
}
foreach ($userId in $AllowedEntraUserIds) {
    foreach ($roleName in $roles.Keys) {
        if (Get-AzRoleAssignment -ObjectId $userId -Scope $accountBase -RoleDefinitionId $roles[$roleName] -ErrorAction SilentlyContinue) {
            continue
        }
        New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $roles[$roleName] -Scope $accountBase -ErrorAction Stop | Out-Null
        Write-Host "[OK]    Granted '$roleName' to $userId."
    }
}
$deployerId = Get-TokenObjectId (Get-PlainToken "https://management.azure.com/")
if (-not (Get-AzRoleAssignment -ObjectId $deployerId -Scope $accountBase -RoleDefinitionId $roles["Cognitive Services User"] -ErrorAction SilentlyContinue)) {
    New-AzRoleAssignment -ObjectId $deployerId -RoleDefinitionId $roles["Cognitive Services User"] -Scope $accountBase -ErrorAction Stop | Out-Null
}

# ---------------------------------------------------------------------------
# 6. Readiness: call every API the challenges use, with the deployer's identity, and retry
#    while the new role assignment propagates (it can take several minutes).
# ---------------------------------------------------------------------------
$decisionEndpoint = "https://$accountName.services.ai.azure.com"
$openaiEndpoint   = "https://$accountName.openai.azure.com"
# A 300 x 300 JPEG (red disc on grey): Decision-1.1 rejects images under 280 px per side.
$probeImage = "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"

$probes = @(
    @{ name = "Microsoft-Decision-1.1 (text)"; url = "$decisionEndpoint/providers/microsoft/v1/systemone"
       body = @{ model = "decision"; state = "Garden hose 25 m with brass fittings"
                 questions = @{ ok = @{ type = "noul"; instructions = "Is this a garden product?" } } }
       check = { param($r) $null -ne $r.answers.ok.noul } },
    @{ name = "Microsoft-Decision-1.1 (image)"; url = "$decisionEndpoint/providers/microsoft/v1/systemone"
       body = @{ model = "decision"; state = "Product photo: image:probe.jpg"
                 assets = @{ "probe.jpg" = @{ type = "image"; format = "jpeg"; data_base64 = $probeImage } }
                 questions = @{ ok = @{ type = "noul"; instructions = "Is the main shape in the photo red?" } } }
       check = { param($r) $null -ne $r.answers.ok.noul } },
    @{ name = "gpt-6-luna Decisions API"; url = "$openaiEndpoint/openai/v1/decisions"
       body = @{ model = "gpt-6-luna"; input = "Garden hose 25 m with brass fittings"
                 questions = @(@{ type = "predicate"; name = "ok"; instructions = "Is this a garden product?" }) }
       check = { param($r) $r.answers.Count -ge 1 } },
    @{ name = "gpt-6-luna Responses API"; url = "$openaiEndpoint/openai/v1/responses"
       body = @{ model = "gpt-6-luna"; input = "Reply with the single word: ready" }
       check = { param($r) $r.status -eq "completed" } }
)

foreach ($p in $probes) {
    $json = $p.body | ConvertTo-Json -Depth 10 -Compress
    $deadline = (Get-Date).AddMinutes(12)
    $lastError = ""
    while ($true) {
        $token = Get-PlainToken "https://cognitiveservices.azure.com"
        $resp = Invoke-WebRequest -Method POST -Uri $p.url -Body $json -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $token" } -SkipHttpErrorCheck -TimeoutSec 60
        if ($resp.StatusCode -eq 200) {
            $parsed = $resp.Content | ConvertFrom-Json
            if (& $p.check $parsed) { Write-Host "[OK]    Probe: $($p.name) answered."; break }
            $lastError = "HTTP 200 but no typed answer: $($resp.Content)"
        } else {
            $lastError = "HTTP $($resp.StatusCode): $($resp.Content)"
        }
        # 401/403 while the role assignment propagates, 429/5xx while the deployment warms up.
        if ($resp.StatusCode -notin @(200, 401, 403, 404, 408, 429, 500, 502, 503, 504)) { break }
        if ((Get-Date) -gt $deadline) { break }
        Start-Sleep -Seconds 20
    }
    if (-not ($resp.StatusCode -eq 200 -and (& $p.check ($resp.Content | ConvertFrom-Json)))) {
        throw "Readiness probe '$($p.name)' failed in '$effectiveLocation': $lastError"
    }
}

Write-Host "[OK]    Models ready."

# ---------------------------------------------------------------------------
# 7a. Storage for Azure Cloud Shell (Build track). Cloud Shell recycles its machine after
#     20 minutes without input; with this file share mounted, attendees keep $HOME (the clone,
#     .venv and .env) across breaks. Cloud Shell mounts the share with the account key, so
#     shared-key access must stay on; Storage Account Contributor lets attendees select it.
# ---------------------------------------------------------------------------
$storageName = "dmcs$stableHash"
$storageBase = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG/providers/Microsoft.Storage/storageAccounts/$storageName"
$storageApi  = "2023-05-01"
$storageBody = @{
    location = $effectiveLocation; kind = "StorageV2"; sku = @{ name = "Standard_LRS" }
    tags = @{ SecurityControl = "Ignore" }
    properties = @{
        minimumTlsVersion = "TLS1_2"; supportsHttpsTrafficOnly = $true; allowBlobPublicAccess = $false
        allowSharedKeyAccess = $true; publicNetworkAccess = "Enabled"
    }
} | ConvertTo-Json -Depth 4
Invoke-MhhArm -Method PUT -Path "${storageBase}?api-version=$storageApi" -Payload $storageBody | Out-Null
$elapsed = 0
do {
    Start-Sleep -Seconds 5; $elapsed += 5
    $sa = Invoke-MhhArm -Method GET -Path "${storageBase}?api-version=$storageApi" -AllowNotFound
    $saProps = if ($sa.StatusCode -eq 200) { ($sa.Content | ConvertFrom-Json).properties } else { $null }
} while ((-not $saProps -or $saProps.provisioningState -ne "Succeeded") -and $elapsed -lt 180)
if (-not $saProps -or $saProps.provisioningState -ne "Succeeded") { throw "Storage account '$storageName' did not become ready." }
$shareBody = @{ properties = @{ shareQuota = 6 } } | ConvertTo-Json -Depth 3
Invoke-MhhArm -Method PUT -Path "$storageBase/fileServices/default/shares/cloudshell?api-version=$storageApi" -Payload $shareBody | Out-Null
$storageRole = "17d1049b-9a84-46fb-8f53-869881c3d3ab"   # Storage Account Contributor
foreach ($userId in $AllowedEntraUserIds) {
    if (-not (Get-AzRoleAssignment -ObjectId $userId -Scope $storageBase -RoleDefinitionId $storageRole -ErrorAction SilentlyContinue)) {
        New-AzRoleAssignment -ObjectId $userId -RoleDefinitionId $storageRole -Scope $storageBase -ErrorAction Stop | Out-Null
    }
}
$cloudShellReady = $saProps.allowSharedKeyAccess -ne $false
if ($cloudShellReady) {
    Write-Host "[OK]    Cloud Shell storage '$storageName' (file share 'cloudshell') ready."
} else {
    # Optional Build track only: don't fail the lab, but don't advertise storage that can't mount.
    Write-Warning "A policy disabled shared-key access on '$storageName'; Cloud Shell can't mount it. Attendees fall back to an ephemeral session."
}

# ---------------------------------------------------------------------------
# 7. The Launch Day console as a web app (browser only for attendees).
#    App Service builds src/requirements.txt (Oryx) and runs uvicorn. The app signs in to the
#    Foundry resource with its own managed identity - no keys in app settings.
#    Code is published with an Entra token (no basic-auth publishing credentials).
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $appSource "ui/app.py"))) {
    throw "Console source not found at '$appSource'. The script must run from the hack folder (labautomation/ next to src/)."
}
$webName  = "dmgate-$stableHash"
$planBase = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG/providers/Microsoft.Web/serverfarms/$webName-plan"
$siteBase = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveRG/providers/Microsoft.Web/sites/$webName"
$planBody = @{ location = $effectiveLocation; kind = "linux"; sku = @{ name = "B1"; tier = "Basic" };
               properties = @{ reserved = $true } } | ConvertTo-Json -Depth 4
Invoke-MhhArm -Method PUT -Path "${planBase}?api-version=$webApiVersion" -Payload $planBody | Out-Null

# Keep the access code stable across re-runs.
$accessCode = $null
$existingSite = Invoke-MhhArm -Method GET -Path "${siteBase}?api-version=$webApiVersion" -AllowNotFound
if ($existingSite.StatusCode -eq 200) {
    $settings = (Invoke-MhhArm -Method POST -Path "$siteBase/config/appsettings/list?api-version=$webApiVersion").Content | ConvertFrom-Json
    $accessCode = $settings.properties.GATE_ACCESS_CODE
}
if (-not $accessCode) {
    $alphabet = "abcdefghjkmnpqrstuvwxyz23456789".ToCharArray()
    $accessCode = -join (1..8 | ForEach-Object { $alphabet[[Security.Cryptography.RandomNumberGenerator]::GetInt32($alphabet.Length)] })
}
$appSettings = @(
    @{ name = "DECISION_ENDPOINT";   value = "https://$accountName.services.ai.azure.com" },
    @{ name = "OPENAI_ENDPOINT";     value = "https://$accountName.openai.azure.com" },
    @{ name = "DECISION_DEPLOYMENT"; value = "decision" },
    @{ name = "LUNA_DEPLOYMENT";     value = "gpt-6-luna" },
    @{ name = "PROJECT_ENDPOINT";    value = "https://$accountName.services.ai.azure.com/api/projects/$projectName" },
    @{ name = "DECISION_CAPACITY";   value = "$($models[0].capacity)" },
    @{ name = "LUNA_CAPACITY";       value = "$($models[1].capacity)" },
    @{ name = "GATE_MAX_CONCURRENCY"; value = "2" },
    @{ name = "GATE_ACCESS_CODE";    value = $accessCode },
    @{ name = "SCM_DO_BUILD_DURING_DEPLOYMENT"; value = "true" },
    @{ name = "WEBSITES_PORT";       value = "8000" }
)
$siteBody = @{
    location = $effectiveLocation; kind = "app,linux"; identity = @{ type = "SystemAssigned" }
    properties = @{
        serverFarmId = $planBase; httpsOnly = $true
        siteConfig = @{
            linuxFxVersion = "PYTHON|3.12"; alwaysOn = $true; ftpsState = "Disabled"; minTlsVersion = "1.2"
            appCommandLine = "python -m uvicorn ui.app:app --host 0.0.0.0 --port 8000"
            appSettings = $appSettings
        }
    }
} | ConvertTo-Json -Depth 8
$site = (Invoke-MhhArm -Method PUT -Path "${siteBase}?api-version=$webApiVersion" -Payload $siteBody).Content | ConvertFrom-Json
$appPrincipal = $site.identity.principalId
if (-not $appPrincipal) {
    Start-Sleep -Seconds 10
    $appPrincipal = ((Invoke-MhhArm -Method GET -Path "${siteBase}?api-version=$webApiVersion").Content | ConvertFrom-Json).identity.principalId
}
Write-Host "[OK]    Web app '$webName' configured (identity $appPrincipal)."

foreach ($roleName in $roles.Keys) {
    if (-not (Get-AzRoleAssignment -ObjectId $appPrincipal -Scope $accountBase -RoleDefinitionId $roles[$roleName] -ErrorAction SilentlyContinue)) {
        $attempt = 0
        while ($true) {
            try {
                New-AzRoleAssignment -ObjectId $appPrincipal -RoleDefinitionId $roles[$roleName] -Scope $accountBase -ErrorAction Stop | Out-Null
                break
            } catch {
                # A brand-new managed identity can take a moment to reach Entra ID.
                if (++$attempt -ge 10) { throw }
                Start-Sleep -Seconds 15
            }
        }
        Write-Host "[OK]    Granted '$roleName' to the web app's identity."
    }
}

# Package src/ (without local environments, caches and secrets), with forward-slash entry names.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path ([IO.Path]::GetTempPath()) "$webName.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $root = (Resolve-Path $appSource).Path
    Get-ChildItem $root -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
        -not ($rel -match '^(\.venv|runs|state)/' -or $rel -match '(^|/)__pycache__/' -or $rel -in @('.env', 'uv.lock'))
    } | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $zip.Dispose() }

$scm = "https://$webName.scm.azurewebsites.net"
$siteHost = "$webName.azurewebsites.net"
# Prefer the host names App Service reports (newer apps can get unique default host names).
$siteProps = ((Invoke-MhhArm -Method GET -Path "${siteBase}?api-version=$webApiVersion").Content | ConvertFrom-Json).properties
if ($siteProps.defaultHostName) { $siteHost = $siteProps.defaultHostName }
$scmHost = ($siteProps.hostNameSslStates | Where-Object { $_.hostType -eq "Repository" } | Select-Object -First 1).name
if ($scmHost) { $scm = "https://$scmHost" }

# Network calls to a brand-new site can fail briefly (DNS, TLS): treat them as "not yet", not fatal.
function Invoke-MhhWeb([hashtable]$Params) {
    try { return Invoke-WebRequest @Params -SkipHttpErrorCheck }
    catch { Write-Host "[WAIT]  $($Params.Uri): $($_.Exception.Message)"; return $null }
}

$publish = $null
for ($attempt = 1; $attempt -le 6; $attempt++) {
    $publish = Invoke-MhhWeb @{ Method = "POST"; Uri = "$scm/api/publish?type=zip&isAsync=true"; InFile = $zipPath
        ContentType = "application/zip"; Headers = @{ Authorization = "Bearer $(Get-PlainToken 'https://management.azure.com/')" }; TimeoutSec = 300 }
    if ($publish -and $publish.StatusCode -in @(200, 202)) { break }
    Start-Sleep -Seconds 20   # the SCM site can need a moment after the app is created
}
if (-not $publish -or $publish.StatusCode -notin @(200, 202)) { throw "Publishing the console failed, HTTP $($publish.StatusCode): $($publish.Content)" }
Remove-Item $zipPath -Force

# Wait for the build (Oryx installs the Python packages; several minutes on B1).
$deadline = (Get-Date).AddMinutes(25)
do {
    Start-Sleep -Seconds 20
    $dep = Invoke-MhhWeb @{ Uri = "$scm/api/deployments/latest"; Headers = @{ Authorization = "Bearer $(Get-PlainToken 'https://management.azure.com/')" }; TimeoutSec = 60 }
    $depState = if ($dep -and $dep.StatusCode -eq 200) { ($dep.Content | ConvertFrom-Json) } else { $null }
} while ((-not $depState -or $depState.status -notin @(3, 4)) -and (Get-Date) -lt $deadline)
if (-not $depState -or $depState.status -ne 4) { throw "Building the console did not succeed: $($dep.Content)" }
# On a re-run the site is already running the previous build: restart it onto the new one.
Invoke-MhhArm -Method POST -Path "$siteBase/restart?api-version=$webApiVersion" | Out-Null
Write-Host "[OK]    Console published."

# Health: the app is up AND its identity can call Microsoft-Decision-1.1 (role propagation can
# take several minutes).
$consoleUrl = "https://$siteHost"
$deadline = (Get-Date).AddMinutes(15)
$health = $null
do {
    $health = Invoke-MhhWeb @{ Uri = "$consoleUrl/api/health"; TimeoutSec = 120 }
    if ($health -and $health.StatusCode -eq 200 -and ($health.Content | ConvertFrom-Json).ok) { break }
    Start-Sleep -Seconds 20
} while ((Get-Date) -lt $deadline)
if (-not ($health -and $health.StatusCode -eq 200 -and ($health.Content | ConvertFrom-Json).ok)) {
    throw "The console did not become healthy: HTTP $($health.StatusCode) $($health.Content)"
}
Write-Host "[OK]    Console healthy at $consoleUrl."
Write-Host "[OK]    Lab ready."

# ---------------------------------------------------------------------------
# 8. Dashboard credentials — only reached when everything above succeeded.
# ---------------------------------------------------------------------------
@{ HackboxCredential = @{ name = "ConsoleUrl";         value = $consoleUrl;       note = "Open this in your browser: the Launch Day console" } }
@{ HackboxCredential = @{ name = "AccessCode";         value = $accessCode;       note = "Enter it when the console asks" } }
@{ HackboxCredential = @{ name = "DecisionEndpoint";   value = $decisionEndpoint; note = "Build track: src/.env DECISION_ENDPOINT (Microsoft-Decision-1.1)" } }
@{ HackboxCredential = @{ name = "OpenAIEndpoint";     value = $openaiEndpoint;   note = "Build track: src/.env OPENAI_ENDPOINT (gpt-6-luna)" } }
@{ HackboxCredential = @{ name = "DecisionCapacity";   value = "$($models[0].capacity)"; note = "Build track: src/.env DECISION_CAPACITY" } }
@{ HackboxCredential = @{ name = "LunaCapacity";       value = "$($models[1].capacity)"; note = "Build track: src/.env LUNA_CAPACITY" } }
@{ HackboxCredential = @{ name = "FoundryProjectEndpoint"; value = "https://$accountName.services.ai.azure.com/api/projects/$projectName"; note = "Optional: src/.env PROJECT_ENDPOINT" } }
@{ HackboxCredential = @{ name = "ResourceGroupName";  value = $effectiveRG;      note = "Where your Foundry resource and console live" } }
if ($cloudShellReady) {
    @{ HackboxCredential = @{ name = "CloudShellStorage"; value = $storageName; note = "Build track: Cloud Shell > Mount storage account > Select existing; file share 'cloudshell'" } }
}
