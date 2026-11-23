Set-StrictMode -Version Latest

function ConvertTo-LabCanonicalJson {
    param([Parameter(Mandatory)][object]$Value)
    # Canonical ordering makes hashes independent of JSON/object key order.
    function ConvertTo-CanonicalValue($Item) {
        if ($Item -is [System.Collections.IDictionary]) {
            $ordered = [ordered]@{}
            foreach ($key in @($Item.Keys | Sort-Object)) { $ordered[$key] = ConvertTo-CanonicalValue $Item[$key] }
            return $ordered
        }
        if ($Item -is [array]) { return ,@($Item | ForEach-Object { ConvertTo-CanonicalValue $_ }) }
        return $Item
    }
    return ConvertTo-CanonicalValue $Value | ConvertTo-Json -Depth 40 -Compress
}

function Get-LabFingerprint {
    param([Parameter(Mandatory)][object]$Value)
    $json = ConvertTo-LabCanonicalJson $Value
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Assert-LabPublicUri {
    param([string]$Value)
    $uri = $null
    if (-not [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.IsLoopback -or -not $uri.IsDefaultPort -or $uri.HostNameType -ne 'Dns') {
        throw 'Assets must use public HTTPS DNS URLs without credentials, query strings or fragments.'
    }
}

function Read-LabSettings {
    $settings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'lab-settings.psd1')
    if ($settings.SourceRef -notmatch '^[a-f0-9]{40}$') { throw 'Student source must use an immutable commit.' }
    foreach ($asset in @($settings.Tools) + @($settings.Skills) + @($settings.Extensions)) {
        Assert-LabPublicUri $asset.uri
        if ($asset.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Every asset needs a SHA256 digest.' }
    }
    foreach ($name in 'powershell', 'git', 'node', 'vscode', 'copilot', 'azure-cli', 'python') {
        $tool = @($settings.Tools | Where-Object name -EQ $name)
        if ($tool.Count -ne 1 -or $tool[0].version -notmatch '^\d+\.\d+\.\d+$') { throw "Missing or unpinned tool: $name" }
    }
    return $settings
}

function Get-LabPlatformContext {
    param([string]$SubscriptionId, [string[]]$PreferredLocation, [string[]]$AllowedEntraUserIds)
    if ($SubscriptionId -notmatch '^[a-fA-F0-9-]{36}$') { throw 'A platform subscription ID is required.' }
    if ($AllowedEntraUserIds.Count -eq 0 -or
        @($AllowedEntraUserIds | Select-Object -Unique).Count -ne $AllowedEntraUserIds.Count -or
        @($AllowedEntraUserIds | Where-Object { $_ -notmatch '^[a-fA-F0-9-]{36}$' }).Count) {
        throw 'Platform participant IDs must be nonempty, unique GUIDs.'
    }
    $context = Invoke-LabAzureOperation { Get-AzContext -ErrorAction Stop } 'Read Azure context'
    if ($context.Subscription.Id -ne $SubscriptionId) { throw 'Azure context subscription mismatch; hooks never authenticate or switch context.' }
    $settings = Read-LabSettings
    $regions = @($PreferredLocation | ForEach-Object { $_.Split(',') } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
    if ($regions.Count -eq 0) { $regions = @($settings.DefaultRegion) }
    foreach ($region in $regions) {
        if ($region -notmatch '^[a-z0-9]+$') { throw 'Invalid preferred Azure region.' }
    }
    foreach ($provider in 'Microsoft.Fabric', 'Microsoft.Compute', 'Microsoft.Network') {
        $registration = @(Invoke-LabAzureOperation { Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop } 'Read resource-provider registration')
        if (@($registration | Where-Object RegistrationState -EQ 'Registered').Count -eq 0) {
            if (@($registration | Where-Object RegistrationState -EQ 'Registering').Count -eq 0) {
                $null = Invoke-LabAzureOperation { Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop } "Register $provider"
            }
            $registered = $false
            $deadline = [DateTimeOffset]::UtcNow.AddMinutes(10)
            for ($attempt = 0; $attempt -lt 120; $attempt++) {
                $remaining = [int][Math]::Floor(($deadline - [DateTimeOffset]::UtcNow).TotalSeconds)
                if ($remaining -lt 1) { break }
                Start-Sleep -Seconds ([Math]::Min(5, $remaining))
                $registration = @(Invoke-LabAzureOperation { Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop } "Wait for $provider registration")
                if (@($registration | Where-Object RegistrationState -EQ 'Registered').Count -gt 0) {
                    $registered = $true
                    break
                }
            }
            if (-not $registered) { throw "$provider did not become Registered within the registration wait limit. No lab deployment was started; inspect provider registration before retrying." }
        }
    }
    return @{ Settings = $settings; Regions = $regions; Context = $context }
}

function Get-LabCapacityAdministrator {
    param([string[]]$ParticipantIds)
    # Read only the caller's oid claim; no Graph directory permission is required.
    $access = Invoke-LabAzureOperation { Get-AzAccessToken -ResourceUrl 'https://management.azure.com/' -ErrorAction Stop } 'Resolve deployment principal'
    $credential = $null
    try {
        $token = if ($access.Token -is [securestring]) {
            $credential = [pscredential]::new('token', $access.Token)
            $credential.GetNetworkCredential().Password
        } else { [string]$access.Token }
        $part = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
        $part = $part.PadRight($part.Length + ((4 - $part.Length % 4) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
        $objectId = [string]$claims.oid
        if ($objectId -notmatch '^[a-fA-F0-9-]{36}$' -or $objectId -in $ParticipantIds) {
            throw 'Deployment principal must be a nonparticipant capacity administrator.'
        }
        return $objectId
    } finally { $token = $null; $credential = $null; $access = $null }
}

function Get-LabRegionImage {
    param([string]$SubscriptionId, [string[]]$Regions, [hashtable]$Settings)
    $fabricSkus = @()
    $next = "/subscriptions/$SubscriptionId/providers/Microsoft.Fabric/skus?api-version=2023-11-01"
    for ($page = 0; $next; $page++) {
        if ($page -ge 20) { throw 'Fabric SKU metadata pagination exceeded its bound.' }
        $fabric = Invoke-LabArmRequest -Path $next
        $fabricSkus += @($fabric.value)
        $next = if ($fabric.ContainsKey('nextLink')) { $fabric.nextLink } else { $null }
        if ($next) {
            $next = ConvertTo-LabArmPath $next
            if ((($next.Split('?')[0] -split '/')[2]) -ne $SubscriptionId) {
                throw 'Fabric SKU pagination changed subscription.'
            }
        }
    }
    $network = Invoke-LabAzureOperation { Get-AzResourceProvider -ProviderNamespace 'Microsoft.Network' -ErrorAction Stop } 'Read network regions'
    $bastionLocations = @($network.ResourceTypes | Where-Object ResourceTypeName -EQ 'bastionHosts' | ForEach-Object Locations |
        ForEach-Object { $_.Replace(' ', '').ToLowerInvariant() })
    foreach ($region in $Regions) {
        $sku = @($fabricSkus | Where-Object {
            $_.name -eq 'F16' -and $region -in @($_.locations | ForEach-Object { $_.Replace(' ', '').ToLowerInvariant() })
        })
        if ($sku.Count -eq 0 -or $region -notin $bastionLocations) {
            Write-Warning "Skipping ${region}: F16 or Bastion is unavailable in provider metadata."
            continue
        }
        $image = $Settings.Image
        $versions = Invoke-LabArmRequest -Path "/subscriptions/$SubscriptionId/providers/Microsoft.Compute/locations/$region/publishers/$($image.publisher)/artifacttypes/vmimage/offers/$($image.offer)/skus/$($image.sku)/versions?api-version=2024-03-01"
        $available = @($versions | Where-Object name -Match '^\d+\.\d+\.\d+$' | Sort-Object { [version]$_.name } -Descending)
        if ($available.Count -eq 0) { Write-Warning "Skipping ${region}: Windows image has no available version."; continue }
        $resolved = $image.Clone()
        $resolved.version = $available[0].name
        return @{ Region = $region; Image = $resolved }
    }
    throw 'No preferred region advertises F16, Bastion and the Windows image. Check region availability; no paid deployment was attempted.'
}

function Get-LabGuestConfiguration {
    param([hashtable]$Settings)
    $files = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'student-files.json') -Raw | ConvertFrom-Json -AsHashtable
    return @{
        bootstrap = Get-LabFingerprint @{ script = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bootstrap.ps1') -Raw).Replace("`r`n", "`n") }
        source = @{ ref = $Settings.SourceRef; files = $files }
        tools = $Settings.Tools; skills = $Settings.Skills; extensions = $Settings.Extensions
        npm = @{
            package = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'npm-runtime\package.json') -Raw).Replace("`r`n", "`n")
            lock = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'npm-runtime\package-lock.json') -Raw).Replace("`r`n", "`n")
        }
    }
}

function Invoke-LabAzureOperation {
    param([scriptblock]$Operation, [string]$Description)
    # Never rethrow provider bodies: deployment failures can echo protected parameters.
    try {
        if (Get-Command Update-MhhToken -ErrorAction SilentlyContinue) { Update-MhhToken | Out-Null }
        & $Operation 3>$null 4>$null 5>$null 6>$null
    }
    catch { throw [InvalidOperationException]::new("$Description failed. Inspect Azure operation status privately; provider response suppressed.") }
}

function Assert-LabResourceGroup {
    param([string]$Name, [string]$Location, [hashtable]$Tags, [switch]$ClaimEmpty, [string]$ImplicitVmId = '')
    $groups = @(Invoke-LabAzureOperation { Get-AzResourceGroup -ErrorAction Stop } 'List resource groups')
    $group = @($groups | Where-Object ResourceGroupName -EQ $Name)
    if ($group.Count -eq 0) {
        if ($ClaimEmpty) { throw 'Participant resource group must already be provisioned by the platform.' }
        $null = Invoke-LabAzureOperation { New-AzResourceGroup -Name $Name -Location $Location -Tag $Tags -ErrorAction Stop } 'Create owned shared resource group'
        return
    }
    # An RG's metadata location need not match its resources' deployment region.
    $resources = @(Invoke-LabAzureOperation { Get-AzResource -ResourceGroupName $Name -ErrorAction Stop } 'Inspect resource ownership')
    $existingTags = $group[0].Tags
    $hasOwnershipTag = $existingTags -and @($Tags.Keys | Where-Object { $existingTags.ContainsKey($_) }).Count -gt 0
    $isEmptyClaim = $ClaimEmpty -and $resources.Count -eq 0 -and -not $hasOwnershipTag
    if (-not $isEmptyClaim) {
        foreach ($key in $Tags.Keys) {
            if (-not $existingTags -or $existingTags[$key] -ne $Tags[$key]) { throw 'Resource group ownership/configuration collision; refusing adoption.' }
        }
    }
    foreach ($resource in $resources) {
        $hasResourceOwnershipTag = $resource.Tags -and @($Tags.Keys | Where-Object { $resource.Tags.ContainsKey($_) }).Count -gt 0
        if ($ImplicitVmId -and $resource.ResourceType -eq 'Microsoft.Compute/disks' -and -not $hasResourceOwnershipTag) {
            $owningVm = @($resources | Where-Object ResourceId -EQ $ImplicitVmId)
            if ($owningVm.Count -ne 1) { throw 'Implicit disk has no matching owned VM.' }
            foreach ($key in $Tags.Keys) {
                if (-not $owningVm[0].Tags -or $owningVm[0].Tags[$key] -ne $Tags[$key]) { throw 'Implicit disk VM ownership mismatch.' }
            }
            $disk = Invoke-LabArmRequest -Path "$($resource.ResourceId)?api-version=2024-03-02"
            if (-not $disk.ContainsKey('managedBy') -or $disk.managedBy -ne $ImplicitVmId) { throw 'Implicit disk is not attached to its expected owned VM.' }
            $null = Invoke-LabAzureOperation {
                Update-AzTag -ResourceId $resource.ResourceId -Operation Merge -Tag $Tags -ErrorAction Stop
            } 'Tag verified implicit VM disk'
            continue
        }
        foreach ($key in $Tags.Keys) {
            if (-not $resource.Tags -or $resource.Tags[$key] -ne $Tags[$key]) { throw 'Existing resource ownership/configuration collision.' }
        }
    }
    if ($isEmptyClaim) {
        $merged = @{}
        if ($existingTags) { foreach ($key in $existingTags.Keys) { $merged[$key] = $existingTags[$key] } }
        foreach ($key in $Tags.Keys) { $merged[$key] = $Tags[$key] }
        $null = Invoke-LabAzureOperation { Set-AzResourceGroup -Name $Name -Tag $merged -ErrorAction Stop } 'Claim empty participant resource group'
    }
}

function Get-LabRetryDelay {
    param([object]$RetryAfter, [int]$DefaultSeconds = 5)
    if ([string]::IsNullOrWhiteSpace([string]$RetryAfter)) { return $DefaultSeconds }
    $seconds = 0
    if ([int]::TryParse([string]$RetryAfter, [ref]$seconds)) { return [Math]::Max(1, $seconds) }
    $date = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$RetryAfter, [ref]$date)) {
        return [Math]::Max(1, [int][Math]::Ceiling(($date - [DateTimeOffset]::UtcNow).TotalSeconds))
    }
    throw 'Invalid ARM Retry-After header.'
}

