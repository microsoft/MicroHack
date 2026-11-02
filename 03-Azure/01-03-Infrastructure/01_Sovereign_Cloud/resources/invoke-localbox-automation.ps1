#Requires -Version 7.0
[CmdletBinding()]
param([string]$ParametersPath, [switch]$HealthOnly,
    [string]$ManifestPath = 'C:\LocalBox\sovereign-localbox.json')

function Initialize-LocalBoxAutomationEnvironment {
    foreach ($name in @('subscriptionId', 'resourceGroup', 'tenantId', 'autoDeployClusterResource', 'LocalBoxConfigFile', 'LocalBoxDir')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if (-not $value) { throw "LocalBox machine environment is missing $name." }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + $env:PATH
    foreach ($command in @('az', 'kubectl', 'Get-VM')) { Get-Command $command -ErrorAction Stop | Out-Null }
}

function Assert-LocalBoxAutomationTests {
    param($Result)
    if ($Result.TotalCount -le 0 -or $Result.FailedCount -ne 0 -or $Result.SkippedCount -ne 0 -or
        $Result.NotRunCount -ne 0 -or $Result.PassedCount -ne $Result.TotalCount) {
        throw 'Required Pester tests failed, were skipped, or did not run.'
    }
    @{ Passed = $Result.PassedCount; Failed = $Result.FailedCount; Skipped = $Result.SkippedCount; NotRun = $Result.NotRunCount }
}

function Send-LocalBoxAutomationFiles {
    param([hashtable]$Configuration, [string]$Directory)
    foreach ($name in @('status.json', 'health.json', 'health.xml', 'upstream.xml', 'automation.log')) {
        $path = Join-Path $Directory $name
        if (Test-Path -LiteralPath $path) {
            Invoke-LocalBoxAz @('storage', 'blob', 'upload', '--account-name', $Configuration.StorageAccountName,
                '--container-name', $Configuration.Container, '--name', "$($Configuration.RunId)/$name",
                '--file', $path, '--auth-mode', 'login', '--overwrite', 'true') -NoOutput
        }
    }
}

function Write-LocalBoxAutomationStatus {
    param([hashtable]$Configuration, [string]$Directory, [hashtable]$Status)
    Write-Host "LocalBox automation phase: $($Status.Phase)"
    $Status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$Directory/status.json"
    Invoke-LocalBoxAz @('storage', 'blob', 'upload', '--account-name', $Configuration.StorageAccountName,
        '--container-name', $Configuration.Container, '--name', "$($Configuration.RunId)/status.json",
        '--file', "$Directory/status.json", '--auth-mode', 'login', '--overwrite', 'true') -NoOutput
}

function Invoke-LocalBoxAutomationHealth {
    param([hashtable]$Configuration, [string]$Directory, [string]$ResourceRoot, [string]$ManifestPath)
    $nodeConfig = Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile
    $credential = Resolve-LocalBoxNodeCredential -Configuration $nodeConfig
    $global:LASTEXITCODE = 0
    & "$ResourceRoot/test-sovereign-cloud.ps1" -Scope LocalBox -Mode Full -DownloadTests:$false `
        -LocalBoxManifestPath $ManifestPath -LocalBoxKubeconfig "$Directory/aks.kubeconfig" `
        -NodeCredential $credential -TimeoutMinutes 5 -OutputDirectory $Directory
    if ($LASTEXITCODE -ne 0) { throw 'Sovereign Cloud health runner exited unsuccessfully.' }
}

function Invoke-LocalBoxAutomationHealthProcess {
    param([string]$ResourceRoot, [string]$InputPath, [string]$ManifestPath)
    & "$PSHOME/pwsh.exe" -NoProfile -NonInteractive -File "$ResourceRoot/invoke-localbox-automation.ps1" -ParametersPath $InputPath -ManifestPath $ManifestPath -HealthOnly
    if ($LASTEXITCODE -ne 0) { throw 'Sovereign Cloud Full health tests failed. Inspect health.xml and health.json.' }
}

function Invoke-LocalBoxGuestAutomation {
    param([hashtable]$Configuration, [string]$Directory, [string]$ResourceRoot, [string]$InputPath,
        [string]$ManifestPath = 'C:\LocalBox\sovereign-localbox.json')
    $ErrorActionPreference = 'Stop'
    $status = @{
        RunId = $Configuration.RunId; PackageHash = $Configuration.PackageHash
        SubscriptionId = $Configuration.SubscriptionId; ResourceGroupName = $Configuration.ResourceGroupName
        AksAdminGroupObjectId = $Configuration.AksAdminGroupObjectId
        State = 'Running'; StartedAt = [datetime]::UtcNow.ToString('o'); Phase = 'Prerequisites'
        DefenderCloudReporting = 'NotVerified'; ParticipantSignIn = 'NotVerified'
    }
    $lock = [Threading.Mutex]::new($false, 'Global\MicroHackLocalBoxAutomation')
    $locked = $false
    $transcribing = $false
    $previousConfig = $env:AZURE_CONFIG_DIR
    $previousExtensions = $env:AZURE_EXTENSION_DIR
    try {
        $locked = $lock.WaitOne(0)
        if (-not $locked) { throw 'Another hosted LocalBox automation is running.' }
        Start-Transcript -LiteralPath "$Directory/automation.log" -Force | Out-Null
        $transcribing = $true
        if ($Configuration.SubscriptionId -ine $env:subscriptionId -or $Configuration.ResourceGroupName -ine $env:resourceGroup) {
            throw 'Automation scope does not match the LocalBox machine environment.'
        }
        $group = [guid]::Empty
        if (-not [guid]::TryParse($Configuration.AksAdminGroupObjectId, [ref]$group) -or $group -eq [guid]::Empty) {
            throw 'A valid Console event group ID is required; interactive prompting is disabled.'
        }
        $env:AZURE_CONFIG_DIR = Join-Path $Directory '.azure'
        $env:AZURE_EXTENSION_DIR = Join-Path (Split-Path $Directory) 'cliextensions'
        Invoke-LocalBoxAz @('login', '--identity') | Out-Null
        Invoke-LocalBoxAz @('account', 'set', '--subscription', $Configuration.SubscriptionId) | Out-Null
        # Blob role assignments may still be propagating when the guest starts.
        Wait-SovereignCheck -TimeoutSeconds 600 -Check {
            Invoke-LocalBoxAz @('storage', 'blob', 'list', '--account-name', $Configuration.StorageAccountName,
                '--container-name', $Configuration.Container, '--auth-mode', 'login', '--num-results', '1') | Out-Null
        }
        $status.Phase = 'Preparation'
        Write-LocalBoxAutomationStatus $Configuration $Directory $status
        & "$ResourceRoot/prepare-localbox.ps1" -SubscriptionId $Configuration.SubscriptionId -ResourceGroupName $Configuration.ResourceGroupName `
            -AksAdminGroupObjectId $group.ToString() -ManifestPath $ManifestPath -Confirm:$false
        if (-not $?) { throw 'LocalBox preparation failed.' }
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -AsHashtable
        if ($manifest.AksPreparationSkipped -or -not $manifest.ReferenceVm -or $manifest.AksAdminGroupObjectId -ne $group.ToString()) {
            throw 'Preparation manifest does not contain the required AKS, reference VM and event group.'
        }
        $status.Phase = 'ReferenceVmOnboarding'
        Write-LocalBoxAutomationStatus $Configuration $Directory $status
        Wait-SovereignCheck -TimeoutSeconds 7200 -Check {
            $readiness = Get-LocalBoxReferenceVmReadiness $manifest.ReferenceVm.MachineId
            if ($readiness.MdeProvisioningState -eq 'Failed') { throw 'MDE provisioning failed.' }
            if ($readiness.PowerState -ne 'Running' -or $readiness.ArcStatus -ne 'Connected' -or $readiness.MdeProvisioningState -ne 'Succeeded') {
                throw "Reference VM not ready: power=$($readiness.PowerState), Arc=$($readiness.ArcStatus), MDE=$($readiness.MdeProvisioningState)."
            }
        }
        $status.Phase = 'UpdateAssessment'
        Write-LocalBoxAutomationStatus $Configuration $Directory $status
        $installed = @(Invoke-LocalBoxAz @('extension', 'list'))
        if ('connectedmachine' -notin $installed.name) { Invoke-LocalBoxAz @('extension', 'add', '--name', 'connectedmachine') -TimeoutSeconds 900 | Out-Null }
        $assessment = Invoke-LocalBoxAz @('connectedmachine', 'assess-patches', '--ids', $manifest.ReferenceVm.MachineId) -TimeoutSeconds 3600
        if ($assessment.status -ne 'Succeeded' -or -not $assessment.lastModifiedDateTime) {
            throw 'Reference VM Update Manager assessment did not return Succeeded with a timestamp.'
        }
        $status.UpdateAssessment = @{ Status = $assessment.status; Timestamp = $assessment.lastModifiedDateTime; ActivityId = $assessment.assessmentActivityId }
        $status.Phase = 'Pester'
        Write-LocalBoxAutomationStatus $Configuration $Directory $status
        $pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.7.1' -and $_.Version -lt [version]'6.0' }
        if (-not $pester) { Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -ErrorAction Stop }
        Import-Module Pester -MinimumVersion 5.7.1 -MaximumVersion 5.999.999 -ErrorAction Stop
        $upstream = New-PesterConfiguration
        $upstream.Run.Path = @('C:\LocalBox\Tests\common.tests.ps1', 'C:\LocalBox\Tests\azlocal.tests.ps1')
        foreach ($path in $upstream.Run.Path.Value) { if (-not (Test-Path -LiteralPath $path)) { throw "Missing upstream test file: $path" } }
        $upstream.Run.PassThru = $true
        $upstream.TestResult.Enabled = $true
        $upstream.TestResult.OutputFormat = 'NUnitXml'
        $upstream.TestResult.OutputPath = "$Directory/upstream.xml"
        $status.Upstream = Assert-LocalBoxAutomationTests (Invoke-Pester -Configuration $upstream)
        Invoke-LocalBoxAz @('aksarc', 'get-credentials', '--subscription', $Configuration.SubscriptionId,
            '--resource-group', $Configuration.ResourceGroupName, '--name', 'localbox-aks', '--admin',
            '--file', "$Directory/aks.kubeconfig", '--overwrite-existing') -NoOutput
        Invoke-LocalBoxAutomationHealthProcess -ResourceRoot $ResourceRoot -InputPath $InputPath -ManifestPath $ManifestPath
        $health = Get-Content -LiteralPath "$Directory/health.json" -Raw | ConvertFrom-Json -AsHashtable
        if (-not $health.FullReadiness) { throw 'Sovereign Cloud tests did not establish full infrastructure health.' }
        $status.Sovereign = @{ Passed = $health.Passed; Failed = $health.Failed; Skipped = $health.Skipped; NotRun = $health.NotRun }
        $status.State = 'Succeeded'
        $status.Phase = 'Complete'
    }
    catch {
        $status.State = 'Failed'
        $status.Error = $_.Exception.Message
        throw
    }
    finally {
        try {
            if ($transcribing) { Stop-Transcript | Out-Null }
            if ($locked) {
                $status.CompletedAt = [datetime]::UtcNow.ToString('o')
                $status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$Directory/status.json"
                Send-LocalBoxAutomationFiles $Configuration $Directory
            }
        }
        finally {
            $env:AZURE_CONFIG_DIR = $previousConfig
            $env:AZURE_EXTENSION_DIR = $previousExtensions
            if ($locked) {
                foreach ($path in @("$Directory/aks.kubeconfig", "$Directory/.azure")) {
                    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop }
                }
                $lock.ReleaseMutex()
            }
            $lock.Dispose()
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    if (-not $IsWindows) { throw 'Hosted guest automation requires Windows LocalBox-Client.' }
    Initialize-LocalBoxAutomationEnvironment
    $requestedManifestPath = $ManifestPath
    . "$PSScriptRoot/prepare-localbox.ps1"
    . "$PSScriptRoot/test-sovereign-cloud.ps1"
    $automation = Get-Content -LiteralPath $ParametersPath -Raw | ConvertFrom-Json -AsHashtable
    $directory = Split-Path -Parent $ParametersPath
    if ($HealthOnly) {
        Invoke-LocalBoxAutomationHealth -Configuration $automation -Directory $directory -ResourceRoot $PSScriptRoot -ManifestPath $requestedManifestPath
    }
    else {
        Invoke-LocalBoxGuestAutomation -Configuration $automation -Directory $directory -ResourceRoot $PSScriptRoot -InputPath $ParametersPath -ManifestPath $requestedManifestPath
    }
}
