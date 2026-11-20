Set-StrictMode -Version Latest

function Get-LabFingerprint {
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
    $json = ConvertTo-CanonicalValue $Value | ConvertTo-Json -Depth 40 -Compress
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

function Assert-LabRelativePath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '(^[\\/]|:|(^|[\\/])\.\.?([\\/]|$))' -or
        $Value -match '(?i)(^|[\\/])(coach|solutions?|walkthrough)([\\/]|$)') {
        throw 'Staged paths must be relative, traversal-free and must not contain coach solutions.'
    }
}

function Assert-LabCidr {
    param([string]$Value)
    $parts = $Value.Split('/')
    $ip = $null
    if ($parts.Count -ne 2 -or -not [Net.IPAddress]::TryParse($parts[0], [ref]$ip) -or
        $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
        $parts[1] -notmatch '^\d+$' -or [int]$parts[1] -lt 24 -or [int]$parts[1] -gt 32 -or
        $parts[0] -eq '0.0.0.0' -or $ip.IsIPv6Multicast) {
        throw 'RDP requires an approved explicit IPv4 /24 through /32 source CIDR; wildcard Internet access is prohibited.'
    }
}

function Read-LabEventConfiguration {
    param([string]$Path = $env:MHH_EVENT_CONFIG)
    if (-not $Path -or -not [IO.Path]::IsPathFullyQualified($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Set MHH_EVENT_CONFIG to an absolute private approved event JSON file before any launch.'
    }
    $json = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if (-not (Test-Json -Json $json -SchemaFile (Join-Path $PSScriptRoot 'event-config.schema.json') -ErrorAction Stop)) {
        throw 'Event configuration failed schema validation.'
    }
    $config = $json | ConvertFrom-Json -AsHashtable
    if (-not $config.approved) { throw 'Event launch is blocked: configuration not approved.' }
    foreach ($entry in $config.evidence.GetEnumerator()) {
        if (-not $entry.Value.verified -or [string]::IsNullOrWhiteSpace($entry.Value.reference)) {
            throw "Event launch is blocked: missing verified evidence for $($entry.Key)."
        }
    }
    if ($config.sizing.measuredConcurrentNotebooks -gt $config.sizing.measuredParticipantsPerSubscription) {
        throw 'Measured concurrent notebooks cannot exceed the measured participant envelope.'
    }
    if ($config.participants.Count -gt $config.sizing.measuredParticipantsPerSubscription * $config.subscriptionIds.Count) {
        throw 'Roster exceeds the approved measured envelope.'
    }
    if ($config.cost.perParticipantDailyUsd -lt 1 -or $config.cost.sharedDailyUsd -le 0) {
        throw 'Real cost approval required; platform silently substitutes a $25 per-lab estimate below $1.'
    }
    $forecast = ($config.cost.retentionHours / 24) * (
        $config.participants.Count * $config.cost.perParticipantDailyUsd +
        $config.subscriptionIds.Count * $config.cost.sharedDailyUsd)
    if ($forecast -gt $config.cost.budgetUsd) { throw 'Approved forecast exceeds the event budget.' }
    $ids = @($config.participants | ForEach-Object objectId)
    if (@($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Participant identities must be unique.' }
    $scopes = @($config.participants | ForEach-Object { "$($_.subscriptionId)/$($_.resourceGroupName)" })
    if (@($scopes | Select-Object -Unique).Count -ne $scopes.Count) { throw 'Participant resource groups must be unique.' }
    foreach ($sub in $config.subscriptionIds) {
        if (@($config.participants | Where-Object subscriptionId -EQ $sub).Count -gt $config.sizing.measuredParticipantsPerSubscription) {
            throw 'Subscription roster exceeds measured cohort size.'
        }
    }
    foreach ($participant in $config.participants) {
        if ($participant.subscriptionId -notin $config.subscriptionIds) { throw 'Roster subscription not approved.' }
        if ($participant.objectId -in $config.capacityAdministrators) { throw 'Participants must not be shared capacity administrators.' }
        if ($participant.resourceGroupName -like 'rg-apbi-shared-*') { throw 'Participant group collides with reserved shared scope.' }
        Assert-LabCidr $participant.sourceAddressPrefix
    }
    foreach ($asset in @($config.bootstrap, $config.source) + @($config.tools)) { Assert-LabPublicUri $asset.uri }
    if (-not $config.source.uri.Contains($config.source.ref) -or -not $config.bootstrap.uri.Contains($config.source.ref)) {
        throw 'Source and bootstrap URLs must include the approved immutable source commit.'
    }
    if (([uri]$config.bootstrap.uri).AbsolutePath -notmatch '/bootstrap\.ps1$') { throw 'Bootstrap URI must end in /bootstrap.ps1.' }
    foreach ($path in @($config.source.root, $config.source.banking, $config.source.insurance, $config.source.briefs,
            $config.source.manifest, $config.source.dictionary, $config.source.generator, $config.source.generatorCli,
            $config.hosts.cliSkills, $config.hosts.cliMcp, $config.hosts.vscodeSkills, $config.hosts.vscodeMcp)) {
        Assert-LabRelativePath $path
    }
    if ($config.source.banking -eq $config.source.insurance) { throw 'Both distinct CSV scenarios are required.' }
    foreach ($tool in $config.tools) {
        if ($tool.version -match '(?i)latest|preview|\*' -or $tool.version -notmatch '\d') { throw 'Only explicit approved tool versions are supported.' }
        Assert-LabRelativePath $tool.executable
        if ($tool.name -eq 'node' -and [int]($tool.version.Split('.')[0]) -lt 22) { throw 'Obsolete Node runtime not supported.' }
    }
    if (@($config.tools.name | Select-Object -Unique).Count -ne $config.tools.Count) { throw 'Duplicate tool packages.' }
    foreach ($required in 'git', 'node', 'vscode', 'copilot', 'azure-cli', 'python') {
        if ($required -notin $config.tools.name) { throw "Missing pinned tool package: $required" }
    }
    if ($config.vm.image.version -match '(?i)latest|\*' -or $config.vm.image.version -notmatch '^\d+\.\d+\.\d+$') {
        throw 'An exact approved Windows image version is required.'
    }
    return $config
}

function Invoke-LabAzureOperation {
    param([scriptblock]$Operation, [string]$Description)
    # Never rethrow provider bodies: deployment failures can echo protected parameters.
    try { & $Operation 3>$null 4>$null 5>$null 6>$null }
    catch { throw [InvalidOperationException]::new("$Description failed. Inspect Azure operation status privately; provider response suppressed.") }
}

function Assert-LabContext {
    param([hashtable]$Config, [string]$SubscriptionId, [string[]]$PreferredLocation)
    if ($SubscriptionId -notin $Config.subscriptionIds) { throw 'Subscription is not approved.' }
    $regions = @($PreferredLocation | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() })
    if ($Config.region -notin $regions) { throw 'Approved region must be explicitly provided by the platform; no automatic region fallback.' }
    $context = Invoke-LabAzureOperation { Get-AzContext -ErrorAction Stop } 'Read Azure context'
    if ($context.Subscription.Id -ne $SubscriptionId) { throw 'Azure context subscription mismatch; hooks never authenticate or switch context.' }
    foreach ($provider in 'Microsoft.Fabric', 'Microsoft.Compute', 'Microsoft.Network') {
        $registration = @(Invoke-LabAzureOperation { Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop } 'Read resource-provider registration')
        if (@($registration | Where-Object RegistrationState -EQ 'Registered').Count -eq 0) { throw "Administrator must register $provider before launch." }
    }
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
    if ($group[0].Location -ne $Location) { throw 'Resource group region differs; refusing destructive fallback.' }
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
        $operationStatus = if ($body -and $body.ContainsKey('status')) { $body['status'] } else { '' }
        $resourceState = if ($body -and $body.ContainsKey('properties') -and $body.properties.ContainsKey('provisioningState')) {
            $body.properties['provisioningState']
        } else { '' }
        if ($operationStatus -in 'Failed', 'Canceled', 'Cancelled' -or $resourceState -in 'Failed', 'Canceled', 'Cancelled') {
            throw 'ARM operation failed or was cancelled.'
        }
        $headers = $response.Headers
        $next = $headers['Azure-AsyncOperation']
        if (-not $next) { $next = $headers['Location'] }
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
        $delay = Get-LabRetryDelay $headers['Retry-After']
        if ($timer.Elapsed.TotalSeconds + $delay -ge $TimeoutSeconds) { throw 'ARM Retry-After exceeds remaining operation deadline.' }
        Start-Sleep -Seconds $delay
    }
    throw 'ARM request limit reached; inspect status before retrying.'
}