function ConvertTo-LabArmPath {
    param([string]$Value)
    if ($Value.StartsWith('/subscriptions/', [StringComparison]::OrdinalIgnoreCase) -and $Value -notmatch '\.\.|[\\#]|%(2e|2f|5c)') { return $Value }
    $uri = $null
    if ([uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -eq 'https' -and
        $uri.Host -eq 'management.azure.com' -and $uri.IsDefaultPort -and -not $uri.UserInfo -and -not $uri.Fragment) {
        return ConvertTo-LabArmPath $uri.PathAndQuery
    }
    throw 'Untrusted ARM polling URL.'
}

function Get-LabResponseHeader {
    param([object]$Headers, [string]$Name)
    if ($null -eq $Headers) { return $null }
    $values = $null
    if ($Headers -is [Net.Http.Headers.HttpHeaders]) {
        if (-not $Headers.TryGetValues($Name, [ref]$values)) { return $null }
    } elseif ($Headers -is [System.Collections.IDictionary]) {
        $keys = @($Headers.Keys | Where-Object { $_ -ieq $Name })
        if ($keys.Count -eq 0) { return $null }
        $values = $Headers[$keys[0]]
    } else { throw 'Unsupported ARM response header type.' }
    $entries = @($values)
    if ($entries.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$entries[0])) {
        throw "Invalid ARM $Name header."
    }
    return [string]$entries[0]
}

