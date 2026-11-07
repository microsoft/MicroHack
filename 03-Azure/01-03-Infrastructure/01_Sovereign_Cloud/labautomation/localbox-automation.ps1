function Invoke-LocalBoxAutomationAz {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$NoOutput)
    Update-MhhToken | Out-Null
    $PSNativeCommandUseErrorActionPreference = $false
    $format = if ($NoOutput) { 'none' } else { 'json' }
    $output = @(& az @Arguments --only-show-errors --output $format 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "LocalBox automation Azure CLI failed: $($output -join "`n")" }
    $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    foreach ($message in $stderr) { Write-Warning "$message" }
    if ($NoOutput) { return }
    $stdout = ($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        try { $stdout | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
        catch {
            $operation = ($Arguments | Select-Object -First 3) -join ' '
            throw "LocalBox automation Azure CLI 'az $operation' returned invalid JSON. Raw output is omitted because it may contain sensitive data."
        }
    }
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

function Test-LocalBoxValidationDownloadTimeout {
    param($ErrorDetail)
    if (-not $ErrorDetail) { return $false }
    if ($ErrorDetail.details) {
        foreach ($child in $ErrorDetail.details) {
            if (-not (Test-LocalBoxValidationDownloadTimeout $child)) { return $false }
        }
        return $true
    }
    return $ErrorDetail.code -eq 'UpdateDeploymentSettingsDataFailed' -and
        $ErrorDetail.message -match 'Name=Download content for deployment' -and
        $ErrorDetail.message -match 'Exception=Timeout of 7200 seconds reached for interface'
}

function Get-LocalBoxValidationRetryState {
    param($Command, [string]$SubscriptionId, [string]$ResourceGroupName)
    $metadata = @{}
    foreach ($parameter in $Command.properties.parameters) {
        if ($metadata.ContainsKey($parameter.name)) { throw 'Duplicate validation recovery metadata. Inspect the existing Run Command; it was not replaced.' }
        $metadata[$parameter.name] = $parameter.value
    }
    $correlation = [guid]::Empty
    $startedAfter = [datetimeoffset]::MinValue
    if ($metadata.RecoveryVersion -ne '1' -or $metadata.SubscriptionId -ne $SubscriptionId -or
        $metadata.ResourceGroupName -ne $ResourceGroupName -or
        -not [guid]::TryParse([string]$metadata.OriginalValidationCorrelationId, [ref]$correlation) -or $correlation -eq [guid]::Empty -or
        -not [datetimeoffset]::TryParse([string]$metadata.StartedAfter, [ref]$startedAfter)) {
        throw 'Unrecognized validation recovery Run Command. Inspect it before retrying; it was not replaced.'
    }
    if ($Command.properties.provisioningState -in @('Failed', 'Canceled')) { throw 'Validation recovery Run Command provisioning failed. Inspect sovereign-localbox-validation-retry.' }
    $state = $Command.properties.instanceView
    if (-not $state.startTime -or [datetimeoffset]$state.startTime -lt $startedAfter) {
        return @{ Ready = $false; OriginalCorrelationId = $metadata.OriginalValidationCorrelationId
            Detail = 'Waiting for validation retry 1/1 to start; ignoring stale instanceView.' }
    }
    if ($state.executionState -in @('Failed', 'Canceled', 'TimedOut')) {
        throw "Automatic validation retry failed or timed out. $(ConvertTo-LocalBoxDiagnosticText $state.error 800) No further automatic retry will be submitted; inspect sovereign-localbox-validation-retry and localcluster-validate."
    }
    if ($state.executionState -eq 'Succeeded') {
        if ($null -eq $state.exitCode -or $state.exitCode -ne 0) { throw 'Validation recovery did not exit successfully.' }
        return @{ Ready = $true; OriginalCorrelationId = $metadata.OriginalValidationCorrelationId }
    }
    @{ Ready = $false; OriginalCorrelationId = $metadata.OriginalValidationCorrelationId
        Detail = "Automatic validation retry 1/1: $($state.executionState). Deployment remains gated on successful validation." }
}

function Get-LocalBoxStartupProgress {
    param([hashtable]$Tracking, [string]$SubscriptionId, [string]$ResourceGroupName, [int]$TimeoutSeconds)
    $vmId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/LocalBox-Client"
    $uri = "$vmId/runCommands/sovereign-localbox-startup-watch?api-version=2024-07-01"
    if (-not $Tracking.Checked) {
        $vm = Invoke-LocalBoxAutomationRequest -Path "$vmId`?api-version=2024-07-01"
        $Tracking.Checked = $true
        if (-not $vm.tags.'microhack-startup-version' -and -not $vm.tags.'microhack-startup-id') {
            $existing = Invoke-LocalBoxAutomationRequest -Path "$uri&`$expand=instanceView" -AllowNotFound
            if ($existing) { throw 'The Client startup identity tags are missing but a startup monitor exists. Organizer review is required; do not rerun bootstrap or assume this is an unprotected legacy VM.' }
            return
        }
        $id = [guid]::Empty
        if ($vm.tags.'microhack-startup-version' -ne '1' -or
            -not [guid]::TryParse([string]$vm.tags.'microhack-startup-id', [ref]$id) -or $id -eq [guid]::Empty) {
            throw 'Invalid VM startup-protection metadata. Startup readiness cannot be verified.'
        }
        $Tracking.Id = $id.ToString()
        $command = Invoke-LocalBoxAutomationRequest -Path "$uri&`$expand=instanceView" -AllowNotFound
        if (-not $command) {
            if ($TimeoutSeconds -le 0) { throw 'No nested-deployment budget remains for startup monitoring.' }
            $startedAfter = [datetime]::UtcNow.ToString('o')
            Invoke-LocalBoxAutomationRequest -Path $uri -Method PUT -Body @{
                location = $vm.location
                properties = @{
                    source = @{ script = Get-Content (Join-Path $PSScriptRoot 'localbox-startup-watch.ps1') -Raw -ErrorAction Stop }
                    asyncExecution = $true; timeoutInSeconds = $TimeoutSeconds
                    parameters = @(
                        @{ name = 'BootstrapId'; value = $Tracking.Id }
                        @{ name = 'SubscriptionId'; value = $SubscriptionId }
                        @{ name = 'ResourceGroupName'; value = $ResourceGroupName }
                        @{ name = 'StartedAfter'; value = $startedAfter }
                        @{ name = 'TimeoutSeconds'; value = [string]$TimeoutSeconds }
                    )
                }
            } | Out-Null
        }
    }
    if (-not $Tracking.Id) { return }
    $command = Invoke-LocalBoxAutomationRequest -Path "$uri&`$expand=instanceView"
    $metadata = @{}
    foreach ($parameter in $command.properties.parameters) {
        if ($metadata.ContainsKey($parameter.name)) { throw 'Duplicate startup-monitor metadata.' }
        $metadata[$parameter.name] = $parameter.value
    }
    $started = [datetimeoffset]::MinValue
    if ($metadata.BootstrapId -ne $Tracking.Id -or $metadata.SubscriptionId -ne $SubscriptionId -or
        $metadata.ResourceGroupName -ne $ResourceGroupName -or
        -not [datetimeoffset]::TryParse([string]$metadata.StartedAfter, [ref]$started)) {
        throw 'An existing startup monitor does not match this VM deployment; it was not replaced.'
    }
    if ($command.properties.provisioningState -in @('Failed', 'Canceled')) { throw 'The LocalBox startup monitor could not be provisioned.' }
    $instance = $command.properties.instanceView
    if (-not $instance.startTime -or [datetimeoffset]$instance.startTime -lt $started -or
        $instance.executionState -notin @('Succeeded', 'Failed', 'Canceled', 'TimedOut')) { return }
    $matches = [regex]::Matches([string]$instance.output, '(?m)^LOCALBOX_STARTUP_REPORT:(.+)\r?$')
    if ($matches.Count -ne 1) { throw 'LocalBox startup monitoring stopped without a verified report. Inspect sovereign-localbox-startup-watch.' }
    try { $report = $matches[0].Groups[1].Value | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
    catch { throw 'Invalid LocalBox startup report. Inspect sovereign-localbox-startup-watch.' }
    if ($report.BootstrapId -ne $Tracking.Id -or $report.SubscriptionId -ne $SubscriptionId -or $report.ResourceGroupName -ne $ResourceGroupName) {
        throw 'LocalBox startup report identity mismatch; no report details were accepted.'
    }
    if ($report.State -eq 'Failed') {
        throw "Upstream LocalBox startup failed during $(ConvertTo-LocalBoxDiagnosticText $report.Phase 80) [$(ConvertTo-LocalBoxDiagnosticText $report.Code 80)]: $(ConvertTo-LocalBoxDiagnosticText $report.Message). Azure Local validation/deployment has not started; no infrastructure readiness is claimed."
    }
    if ($report.State -ne 'Succeeded' -or $instance.executionState -ne 'Succeeded' -or $null -eq $instance.exitCode -or $instance.exitCode -ne 0) {
        throw 'The LocalBox startup monitor did not finish successfully; readiness remains unverified.'
    }
}

