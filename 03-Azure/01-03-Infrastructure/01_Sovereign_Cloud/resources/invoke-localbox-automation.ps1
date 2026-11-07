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
    $env:PATH = $env:PATH + ';' + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    foreach ($command in @('az', 'Get-VM')) { Get-Command $command -ErrorAction Stop | Out-Null }
}

function Get-LocalBoxKubectlClientVersion {
    param([string]$Path)
    $output = & $Path version --client --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "kubectl client version check failed: $($output -join "`n")" }
    $client = ($output -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($client.clientVersion.gitVersion -notmatch '^v?(?<Version>\d+\.\d+\.\d+)(?:[-+][0-9A-Za-z.-]+)?$') {
        throw 'kubectl did not report a valid client version.'
    }
    [version]$Matches.Version
}

function Initialize-LocalBoxAutomationKubectl {
    param([string]$InstanceId, [string]$Directory)
    $instance = Get-LocalBoxResource $InstanceId
    if ($instance.properties.kubernetesVersion -notmatch '^v?(?<Version>\d+\.\d+\.\d+)(?:[-+][0-9A-Za-z.-]+)?$') {
        throw 'AKS did not report a valid Kubernetes version for kubectl installation.'
    }
    $version = [version]$Matches.Version
    $existing = Get-Command kubectl -CommandType Application -ErrorAction SilentlyContinue
    if ($existing) {
        $client = Get-LocalBoxKubectlClientVersion -Path $existing.Path
        if ($client.Major -eq $version.Major -and $client.Minor -eq $version.Minor) { return $existing.Path }
    }
    $tools = Join-Path (Split-Path -Parent $Directory) "tools/kubectl-$version"
    New-Item -ItemType Directory -Path $tools -Force -ErrorAction Stop | Out-Null
    $kubectl = Join-Path $tools 'kubectl.exe'
    if (-not (Test-Path -LiteralPath $kubectl -PathType Leaf)) {
        Write-Host "Installing kubectl $version for unattended SYSTEM health checks in $tools."
        Invoke-LocalBoxAz @('aks', 'install-cli', '--client-version', $version.ToString(),
            '--install-location', $kubectl, '--kubelogin-install-location', (Join-Path $tools 'kubelogin.exe')) -TimeoutSeconds 900 -NoOutput
    }
    if ((Get-LocalBoxKubectlClientVersion -Path $kubectl) -ne $version) {
        throw "The private kubectl installation does not match requested version $version."
    }
    $env:PATH = $tools + [IO.Path]::PathSeparator + $env:PATH
    return $kubectl
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
    foreach ($name in @('status.json', 'health.json', 'health.xml', 'upstream.xml', 'automation.log', 'metallb-recovery.json')) {
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
    Get-Command kubectl -CommandType Application -ErrorAction Stop | Out-Null
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

function Test-LocalBoxAutomationMetalLbRuntime {
    param([string]$Kubeconfig, [hashtable]$Plan)
    $pools = Invoke-SovereignKubectl $Kubeconfig @('get', 'ipaddresspools.metallb.io', '--all-namespaces')
    $advertisements = Invoke-SovereignKubectl $Kubeconfig @('get', 'l2advertisements.metallb.io', '--all-namespaces')
    foreach ($list in @($pools, $advertisements)) {
        if ($list -isnot [System.Collections.IDictionary] -or $list.items -isnot [System.Collections.IList]) {
            throw 'Invalid MetalLB Kubernetes list response; missing objects cannot be determined safely.'
        }
    }
    $expected = @($pools.items | Where-Object { $_.metadata.name -eq 'aks-pool' -and $_.metadata.namespace -eq 'kube-system' })
    if ($pools.items.Count -ne $expected.Count -or $expected.Count -gt 1) {
        throw 'Conflicting MetalLB IPAddressPool objects exist. Organizer review is required; no automatic repair is allowed.'
    }
    if ($expected.Count) {
        $pool = $expected[0]
        Assert-LocalBoxProperties $pool.spec @{ addresses = $Plan.PoolExpected.properties.addresses }
        if ($pool.spec.autoAssign -eq $false -or $pool.metadata.deletionTimestamp) {
            throw 'The MetalLB pool disables auto-assignment or is being deleted; no automatic repair is allowed.'
        }
    }
    $matching = @($advertisements.items | Where-Object {
        $_.metadata.namespace -eq 'kube-system' -and $_.spec.ipAddressPools -contains 'aks-pool'
    })
    foreach ($advertisement in @($advertisements.items | Where-Object {
        $_.metadata.namespace -eq 'kube-system' -and
        ($_.metadata.name -eq 'aks-pool' -or $_.spec.ipAddressPools -contains 'aks-pool')
    })) {
        Assert-LocalBoxProperties $advertisement.spec @{ ipAddressPools = @('aks-pool') }
        foreach ($key in @('interfaces', 'nodeSelectors', 'ipAddressPoolSelectors')) {
            if ($advertisement.spec[$key].Count -gt 0) {
                throw "The MetalLB L2Advertisement has custom $key configured; organizer review is required."
            }
        }
    }
    if (@($matching | Where-Object { $_.metadata.deletionTimestamp }).Count) {
        throw 'A MetalLB L2Advertisement is being deleted; no automatic repair is allowed.'
    }
    return ($expected.Count -eq 1 -and $matching.Count -gt 0)
}

function Sync-LocalBoxAutomationMetalLbRuntime {
    param(
        [hashtable]$Manifest, [hashtable]$Configuration, [string]$Kubeconfig,
        [Parameter(Mandatory)][string]$StatePath,
        [ValidateRange(0, 600)][int]$GraceSeconds = 120,
        [ValidateRange(0, 600)][int]$RecoverySeconds = 300
    )
    $ErrorActionPreference = 'Stop'
    $aksId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks"
    if (-not $env:subscriptionId -or -not $env:resourceGroup -or $Manifest.AksId -ine $aksId -or
        $Manifest.SubscriptionId -ine $env:subscriptionId -or $Manifest.ResourceGroupName -ine $env:resourceGroup) {
        throw 'MetalLB recovery manifest does not match this hosted LocalBox scope.'
    }
    $plan = Get-LocalBoxMetalLbPlan -Configuration $Configuration -ClusterId $aksId
    Assert-LocalBoxProperties $Manifest.MetalLb $plan
    $deadline = [datetime]::UtcNow.AddSeconds($GraceSeconds)
    do {
        if (Test-LocalBoxAutomationMetalLbRuntime -Kubeconfig $Kubeconfig -Plan $plan) {
            Write-Host 'MetalLB runtime objects are verified; no recovery PUT is needed.'
            return
        }
        if ([datetime]::UtcNow -ge $deadline) { break }
        Write-Host 'MetalLB runtime pool or L2 advertisement is missing; waiting for initial reconciliation.'
        Start-Sleep -Seconds ([math]::Min(15, [math]::Max(0, ($deadline - [datetime]::UtcNow).TotalSeconds)))
    } while ($true)
    if (Test-Path -LiteralPath $StatePath) {
        throw 'MetalLB runtime objects remain missing and automatic recovery was already recorded for this run. No second PUT will be submitted; inspect the private metallb-recovery.json report.'
    }
    $extension = Get-LocalBoxResource $plan.ExtensionId -TimeoutSeconds 30
    Assert-LocalBoxProperties $extension @{ properties = @{ provisioningState = 'Succeeded'; extensionType = 'microsoft.arcnetworking' } }
    $url = "https://management.azure.com$aksId/providers/Microsoft.KubernetesRuntime/loadBalancers?api-version=2024-08-01"
    $pools = @(Get-LocalBoxArmCollection $url -TimeoutSeconds 30)
    if ($pools.Count -ne 1 -or $pools[0].id -ine $plan.PoolId) {
        throw 'The existing Azure-managed MetalLB pool is missing or additional pools exist; no automatic repair is allowed.'
    }
    $pool = $pools[0]
    Assert-LocalBoxProperties $pool $plan.PoolExpected
    if ($pool.properties.provisioningState -ne 'Succeeded') {
        throw "The Azure-managed MetalLB pool is $($pool.properties.provisioningState), not Succeeded; no automatic repair is allowed."
    }
    foreach ($key in @('bgpPeers', 'communities', 'serviceSelector')) {
        if ($pool.properties[$key].Count -gt 0) {
            throw "The Azure-managed MetalLB pool has $key configured; organizer review is required."
        }
    }
    if (Test-LocalBoxAutomationMetalLbRuntime -Kubeconfig $Kubeconfig -Plan $plan) {
        Write-Host 'MetalLB runtime objects converged before recovery; no PUT was submitted.'
        return
    }
    $body = @{ properties = @{
        addresses = $pool.properties.addresses; advertiseMode = $pool.properties.advertiseMode
        bgpPeers = $pool.properties.bgpPeers; communities = $pool.properties.communities
        serviceSelector = $pool.properties.serviceSelector
    } } | ConvertTo-Json -Depth 10 -Compress
    $record = @{ PoolId = $plan.PoolId; Attempt = 1; State = 'Attempted'; StartedAt = [datetime]::UtcNow.ToString('o') }
    # Record before submitting: a timeout or guest restart must not cause a second PUT.
    New-Item -Path $StatePath -ItemType File -Value ($record | ConvertTo-Json) -ErrorAction Stop | Out-Null
    Write-Host 'MetalLB automatic recovery 1/1: reapplying the unchanged Azure-managed ARP pool; no resources will be deleted.'
    Invoke-LocalBoxAz @('rest', '--method', 'put', '--url',
        "https://management.azure.com$($plan.PoolId)?api-version=2024-08-01", '--body', $body) -TimeoutSeconds 120 -NoOutput
    $deadline = [datetime]::UtcNow.AddSeconds($RecoverySeconds)
    do {
        $actual = Get-LocalBoxResource $plan.PoolId -TimeoutSeconds 30
        Assert-LocalBoxProperties $actual $plan.PoolExpected
        $state = $actual.properties.provisioningState
        if ([string]::IsNullOrWhiteSpace($state) -or $state -in @('Failed', 'Canceled', 'Deleting')) {
            throw "MetalLB automatic recovery failed: Azure provisioning state is '$state'. No further automatic attempt is allowed."
        }
        $ready = Test-LocalBoxAutomationMetalLbRuntime -Kubeconfig $Kubeconfig -Plan $plan
        if ($state -eq 'Succeeded' -and $ready) {
            $record.State = 'Succeeded'
            $record.CompletedAt = [datetime]::UtcNow.ToString('o')
            $record | ConvertTo-Json | Set-Content -LiteralPath $StatePath -ErrorAction Stop
            Write-Host 'MetalLB automatic recovery succeeded: Kubernetes pool and L2 advertisement verified. Full health tests must still pass.'
            return
        }
        if ([datetime]::UtcNow -ge $deadline) {
            throw "MetalLB automatic recovery exhausted after one PUT: Azure state=$state; Kubernetes pool/L2 advertisement ready=$ready. Inspect the Arc networking controller and private reports; readiness remains unverified."
        }
        Write-Host "Waiting for MetalLB recovery: Azure state=$state; Kubernetes pool/L2 advertisement ready=$ready."
        Start-Sleep -Seconds ([math]::Min(15, [math]::Max(0, ($deadline - [datetime]::UtcNow).TotalSeconds)))
    } while ($true)
}

function Invoke-LocalBoxAutomationRoutedHealth {
    param([string]$ResourceRoot, [string]$InputPath, [string]$ManifestPath, [string]$Kubeconfig, [switch]$RecoverMetalLb)
    $ErrorActionPreference = 'Stop'
    $config = Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile
    foreach ($key in @('AKSControlPlaneIP', 'PhysicalHostInternalIP', 'SDNLABRoute')) {
        $address = $null
        if (-not [Net.IPAddress]::TryParse([string]$config[$key], [ref]$address) -or
            $address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or $address.ToString() -ne $config[$key]) {
            throw "LocalBox configuration requires a canonical IPv4 address for $key."
        }
    }
    $server = & kubectl --kubeconfig $Kubeconfig config view --minify -o 'jsonpath={.clusters[0].cluster.server}'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the AKS API endpoint from the private kubeconfig.' }
    $endpoint = $null
    if (-not [uri]::TryCreate([string]$server, [UriKind]::Absolute, [ref]$endpoint) -or
        $endpoint.Scheme -ne 'https' -or $endpoint.Host -ne $config.AKSControlPlaneIP) {
        throw 'The kubeconfig API endpoint does not match the configured LocalBox AKS control-plane IP.'
    }
    if ([string]::IsNullOrWhiteSpace($config.InternalSwitch)) { throw 'LocalBox configuration is missing InternalSwitch.' }
    $interfaces = @(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "vEthernet ($($config.InternalSwitch))" -ErrorAction Stop |
        Where-Object IPAddress -eq $config.PhysicalHostInternalIP)
    if ($interfaces.Count -ne 1 -or $interfaces[0].PrefixLength -lt 1 -or $interfaces[0].PrefixLength -gt 30) {
        throw 'Cannot uniquely resolve the configured LocalBox internal interface and subnet.'
    }
    $interface = $interfaces[0]
    $size = [math]::Pow(2, 32 - $interface.PrefixLength)
    $hostNumber = ConvertTo-LocalBoxIPv4Number $config.PhysicalHostInternalIP
    $gatewayNumber = ConvertTo-LocalBoxIPv4Number $config.SDNLABRoute
    if ([math]::Floor($hostNumber / $size) -ne [math]::Floor($gatewayNumber / $size) -or
        $gatewayNumber -eq $hostNumber -or $gatewayNumber % $size -in @(0, ($size - 1))) {
        throw 'The configured internal gateway is not a usable peer in the Client internal subnet.'
    }
    $prefix = "$($endpoint.Host)/32"
    $existing = @(Get-NetRoute -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction Stop |
        Where-Object DestinationPrefix -eq $prefix)
    if ($existing.Count -gt 1 -or ($existing.Count -eq 1 -and
        ($existing[0].InterfaceIndex -ne $interface.InterfaceIndex -or $existing[0].NextHop -ne $config.SDNLABRoute))) {
        throw "An ambiguous or conflicting route already exists for $prefix; it will not be replaced."
    }
    $ownedRoute = $null
    $healthError = $null
    try {
        if (-not $existing.Count) {
            Write-Host "Temporarily routing AKS API $prefix through $($config.SDNLABRoute) on $($interface.InterfaceAlias)."
            $ownedRoute = New-NetRoute -DestinationPrefix $prefix -InterfaceIndex $interface.InterfaceIndex `
                -NextHop $config.SDNLABRoute -PolicyStore ActiveStore -ErrorAction Stop
        }
        else { Write-Host "Reusing the existing AKS API route for $prefix without modifying it." }
        if ($RecoverMetalLb) {
            $manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
            Sync-LocalBoxAutomationMetalLbRuntime -Manifest $manifest -Configuration $config -Kubeconfig $Kubeconfig `
                -StatePath (Join-Path (Split-Path -Parent $InputPath) 'metallb-recovery.json')
        }
        Invoke-LocalBoxAutomationHealthProcess -ResourceRoot $ResourceRoot -InputPath $InputPath -ManifestPath $ManifestPath
    }
    catch { $healthError = $_.Exception.Message; throw }
    finally {
        if ($ownedRoute) {
            try {
                $ownedRoute | Remove-NetRoute -Confirm:$false -ErrorAction Stop
                $remaining = @(Get-NetRoute -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction Stop | Where-Object {
                    $_.DestinationPrefix -eq $prefix -and $_.InterfaceIndex -eq $interface.InterfaceIndex -and $_.NextHop -eq $config.SDNLABRoute
                })
                if ($remaining.Count) { throw "Temporary AKS API route $prefix remains after cleanup." }
                Write-Host "Removed temporary AKS API route $prefix."
            }
            catch {
                if ($healthError) { throw "$healthError Route cleanup also failed: $($_.Exception.Message)" }
                throw
            }
        }
    }
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
    $azureReady = $false
    $previousConfig = $env:AZURE_CONFIG_DIR
    $previousExtensions = $env:AZURE_EXTENSION_DIR
    $previousPath = $env:PATH
    try {
        $locked = $lock.WaitOne(0)
        if (-not $locked) { throw 'Another hosted LocalBox automation is running.' }
        Start-Transcript -LiteralPath "$Directory/automation.log" -Force | Out-Null
        $transcribing = $true
        Initialize-LocalBoxAutomationEnvironment
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
        $azureReady = $true
        # Listing can succeed before uploads while Blob role assignments propagate.
        $status.Phase = 'Preparation'
        Wait-SovereignCheck -TimeoutSeconds 600 -Check {
            Invoke-LocalBoxAz @('storage', 'blob', 'list', '--account-name', $Configuration.StorageAccountName,
                '--container-name', $Configuration.Container, '--auth-mode', 'login', '--num-results', '1') | Out-Null
            Write-LocalBoxAutomationStatus $Configuration $Directory $status
        }
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
        $status.Phase = 'KubernetesClient'
        Write-LocalBoxAutomationStatus $Configuration $Directory $status
        $status.KubectlPath = Initialize-LocalBoxAutomationKubectl -InstanceId $manifest.AksInstanceId -Directory $Directory
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
        Invoke-LocalBoxAutomationRoutedHealth -ResourceRoot $ResourceRoot -InputPath $InputPath -ManifestPath $ManifestPath `
            -Kubeconfig "$Directory/aks.kubeconfig" -RecoverMetalLb
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
                if ($azureReady) {
                    try { Send-LocalBoxAutomationFiles $Configuration $Directory }
                    catch {
                        if ($status.Error) { throw "$($status.Error) Diagnostic upload also failed: $($_.Exception.Message)" }
                        throw
                    }
                }
                else { Write-Warning "Guest Azure authentication was not established. Diagnostics remain in $Directory and Run Command instanceView." }
            }
        }
        finally {
            $env:AZURE_CONFIG_DIR = $previousConfig
            $env:AZURE_EXTENSION_DIR = $previousExtensions
            $env:PATH = $previousPath
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
    $requestedManifestPath = $ManifestPath
    . "$PSScriptRoot/prepare-localbox.ps1"
    . "$PSScriptRoot/test-sovereign-cloud.ps1"
    $automation = Get-Content -LiteralPath $ParametersPath -Raw | ConvertFrom-Json -AsHashtable
    $directory = Split-Path -Parent $ParametersPath
    if ($HealthOnly) {
        Initialize-LocalBoxAutomationEnvironment
        Invoke-LocalBoxAutomationHealth -Configuration $automation -Directory $directory -ResourceRoot $PSScriptRoot -ManifestPath $requestedManifestPath
    }
    else {
        Invoke-LocalBoxGuestAutomation -Configuration $automation -Directory $directory -ResourceRoot $PSScriptRoot -InputPath $ParametersPath -ManifestPath $requestedManifestPath
    }
}
