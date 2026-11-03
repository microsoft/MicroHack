function Invoke-LocalBoxAutomationAz {
    param([Parameter(Mandatory)][string[]]$Arguments)
    Update-MhhToken | Out-Null
    $output = & az @Arguments --only-show-errors --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "LocalBox automation Azure CLI failed: $($output -join "`n")" }
    if ($output) { ($output -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
}

function Invoke-LocalBoxAutomationRequest {
    param([string]$Path, [string]$Method = 'GET', [hashtable]$Body, [switch]$AllowNotFound)
    Update-MhhToken | Out-Null
    $arguments = @{ Path = $Path; Method = $Method; ErrorAction = 'Stop' }
    if ($Body) { $arguments.Payload = $Body | ConvertTo-Json -Depth 30 -Compress }
    $response = Invoke-AzRestMethod @arguments
    if ($AllowNotFound -and $response.StatusCode -eq 404) { return }
    if ($response.StatusCode -notin @(200, 201, 202, 204)) {
        throw "LocalBox automation $Method failed (HTTP $($response.StatusCode)): $($response.Content)"
    }
    if ($response.Content) { $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
}

function Wait-LocalBoxAutomation {
    param([scriptblock]$Probe, [int]$TimeoutSeconds, [string]$Phase)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Update-MhhToken | Out-Null
        $state = & $Probe
        if ($state.Ready) { return $state }
        if ([datetime]::UtcNow -ge $deadline) { throw "Timed out during $Phase. $($state.Detail)" }
        Write-Host "LocalBox ${Phase}: $($state.Detail)"
        Start-Sleep -Seconds 30
    } while ($true)
}

function Wait-LocalBoxNestedDeployment {
    param([string]$SubscriptionId, [string]$ResourceGroupName, [int]$TimeoutSeconds = 28800)
    Wait-LocalBoxAutomation -Phase 'nested deployment' -TimeoutSeconds $TimeoutSeconds -Probe {
        $deployments = @(Invoke-LocalBoxAutomationAz @('deployment', 'group', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName))
        $clusterDeployment = @($deployments | Where-Object name -eq 'localcluster-deploy')
        foreach ($deployment in @($deployments | Where-Object name -in @('localcluster-validate', 'localcluster-deploy'))) {
            if ($deployment.properties.provisioningState -in @('Failed', 'Canceled')) {
                throw "Nested deployment $($deployment.name) failed. Inspect its deployment operations and Client logs."
            }
        }
        if ($clusterDeployment.Count -ne 1 -or $clusterDeployment[0].properties.provisioningState -ne 'Succeeded') {
            return @{ Ready = $false; Detail = 'Waiting for localcluster-deploy to succeed.' }
        }
        $resources = @(Invoke-LocalBoxAutomationAz @('resource', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName))
        foreach ($type in @('Microsoft.AzureStackHCI/clusters', 'Microsoft.ResourceConnector/appliances', 'Microsoft.ExtendedLocation/customLocations')) {
            $matching = @($resources | Where-Object type -ieq $type)
            if ($matching.Count -gt 1) { throw "Expected one $type in the shared LocalBox scope." }
            if ($matching.Count -eq 0) { return @{ Ready = $false; Detail = "Waiting for $type." } }
            $resource = Invoke-LocalBoxAutomationAz @('resource', 'show', '--ids', $matching[0].id)
            if ($resource.properties.provisioningState -in @('Failed', 'Canceled')) { throw "$($resource.id) is $($resource.properties.provisioningState)." }
            if ($resource.properties.provisioningState -ne 'Succeeded') { return @{ Ready = $false; Detail = "Waiting for $type provisioning." } }
            if ($type -eq 'Microsoft.AzureStackHCI/clusters' -and $resource.properties.connectivityStatus -ne 'Connected') {
                return @{ Ready = $false; Detail = 'Waiting for Azure Local connectivity.' }
            }
            if ($type -eq 'Microsoft.ResourceConnector/appliances' -and $resource.properties.status -ne 'Running') {
                return @{ Ready = $false; Detail = 'Waiting for Arc Resource Bridge.' }
            }
            if ($type -eq 'Microsoft.ExtendedLocation/customLocations') {
                $extensions = @($resource.properties.clusterExtensionIds | Where-Object { $_ -match '/hybridaksextension$' })
                if ($extensions.Count -ne 1) { return @{ Ready = $false; Detail = 'Waiting for hybridaksextension association.' } }
                $extension = Invoke-LocalBoxAutomationAz @('resource', 'show', '--ids', $extensions[0], '--api-version', '2023-05-01')
                if ($extension.properties.provisioningState -in @('Failed', 'Canceled')) { throw 'hybridaksextension provisioning failed.' }
                if ($extension.properties.provisioningState -ne 'Succeeded') { return @{ Ready = $false; Detail = 'Waiting for hybridaksextension.' } }
            }
        }
        @{ Ready = $true }
    } | Out-Null
}

function New-LocalBoxAutomationPackage {
    param(
        [string]$ResourceRoot = (Join-Path $PSScriptRoot '../resources'),
        [string]$Directory,
        [string]$SourceManifestPath = (Join-Path $PSScriptRoot 'localbox-automation-source.json')
    )
    $ErrorActionPreference = 'Stop'
    $files = @('prepare-localbox.ps1', 'invoke-localbox-automation.ps1', 'test-sovereign-cloud.ps1',
        'tests/localbox.health.tests.ps1', 'tests/sovereign-lab.health.tests.ps1')
    $ownsDirectory = -not $Directory
    if ($ownsDirectory) { $Directory = Join-Path ([IO.Path]::GetTempPath()) "localbox-package-$([guid]::NewGuid())" }
    try {
        $contents = [ordered]@{}
        $package = Join-Path $Directory 'package'
        New-Item -ItemType Directory -Path "$package/tests" -Force | Out-Null
        $missing = @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ResourceRoot $_) -PathType Leaf) })
        $sourceManifest = $null
        if ($missing.Count) {
            $sourceManifest = Get-Content -LiteralPath $SourceManifestPath -Raw | ConvertFrom-Json -AsHashtable
            if ($sourceManifest.repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or
                $sourceManifest.commit -notmatch '^[a-fA-F0-9]{40}$' -or $sourceManifest.files.Count -ne $files.Count) {
                throw 'LocalBox source manifest must identify one repository, immutable commit and the exact guest file set.'
            }
            foreach ($file in $files) {
                if ($sourceManifest.files[$file] -notmatch '^[a-fA-F0-9]{64}$') { throw "Missing or invalid SHA256 for guest source $file." }
            }
            Write-Host "LocalBox guest sources are absent from the content mount ($($missing -join ', ')). Downloading the complete pinned set from $($sourceManifest.repository) at $($sourceManifest.commit)."
        }
        else { Write-Host 'Packaging LocalBox guest scripts from the local resources directory.' }
        foreach ($file in $files) {
            $destination = Join-Path $package $file
            if ($sourceManifest) {
                $base = "https://raw.githubusercontent.com/$($sourceManifest.repository)/$($sourceManifest.commit)/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources"
                Invoke-WebRequest -Uri "$base/$file" -OutFile $destination -TimeoutSec 120 -ErrorAction Stop | Out-Null
            }
            else {
                Copy-Item -LiteralPath (Join-Path $ResourceRoot $file) -Destination $destination -ErrorAction Stop
            }
            $contents[$file] = (Get-FileHash -LiteralPath $destination -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($sourceManifest -and $contents[$file] -ine $sourceManifest.files[$file]) {
                throw "SHA256 mismatch for LocalBox guest source $file. No guest code was submitted."
            }
        }
        $bytes = [Text.Encoding]::UTF8.GetBytes(($contents | ConvertTo-Json -Compress))
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $archive = Join-Path $Directory 'package.zip'
        Compress-Archive -Path "$package/*" -DestinationPath $archive -ErrorAction Stop
        @{ Hash = $hash; Archive = [Convert]::ToBase64String([IO.File]::ReadAllBytes($archive)) }
    }
    finally {
        if ($ownsDirectory -and (Test-Path -LiteralPath $Directory)) {
            Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction Stop
        }
    }
}

function New-LocalBoxGuestCommand {
    param([hashtable]$Configuration, [string]$Archive)
    $configurationBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Configuration | ConvertTo-Json -Compress)))
    # Managed Run Command starts Windows PowerShell as SYSTEM. Launch PS7 explicitly.
    @'
$ErrorActionPreference = 'Stop'
try {
    $settings = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__CONFIG__')) | ConvertFrom-Json
    $root = 'C:\LocalBox\MicroHackAutomation'
    $directory = Join-Path $root $settings.RunId
    foreach ($path in @($root, $directory)) {
        if (Test-Path -LiteralPath $path) {
            if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Automation directory must not be a link.' }
        } else { New-Item -ItemType Directory -Path $path | Out-Null }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetOwner($identity)
        $acl.SetAccessRuleProtection($true, $false)
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    $archivePath = Join-Path $directory 'package.zip'
    [IO.File]::WriteAllBytes($archivePath, [Convert]::FromBase64String('__ARCHIVE__'))
    Expand-Archive -LiteralPath $archivePath -DestinationPath $directory -Force
    Remove-Item -LiteralPath $archivePath -Force
    $parametersPath = Join-Path $directory 'automation.json'
    [IO.File]::WriteAllText($parametersPath, [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__CONFIG__')))
    & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -NonInteractive -File "$directory\invoke-localbox-automation.ps1" -ParametersPath $parametersPath
    exit $LASTEXITCODE
} catch {
    Write-Error $_
    exit 1
}
'@.Replace('__CONFIG__', $configurationBase64).Replace('__ARCHIVE__', $Archive)
}

function Assert-LocalBoxAutomationResult {
    param([hashtable]$Result, [string]$RunId, [string]$PackageHash, [string]$GroupId, [string]$SubscriptionId, [string]$ResourceGroupName)
    if ($Result.RunId -ne $RunId -or $Result.PackageHash -ne $PackageHash -or
        $Result.AksAdminGroupObjectId -ne $GroupId -or $Result.SubscriptionId -ne $SubscriptionId -or
        $Result.ResourceGroupName -ne $ResourceGroupName -or $Result.State -ne 'Succeeded') {
        throw 'LocalBox automation result is missing, stale, mismatched or unsuccessful.'
    }
    foreach ($suite in @('Upstream', 'Sovereign')) {
        $tests = $Result[$suite]
        if (-not $tests -or $tests.Passed -le 0 -or $tests.Failed -ne 0 -or $tests.Skipped -ne 0 -or $tests.NotRun -ne 0) {
            throw "LocalBox $suite tests did not establish readiness."
        }
    }
    if ($Result.UpdateAssessment.Status -ne 'Succeeded' -or -not $Result.UpdateAssessment.Timestamp) {
        throw 'Reference VM update assessment did not complete successfully.'
    }
}

function Assert-LocalBoxAutomationXml {
    param([string]$Path, [hashtable]$Expected)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $reader = [Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
        $cases = @($document.SelectNodes('//test-case'))
        if ($document.DocumentElement.get_LocalName() -ne 'test-results' -or $cases.Count -ne $Expected.Passed -or
            @($cases | Where-Object { $_.GetAttribute('result') -ne 'Success' -or $_.GetAttribute('executed') -ne 'True' }).Count) {
            throw "Pester XML does not match the successful test summary: $Path"
        }
    }
    finally { $reader.Dispose() }
}

function Write-LocalBoxAutomationSuiteSummary {
    param([ValidateSet('Upstream', 'Sovereign')][string]$Name, [hashtable]$Counts)
    foreach ($field in @('Passed', 'Failed', 'Skipped', 'NotRun')) {
        $number = 0L
        if (-not $Counts -or -not [long]::TryParse([string]$Counts[$field], [ref]$number) -or $number -lt 0) {
            throw "Cannot display $Name test results: missing or invalid $field count."
        }
    }
    Write-Host "[LocalBox] $Name tests: $($Counts.Passed) passed, $($Counts.Failed) failed, $($Counts.Skipped) skipped, $($Counts.NotRun) not run."
}

function Invoke-LocalBoxHostedAutomation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][guid]$AksAdminGroupObjectId,
        [string]$ResourceRoot = (Join-Path $PSScriptRoot '../resources'),
        [hashtable]$Package,
        [int]$NestedTimeoutSeconds = 28800,
        [int]$GuestTimeoutSeconds = 43200
    )
    $ErrorActionPreference = 'Stop'
    if ($AksAdminGroupObjectId -eq [guid]::Empty) { throw 'A nonempty event Entra group ID is required.' }
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
    $vmId = "$scope/providers/Microsoft.Compute/virtualMachines/LocalBox-Client"
    $commandPath = "$vmId/runCommands/sovereign-localbox-prepare"
    $commandUri = "$commandPath`?api-version=2024-07-01"
    $temporary = Join-Path ([IO.Path]::GetTempPath()) "localbox-automation-$([guid]::NewGuid())"
    $resultUri = $null
    New-Item -ItemType Directory -Path $temporary | Out-Null
    try {
        if (-not $Package) { $Package = New-LocalBoxAutomationPackage -ResourceRoot $ResourceRoot -Directory $temporary }
        $existing = Invoke-LocalBoxAutomationRequest -Path "$commandUri&`$expand=instanceView" -AllowNotFound
        $active = $existing -and ($existing.properties.provisioningState -in @('Creating', 'Updating') -or
            $existing.properties.instanceView.executionState -in @('Pending', 'Running', 'Unknown') -or
            -not $existing.properties.instanceView.executionState)
        $runId = [guid]::NewGuid().ToString()
        $startedAfter = [datetime]::UtcNow.ToString('o')
        if ($active) {
            $metadata = @{}
            foreach ($item in $existing.properties.parameters) { $metadata[$item.name] = $item.value }
            $existingRunId = [guid]::Empty
            if ($metadata.PackageHash -ne $package.Hash -or $metadata.GroupId -ne $AksAdminGroupObjectId.ToString() -or
                -not [guid]::TryParse([string]$metadata.RunId, [ref]$existingRunId) -or $existingRunId -eq [guid]::Empty -or
                -not $metadata.StartedAfter) {
                throw 'An active LocalBox automation command belongs to different content or group. Inspect it before retrying; it was not replaced.'
            }
            $runId = $metadata.RunId
            $startedAfter = $metadata.StartedAfter
            Write-Host "Resuming monitoring of LocalBox automation $runId."
        }
        else {
            Wait-LocalBoxNestedDeployment -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -TimeoutSeconds $NestedTimeoutSeconds
        }
        $vm = Invoke-LocalBoxAutomationRequest -Path "$vmId`?api-version=2024-07-01"
        $accounts = @(Invoke-LocalBoxAutomationAz @('storage', 'account', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName) |
            Where-Object { $_.name -match '^localbox[a-z0-9]+$' -and $_.name -notlike 'localboxdiag*' })
        if ($accounts.Count -ne 1) { throw 'Expected exactly one LocalBox staging storage account for private automation results.' }
        $account = $accounts[0]
        $container = 'microhack-automation'
        $containerId = "$($account.id)/blobServices/default/containers/$container"
        Invoke-LocalBoxAutomationRequest -Path "$containerId`?api-version=2023-05-01" -Method PUT -Body @{ properties = @{ publicAccess = 'None' } } | Out-Null
        Update-MhhToken | Out-Null
        $token = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/' -ErrorAction Stop
        $jwt = if ($token.Token -is [securestring]) { [System.Net.NetworkCredential]::new('', $token.Token).Password } else { [string]$token.Token }
        $payload = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
        $payload = $payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '=')
        $caller = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json).oid
        $jwt = $null
        foreach ($identity in @($caller, $vm.identity.principalId)) {
            $id = [guid]::Empty
            if (-not [guid]::TryParse([string]$identity, [ref]$id) -or $id -eq [guid]::Empty) { throw 'Unable to resolve automation identities for Blob RBAC.' }
            Update-MhhToken | Out-Null
            $grants = @(Get-AzRoleAssignment -ObjectId $identity -RoleDefinitionName 'Storage Blob Data Contributor' -Scope $containerId -ErrorAction Stop)
            if (-not $grants.Count) {
                New-AzRoleAssignment -ObjectId $identity -RoleDefinitionName 'Storage Blob Data Contributor' -Scope $containerId -ErrorAction Stop | Out-Null
            }
        }
        $resultUri = "$($account.primaryEndpoints.blob)$container/$runId"
        Write-Host "Private LocalBox automation results: $resultUri (Entra authentication required)."
        if (-not $active) {
            $configuration = @{
                RunId = $runId; PackageHash = $package.Hash; SubscriptionId = $SubscriptionId
                ResourceGroupName = $ResourceGroupName; AksAdminGroupObjectId = $AksAdminGroupObjectId.ToString()
                StorageAccountName = $account.name; Container = $container
            }
            $source = New-LocalBoxGuestCommand -Configuration $configuration -Archive $package.Archive
            Invoke-LocalBoxAutomationRequest -Path $commandUri -Method PUT -Body @{
                location = $vm.location
                properties = @{
                    source = @{ script = $source }; asyncExecution = $true; timeoutInSeconds = $GuestTimeoutSeconds
                    parameters = @(
                        @{ name = 'RunId'; value = $runId }, @{ name = 'PackageHash'; value = $package.Hash }
                        @{ name = 'GroupId'; value = $AksAdminGroupObjectId.ToString() }
                        @{ name = 'StartedAfter'; value = $startedAfter }
                    )
                }
            } | Out-Null
        }
        Wait-LocalBoxAutomation -Phase 'guest preparation and tests' -TimeoutSeconds ($GuestTimeoutSeconds + 300) -Probe {
            $command = Invoke-LocalBoxAutomationRequest -Path "$commandUri&`$expand=instanceView"
            $state = $command.properties.instanceView
            if ($command.properties.provisioningState -in @('Failed', 'Canceled')) {
                throw "LocalBox Run Command provisioning failed. Inspect $commandPath."
            }
            $reportedRun = @($command.properties.parameters | Where-Object name -eq 'RunId')
            if ($reportedRun.Count -ne 1 -or $reportedRun[0].value -ne $runId -or -not $state.startTime -or
                [datetimeoffset]$state.startTime -lt [datetimeoffset]$startedAfter) {
                return @{ Ready = $false; Detail = "Waiting for execution $runId to start; ignoring previous instanceView." }
            }
            if ($state.executionState -in @('Failed', 'Canceled', 'TimedOut')) {
                throw "LocalBox guest automation failed. Inspect $commandPath instanceView and $resultUri."
            }
            if ($state.executionState -eq 'Succeeded') {
                if ($null -eq $state.exitCode -or $state.exitCode -ne 0) { throw "LocalBox guest exit code was not zero. Inspect $resultUri." }
                return @{ Ready = $true }
            }
            @{ Ready = $false; Detail = "$($state.executionState); results: $resultUri" }
        } | Out-Null
        foreach ($name in @('status.json', 'health.json', 'health.xml', 'upstream.xml')) {
            Invoke-LocalBoxAutomationAz @('storage', 'blob', 'download', '--account-name', $account.name, '--container-name', $container,
                '--name', "$runId/$name", '--file', (Join-Path $temporary $name), '--auth-mode', 'login', '--overwrite', 'true') | Out-Null
        }
        $result = Get-Content -LiteralPath "$temporary/status.json" -Raw | ConvertFrom-Json -AsHashtable
        Assert-LocalBoxAutomationResult -Result $result -RunId $runId -PackageHash $package.Hash -GroupId $AksAdminGroupObjectId.ToString() `
            -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
        Assert-LocalBoxAutomationXml -Path "$temporary/health.xml" -Expected $result.Sovereign
        Assert-LocalBoxAutomationXml -Path "$temporary/upstream.xml" -Expected $result.Upstream
        Write-Host '[LocalBox] Infrastructure health: PASSED' -ForegroundColor Green
        Write-LocalBoxAutomationSuiteSummary -Name Upstream -Counts $result.Upstream
        Write-LocalBoxAutomationSuiteSummary -Name Sovereign -Counts $result.Sovereign
        Write-Host '[LocalBox] Reference VM: Running / Arc Connected / MDE installation succeeded.'
        Write-Host "[LocalBox] Update assessment: $($result.UpdateAssessment.Status) ($($result.UpdateAssessment.Timestamp))."
        Write-Host "[LocalBox] Private test reports: $resultUri (Entra authentication required)."
        Write-Host '[LocalBox] Scope: shared LocalBox only; subsequent participant deployment stages are not covered by this result.'
        Write-Warning '[LocalBox] Remaining manual checks: Defender cloud reporting and real participant sign-in.'
        @{ RunId = $runId; ResultsUri = $resultUri }
    }
    catch {
        Write-Host '[LocalBox] Readiness gate: FAILED - infrastructure health is NOT VERIFIED.' -ForegroundColor Red
        Write-Host '[LocalBox] No successful end-of-run test summary was verified. See the error and diagnostic reports; do not treat deployment as ready.'
        if ($resultUri) { Write-Host "[LocalBox] Private diagnostic reports: $resultUri (Entra authentication required)." }
        throw
    }
    finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop }
}