function Invoke-LabArmRequest {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method = 'GET',
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 900,
        [ValidateRange(1, 600)][int]$MaxRequests = 120
    )
    $pathToPoll = ConvertTo-LabArmPath $Path
    $subscriptionPrefix = ($pathToPoll.Split('?')[0] -split '/')[2]
    $timer = [Diagnostics.Stopwatch]::StartNew()
    for ($attempt = 0; $attempt -lt $MaxRequests; $attempt++) {
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'ARM operation timed out; inspect status before rerunning.' }
        $response = Invoke-LabAzureOperation { Invoke-AzRestMethod -Method $Method -Path $pathToPoll -ErrorAction Stop } 'ARM request'
        $status = [int]$response.StatusCode
        if ($status -notin 200, 201, 202, 204, 429, 503) { throw "ARM HTTP $status; no success fallback." }
        $body = $null
        if ($response.Content) {
            try { $body = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
            catch { throw 'Invalid JSON from ARM.' }
        }
        $objectBody = $body -is [System.Collections.IDictionary]
        $operationStatus = if ($objectBody -and $body.ContainsKey('status')) { $body['status'] } else { '' }
        $resourceState = if ($objectBody -and $body.ContainsKey('properties') -and $body.properties -and $body.properties.ContainsKey('provisioningState')) {
            $body.properties['provisioningState']
        } else { '' }
        if ($operationStatus -in 'Failed', 'Canceled', 'Cancelled' -or $resourceState -in 'Failed', 'Canceled', 'Cancelled') {
            throw 'ARM operation failed or was cancelled.'
        }
        $headers = $response.Headers
        $next = Get-LabResponseHeader $headers 'Azure-AsyncOperation'
        if (-not $next) { $next = Get-LabResponseHeader $headers 'Location' }
        $pending = $operationStatus -in 'InProgress', 'Running', 'Accepted' -or
            ($resourceState -and $resourceState -ne 'Succeeded')
        if ($operationStatus -and $operationStatus -notin 'Succeeded', 'InProgress', 'Running', 'Accepted') { throw 'Unknown ARM operation state.' }
        if ($status -in 200, 201, 204 -and -not $pending -and -not $next) { return $body }
        if ($status -notin 429, 503) {
            if ($next) {
                $pathToPoll = ConvertTo-LabArmPath ([string]$next)
                if ((($pathToPoll.Split('?')[0] -split '/')[2]) -ne $subscriptionPrefix) { throw 'ARM polling URL changed subscription.' }
                $Method = 'GET'
            }
            elseif ($status -eq 202) { throw 'ARM accepted the request without a supported polling URL.' }
        }
        $delay = Get-LabRetryDelay (Get-LabResponseHeader $headers 'Retry-After')
        if ($timer.Elapsed.TotalSeconds + $delay -ge $TimeoutSeconds) { throw 'ARM Retry-After exceeds remaining operation deadline.' }
        Start-Sleep -Seconds $delay
    }
    throw 'ARM request limit reached; inspect status before retrying.'
}