function Wait-LocalBoxNestedDeployment {
    param([string]$SubscriptionId, [string]$ResourceGroupName, [int]$TimeoutSeconds = 28800)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    $retry = @{ Checked = $false; Command = $null; OriginalCorrelationId = $null }
    $startup = @{ Checked = $false; Id = $null }
    $vmId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/LocalBox-Client"
    $retryUri = "$vmId/runCommands/sovereign-localbox-validation-retry?api-version=2024-07-01"
    Wait-LocalBoxAutomation -Phase 'nested deployment' -TimeoutSeconds $TimeoutSeconds -Probe {
        $deployments = @(Invoke-LocalBoxAutomationAz @('deployment', 'group', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName))
        $clusterDeployment = @($deployments | Where-Object name -eq 'localcluster-deploy')
        $validation = @($deployments | Where-Object name -eq 'localcluster-validate')
        if ($clusterDeployment.Count -gt 1 -or $validation.Count -gt 1) { throw 'Ambiguous nested deployment records.' }
        if (-not $clusterDeployment.Count -and -not $validation.Count) {
            $remaining = [int][math]::Max(0, [math]::Floor(($deadline - [datetime]::UtcNow).TotalSeconds))
            Get-LocalBoxStartupProgress -Tracking $startup -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -TimeoutSeconds $remaining
        }
        if ($clusterDeployment.Count -eq 1 -and $clusterDeployment[0].properties.provisioningState -in @('Failed', 'Canceled')) {
            throw 'Nested deployment localcluster-deploy failed. Inspect its deployment operations and Client logs.'
        }
        if (-not $retry.Checked -and ($clusterDeployment.Count -ne 1 -or $clusterDeployment[0].properties.provisioningState -ne 'Succeeded')) {
            $retry.Command = Invoke-LocalBoxAutomationRequest -Path "$retryUri&`$expand=instanceView" -AllowNotFound
            $retry.Checked = $true
        }
        if ($retry.Command) {
            $retry.Command = Invoke-LocalBoxAutomationRequest -Path "$retryUri&`$expand=instanceView"
            $retryState = Get-LocalBoxValidationRetryState -Command $retry.Command -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
            if ($retry.OriginalCorrelationId -and $retry.OriginalCorrelationId -ne $retryState.OriginalCorrelationId) {
                throw 'Validation recovery correlation changed while monitoring; the command was not replaced.'
            }
            $retry.OriginalCorrelationId = $retryState.OriginalCorrelationId
            if (-not $retryState.Ready) { return $retryState }
            if ($validation.Count -eq 1 -and $validation[0].properties.correlationId -eq $retryState.OriginalCorrelationId) {
                return @{ Ready = $false; Detail = 'Validation retry completed; waiting for updated ARM deployment records.' }
            }
        }
        if ($validation.Count -eq 1 -and $validation[0].properties.provisioningState -in @('Failed', 'Canceled')) {
            if ($retry.Command -or $validation[0].properties.provisioningState -eq 'Canceled' -or $clusterDeployment.Count) {
                throw 'Nested deployment localcluster-validate failed or was canceled. No further automatic validation retry is allowed.'
            }
            $operations = @(Invoke-LocalBoxAutomationAz @('deployment', 'operation', 'group', 'list', '--subscription', $SubscriptionId,
                '--resource-group', $ResourceGroupName, '--name', 'localcluster-validate'))
            $failed = @($operations | Where-Object { $_.properties.provisioningState -eq 'Failed' })
            if ($failed.Count -ne 1 -or $failed[0].properties.targetResource.resourceType -ine 'Microsoft.AzureStackHCI/clusters/deploymentSettings') {
                throw 'Nested deployment localcluster-validate failed outside the recognized content-download operation. Manual investigation is required.'
            }
            $status = $failed[0].properties.statusMessage
            if ($status -is [string]) {
                try { $status = $status | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
                catch { throw 'Unable to parse validation operation details; automatic retry is not safe.' }
            }
            if (-not (Test-LocalBoxValidationDownloadTimeout $status.error)) {
                throw 'Nested deployment localcluster-validate failed with a non-retryable validation error. Inspect its deployment operations.'
            }
            $correlation = [guid]::Empty
            if (-not [guid]::TryParse([string]$validation[0].properties.correlationId, [ref]$correlation) -or $correlation -eq [guid]::Empty) {
                throw 'Cannot correlate the failed validation; automatic retry was not submitted.'
            }
            $remaining = [int][math]::Floor(($deadline - [datetime]::UtcNow).TotalSeconds)
            if ($remaining -le 120) { throw 'Insufficient nested-deployment time remaining for the validation retry delay.' }
            $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'localbox-validation-retry.ps1') -Raw -ErrorAction Stop
            $vm = Invoke-LocalBoxAutomationRequest -Path "$vmId`?api-version=2024-07-01"
            Write-Warning '[LocalBox] Azure Local validation hit the 7200-second content-download timeout. Scheduling automatic retry 1/1 after 120 seconds; the existing nested wait deadline is unchanged.'
            Invoke-LocalBoxAutomationRequest -Path $retryUri -Method PUT -Body @{
                location = $vm.location
                properties = @{
                    source = @{ script = $source }; asyncExecution = $true; timeoutInSeconds = $remaining
                    parameters = @(
                        @{ name = 'SubscriptionId'; value = $SubscriptionId }
                        @{ name = 'ResourceGroupName'; value = $ResourceGroupName }
                        @{ name = 'OriginalValidationCorrelationId'; value = $correlation.ToString() }
                        @{ name = 'StartedAfter'; value = [datetime]::UtcNow.ToString('o') }
                        @{ name = 'RecoveryVersion'; value = '1' }
                    )
                }
            } | Out-Null
            $retry.Command = @{ properties = @{} }
            $retry.OriginalCorrelationId = $correlation.ToString()
            return @{ Ready = $false; Detail = 'Automatic validation retry 1/1 submitted. Credentials and existing ARM files remain on LocalBox-Client.' }
        }
        if ($clusterDeployment.Count -ne 1 -or $clusterDeployment[0].properties.provisioningState -ne 'Succeeded') {
            $detail = if (-not $validation.Count -and -not $clusterDeployment.Count) {
                'Azure Local validation/deployment records are absent; waiting for upstream Client startup.'
            } else { 'Waiting for localcluster-deploy to succeed.' }
            return @{ Ready = $false; Detail = $detail }
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

function Assert-LocalBoxAutomationReportIdentity {
    param([hashtable]$Result, [string]$RunId, [string]$PackageHash, [string]$GroupId, [string]$SubscriptionId, [string]$ResourceGroupName)
    if (-not $Result -or $Result.RunId -ne $RunId -or $Result.PackageHash -ne $PackageHash -or
        $Result.AksAdminGroupObjectId -ne $GroupId -or $Result.SubscriptionId -ne $SubscriptionId -or
        $Result.ResourceGroupName -ne $ResourceGroupName) {
        throw 'LocalBox diagnostic report is missing, stale or belongs to a different run, package, group or Azure scope.'
    }
}

function Assert-LocalBoxAutomationResult {
    param([hashtable]$Result, [string]$RunId, [string]$PackageHash, [string]$GroupId, [string]$SubscriptionId, [string]$ResourceGroupName)
    Assert-LocalBoxAutomationReportIdentity @PSBoundParameters
    if ($Result.State -ne 'Succeeded') {
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

function Read-LocalBoxAutomationXml {
    param([string]$Path)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.MaxCharactersInDocument = 10485760
    $reader = [Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
        if ($document.DocumentElement.get_LocalName() -ne 'test-results') { throw 'Expected a Pester NUnit report.' }
        return ,$document
    }
    finally { $reader.Dispose() }
}

function Assert-LocalBoxAutomationXml {
    param([string]$Path, [hashtable]$Expected)
    $document = Read-LocalBoxAutomationXml -Path $Path
    $cases = @($document.SelectNodes('//test-case'))
    if ($cases.Count -ne $Expected.Passed -or
        @($cases | Where-Object { $_.GetAttribute('result') -ne 'Success' -or $_.GetAttribute('executed') -ne 'True' }).Count) {
        throw "Pester XML does not match the successful test summary: $Path"
    }
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

function ConvertTo-LocalBoxDiagnosticText {
    param([string]$Text, [ValidateRange(40, [int]::MaxValue)][int]$MaximumLength = 800)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '(not reported)' }
    $text = [regex]::Replace($Text, '\x1b\[[0-?]*[ -/]*[@-~]', '')
    $text = [regex]::Replace($text, '(?s)-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----', '[REDACTED PRIVATE KEY]')
    $text = [regex]::Replace($text, '(?i)\bBearer\s+[^\s"''<>]+', 'Bearer [REDACTED]')
    $text = [regex]::Replace($text, '\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '[REDACTED JWT]')
    $text = [regex]::Replace($text, '(?i)(https?://)[^/\s@]+@', '$1[REDACTED]@')
    $text = [regex]::Replace($text, '(?i)(https?://[^\s?]+)\?[^\s"''<>]+', '$1?[REDACTED QUERY]')
    $text = [regex]::Replace($text,
        '(?i)(["'']?[\w-]*(?:password|secret|token|accountkey|connectionstring|authorization)["'']?\s*[:=]\s*)(?:"[^"]*"|''[^'']*''|[^\s,;]+)', '$1[REDACTED]')
    $text = [regex]::Replace($text,
        '(?i)(--?[\w-]*(?:password|secret|token|account-key|connection-string)\s+)(?:"[^"]*"|''[^'']*''|\S+)', '$1[REDACTED]')
    $text = [regex]::Replace($text, '[\x00-\x1f\x7f-\x9f]', ' ')
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt $MaximumLength) {
        $suffix = ' ... [truncated; see private report]'
        return $text.Substring(0, $MaximumLength - $suffix.Length) + $suffix
    }
    $text
}

function Get-LocalBoxAutomationFailureSuite {
    param([string]$Path)
    $document = Read-LocalBoxAutomationXml -Path $Path
    $cases = @($document.SelectNodes('//test-case'))
    if (-not $cases.Count) { throw 'The test report contains no test cases.' }
    $counts = @{ Passed = 0; Failed = 0; Skipped = 0; NotRun = 0 }
    $failures = @(
        foreach ($case in $cases) {
            switch ($case.GetAttribute('result')) {
                'Success' {
                    if ($case.GetAttribute('executed') -ne 'True') { throw 'An unexecuted test claims success.' }
                    $counts.Passed++
                }
                { $_ -in @('Failure', 'Error') } {
                    $counts.Failed++
                    $message = $case.SelectSingleNode('failure/message')
                    @{ Name = $case.GetAttribute('name'); Message = if ($message) { $message.InnerText } else { 'No failure message recorded.' } }
                }
                { $_ -in @('Ignored', 'Skipped') } { $counts.Skipped++ }
                { $_ -in @('Inconclusive', 'NotRunnable', 'Invalid') } { $counts.NotRun++ }
                default { throw 'The test report contains an unsupported result value.' }
            }
        }
    )
    @{ Counts = $counts; Failures = $failures }
}

function Write-LocalBoxAutomationFailureReport {
    param([string]$Directory, [string]$RunId, [string]$PackageHash, [string]$GroupId,
        [string]$SubscriptionId, [string]$ResourceGroupName)
    try {
        $status = Get-Content -LiteralPath "$Directory/status.json" -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        Assert-LocalBoxAutomationReportIdentity -Result $status -RunId $RunId -PackageHash $PackageHash -GroupId $GroupId `
            -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
    }
    catch {
        Write-Warning '[LocalBox] Detailed report unavailable or unverified: status.json could not be read and correlated. No test counts from these files will be displayed.'
        return
    }
    Write-Host "[LocalBox] Last guest phase: $(ConvertTo-LocalBoxDiagnosticText $status.Phase 120); reported state: $(ConvertTo-LocalBoxDiagnosticText $status.State 80)."
    if ($status.Error) { Write-Host "[LocalBox] Guest error: $(ConvertTo-LocalBoxDiagnosticText $status.Error)" }
    foreach ($suite in @(@{ Name = 'Upstream'; File = 'upstream.xml' }, @{ Name = 'Sovereign'; File = 'health.xml' })) {
        try {
            $report = Get-LocalBoxAutomationFailureSuite -Path (Join-Path $Directory $suite.File)
            Write-LocalBoxAutomationSuiteSummary -Name $suite.Name -Counts $report.Counts
            foreach ($failure in @($report.Failures | Select-Object -First 10)) {
                Write-Host "[LocalBox] FAILED TEST ($($suite.Name)): $(ConvertTo-LocalBoxDiagnosticText $failure.Name 300)"
                Write-Host "[LocalBox] Reason: $(ConvertTo-LocalBoxDiagnosticText $failure.Message)"
            }
            if ($report.Failures.Count -gt 10) { Write-Host "[LocalBox] $($report.Failures.Count - 10) additional failed tests are listed in $($suite.File)." }
            if (@($report.Failures | Where-Object {
                $_.Message -match 'ipaddresspools\.metallb\.io' -and $_.Message -match 'not found|NotFound'
            }).Count) {
                Write-Host '[LocalBox] Suggested check: compare the Azure-managed MetalLB pool with its Kubernetes IPAddressPool and L2Advertisement. Azure Succeeded does not prove these objects exist; have an organizer reconcile the existing configuration rather than rebuild LocalBox.'
            }
        }
        catch { Write-Warning "[LocalBox] $($suite.Name) test results unavailable or invalid ($($suite.File)); this suite is NOT VERIFIED." }
    }
    Write-Host '[LocalBox] These diagnostic counts do not establish overall readiness. Fix the reported failure, then retry the existing Console event; downstream stages remain blocked.'
}

function Write-LocalBoxAutomationFailureDiagnostics {
    param([string]$Directory, [string]$StorageAccountName, [string]$Container, [string]$RunId,
        [string]$PackageHash, [string]$GroupId, [string]$SubscriptionId, [string]$ResourceGroupName, $InstanceView)
    $exitCode = if ($null -eq $InstanceView.exitCode) { 'not reported' } else { ConvertTo-LocalBoxDiagnosticText ([string]$InstanceView.exitCode) 40 }
    Write-Host "[LocalBox] Run: $RunId; execution: $(ConvertTo-LocalBoxDiagnosticText $InstanceView.executionState 80); exit code: $exitCode."
    if ($InstanceView.error) { Write-Host "[LocalBox] Execution error: $(ConvertTo-LocalBoxDiagnosticText $InstanceView.error)" }
    foreach ($name in @('status.json', 'upstream.xml', 'health.xml')) {
        $path = Join-Path $Directory $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
        try {
            Invoke-LocalBoxAutomationAz @('storage', 'blob', 'download', '--account-name', $StorageAccountName, '--container-name', $Container,
                '--name', "$RunId/$name", '--file', $path, '--auth-mode', 'login', '--overwrite', 'true', '--no-progress') -NoOutput
        }
        catch {
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
            Write-Warning "[LocalBox] Could not retrieve $name for this run: $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 400)"
        }
    }
    Write-LocalBoxAutomationFailureReport -Directory $Directory -RunId $RunId -PackageHash $PackageHash -GroupId $GroupId `
        -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
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
    $failureEvidence = @{ InstanceView = $null }
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
                $failureEvidence.InstanceView = $state
                throw "LocalBox guest automation failed. Inspect $commandPath instanceView and $resultUri."
            }
            if ($state.executionState -eq 'Succeeded') {
                $failureEvidence.InstanceView = $state
                if ($null -eq $state.exitCode -or $state.exitCode -ne 0) { throw "LocalBox guest exit code was not zero. Inspect $resultUri." }
                return @{ Ready = $true }
            }
            @{ Ready = $false; Detail = "$($state.executionState); results: $resultUri" }
        } | Out-Null
        foreach ($name in @('status.json', 'health.json', 'health.xml', 'upstream.xml')) {
            Invoke-LocalBoxAutomationAz @('storage', 'blob', 'download', '--account-name', $account.name, '--container-name', $container,
                '--name', "$runId/$name", '--file', (Join-Path $temporary $name), '--auth-mode', 'login', '--overwrite', 'true',
                '--no-progress') -NoOutput
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
        $primaryFailure = $_
        Write-Host '[LocalBox] Readiness gate: FAILED - infrastructure health is NOT VERIFIED.' -ForegroundColor Red
        Write-Host '[LocalBox] No successful end-of-run test summary was verified. See the error and diagnostic reports; do not treat deployment as ready.'
        if ($failureEvidence.InstanceView -and $resultUri) {
            try {
                Write-LocalBoxAutomationFailureDiagnostics -Directory $temporary -StorageAccountName $account.name -Container $container `
                    -RunId $runId -PackageHash $package.Hash -GroupId $AksAdminGroupObjectId.ToString() `
                    -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -InstanceView $failureEvidence.InstanceView
            }
            catch { Write-Warning "[LocalBox] Failure diagnostics could not be completed: $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 400)" }
        }
        if ($resultUri) { Write-Host "[LocalBox] Private diagnostic reports: $resultUri (Entra authentication required)." }
        throw $primaryFailure
    }
    finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop }
}
