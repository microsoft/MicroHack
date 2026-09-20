BeforeAll {
    . "$PSScriptRoot/../prepare-localbox.ps1"
    . "$PSScriptRoot/../test-sovereign-cloud.ps1"
}

Describe 'Lab cost-control tags' {
    It 'tags the LocalBox template and both resource-group paths' {
        $source = Get-Content "$PSScriptRoot/../../labautomation/deploy-localbox.ps1" -Raw
        $source | Should -Match 'tags\.CostControl=Ignore'
        $source | Should -Match "'CostControl=Ignore'"
        $source | Should -Match "CostControl\s*=\s*'Ignore'"
    }
    It 'tags participant resources and both AKS pools' {
        $source = Get-Content "$PSScriptRoot/../../labautomation/sovereign-lab.bicep" -Raw
        $source | Should -Match "(?s)var tags = \{[^}]*CostControl: 'Ignore'"
        $source | Should -Match "(?s)name: 'system'\s+count: 2\s+tags: tags"
        $source | Should -Match "(?s)resource confidentialNodePool .*?properties: \{\s+count: 1\s+tags: tags"
    }
}

Describe 'LocalBox input validation' {
    It 'defaults to three AKS worker nodes' {
        . "$PSScriptRoot/../prepare-localbox.ps1"
        $NodeCount | Should -Be 3
    }
    It 'allows an explicit AKS worker-count override' {
        . "$PSScriptRoot/../prepare-localbox.ps1" -NodeCount 1
        $NodeCount | Should -Be 1
    }
    It 'uses the image resource name shown in the walkthrough' {
        . "$PSScriptRoot/../prepare-localbox.ps1"
        $ImageName | Should -Be '2025-datacenter-azure-edition-smalldisk-01'
    }
    It 'allows an explicit image resource-name override' {
        . "$PSScriptRoot/../prepare-localbox.ps1" -ImageName 'existing-lab-image'
        $ImageName | Should -Be 'existing-lab-image'
    }
    It 'does not prompt or fabricate a group ID when AKS is explicitly skipped' {
        Mock Read-Host { throw 'Unexpected prompt' }
        Read-LocalBoxGroupId -SkipAks | Should -BeNullOrEmpty
        Should -Invoke Read-Host -Times 0
    }
    It 'fails on an empty group response instead of repeatedly prompting unattended runs' {
        Mock Read-Host { '' }
        { Read-LocalBoxGroupId } | Should -Throw
        Should -Invoke Read-Host -Times 1
    }
    It 'accepts the AKS node range while reserving control plane and VIP addresses' {
        { Test-LocalBoxAddressPool '10.10.0.0/24' '10.10.0.101' '10.10.0.199' '10.10.0.1' @('10.10.0.5', '10.10.0.10', '10.10.0.100') } | Should -Not -Throw
    }
    It 'rejects the old network-to-broadcast VM pool' {
        { Test-LocalBoxAddressPool '192.168.200.0/24' '192.168.200.0' '192.168.200.255' '192.168.200.1' } | Should -Throw
    }
    It 'rejects an infrastructure address inside the VM pool' {
        { Test-LocalBoxAddressPool '192.168.200.0/24' '192.168.200.10' '192.168.200.220' '192.168.200.1' @('192.168.200.205') } | Should -Throw
    }
    It 'rejects reversed ranges and foreign gateways' {
        { Test-LocalBoxAddressPool '10.10.0.0/24' '10.10.0.199' '10.10.0.101' '10.10.0.1' } | Should -Throw
        { Test-LocalBoxAddressPool '10.10.0.0/24' '10.10.0.101' '10.10.0.199' '10.11.0.1' } | Should -Throw
    }
    It 'rejects a pool wholly contained inside a reserved VIP range' {
        { Test-LocalBoxAddressPool '10.10.0.0/24' '10.10.0.20' '10.10.0.30' '10.10.0.1' -ReservedRanges @(@{ Start = '10.10.0.10'; End = '10.10.0.100' }) } | Should -Throw '*overlaps*'
    }
    It 'rejects missing or malformed group IDs' {
        { Assert-LocalBoxGroupId 'LabUsers' } | Should -Throw
        { Assert-LocalBoxGroupId ([guid]::Empty.ToString()) } | Should -Throw
    }
    It 'normalizes a group ID' {
        Assert-LocalBoxGroupId 'A0000000-0000-0000-0000-000000000001' | Should -Be 'a0000000-0000-0000-0000-000000000001'
    }
}

Describe 'AKS Local resource API selection' {
    It 'specifies the API version for nested AKS Local node pools' {
        Mock Invoke-LocalBoxAz { @{} }
        $identifier = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks/providers/Microsoft.HybridContainerService/provisionedClusterInstances/default/agentPools/nodepool1'
        Get-LocalBoxResource $identifier
        Should -Invoke Invoke-LocalBoxAz -Times 1 -ParameterFilter { $Arguments -contains '--api-version' -and $Arguments -contains '2024-01-01' }
    }
}

Describe 'Resource reconciliation' {
    BeforeEach {
        $resourceId = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.AzureStackHCI/logicalNetworks/vm-net'
        $expected = @{ properties = @{ vmSwitchName = 'external' } }
        Mock Invoke-LocalBoxAz { @() }
        Mock Get-LocalBoxResource { @{ properties = @{ provisioningState = 'Succeeded'; vmSwitchName = 'external' } } }
        Mock Start-Sleep {}
    }
    It 'does not create a resource in WhatIf mode' {
        Sync-LocalBoxResource $resourceId $expected @('resource', 'create') -WhatIf
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'create' }
    }
    It 'reuses a matching resource without writes' {
        Mock Invoke-LocalBoxAz { @(@{ id = $resourceId }) }
        Sync-LocalBoxResource $resourceId $expected @('resource', 'create')
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'create' }
    }
    It 'rejects conflicting properties without deleting or recreating' {
        Mock Invoke-LocalBoxAz { @(@{ id = $resourceId }) }
        { Sync-LocalBoxResource $resourceId @{ properties = @{ vmSwitchName = 'different' } } @('resource', 'create') } | Should -Throw '*Conflicting*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'create' -or $Arguments -contains 'delete' }
    }
    It 'rejects missing expected properties and empty arrays' {
        { Assert-LocalBoxProperties @{} @{ properties = @{ name = 'required' } } } | Should -Throw '*Missing*'
        { Assert-LocalBoxProperties @{ nodes = @() } @{ nodes = @('required') } } | Should -Throw '*array*'
    }
    It 'fails immediately on a failed deployment' {
        Mock Get-LocalBoxResource { @{ properties = @{ provisioningState = 'Failed' } } }
        { Wait-LocalBoxResource $resourceId } | Should -Throw '*Failed*'
        Should -Invoke Start-Sleep -Times 0
    }
    It 'bounds waits and reports the unfinished resource' {
        Mock Get-LocalBoxResource { @{ properties = @{ provisioningState = 'Creating' } } }
        { Wait-LocalBoxResource $resourceId -TimeoutSeconds 0 } | Should -Throw '*Timed out*'
    }
    It 'preserves the custom-location region instead of the resource-group region' {
        { Assert-LocalBoxProperties @{ location = 'swedencentral' } @{ location = 'australiaeast' } } | Should -Throw '*location*'
    }
    It 'resumes an in-progress resource' {
        $script:polls = 0
        Mock Get-LocalBoxResource {
            $script:polls++
            @{ properties = @{ provisioningState = $(if ($script:polls -eq 1) { 'Creating' } else { 'Succeeded' }) } }
        }
        (Wait-LocalBoxResource $resourceId).properties.provisioningState | Should -Be 'Succeeded'
        Should -Invoke Start-Sleep -Times 1
    }
}

Describe 'CLI process cleanup' {
    BeforeEach {
        Mock Get-LocalBoxAzInvocation { @{ Executable = 'az'; Prefix = @() } }
    }
    It 'cleans up read-only CLI jobs even during WhatIf' {
        Mock Start-Job { 1 }
        Mock Wait-Job { 1 }
        Mock Receive-Job { @{ name = 'read-only-result' } }
        Mock Remove-Job {}
        $WhatIfPreference = $true
        (Invoke-LocalBoxAz @('account', 'show')).name | Should -Be 'read-only-result'
        Should -Invoke Remove-Job -Times 1 -ParameterFilter { -not $WhatIf -and -not $Confirm }
    }
    It 'propagates a failed CLI job and still cleans it up' {
        Mock Start-Job { 1 }
        Mock Wait-Job { 1 }
        Mock Receive-Job { throw 'Azure CLI returned a nonzero exit code' }
        Mock Remove-Job {}
        { Invoke-LocalBoxAz @('resource', 'list') } | Should -Throw '*nonzero*'
        Should -Invoke Remove-Job -Times 1
    }
    It 'bounds a stalled CLI job without claiming the Azure operation was canceled' {
        Mock Start-Job { 1 }
        Mock Wait-Job { $null }
        Mock Receive-Job {}
        Mock Remove-Job {}
        { Invoke-LocalBoxAz @('resource', 'create') -TimeoutSeconds 1 } | Should -Throw '*may still be running*'
        Should -Invoke Receive-Job -Times 0
        Should -Invoke Remove-Job -Times 1
    }
}

Describe 'Windows Azure CLI argument transport' {
    It 'bypasses the batch wrapper using its bundled Python' {
        Mock Test-Path { $true }
        $command = Join-Path $TestDrive 'CLI2/wbin/az.cmd'
        $invocation = Get-LocalBoxAzInvocation -CommandPath $command
        $invocation.Executable | Should -Be ([IO.Path]::GetFullPath((Join-Path $TestDrive 'CLI2/python.exe')))
        $invocation.Prefix | Should -Be @('-IBm', 'azure.cli')
    }
    It 'rejects a batch installation without its bundled Python' {
        Mock Test-Path { $false }
        { Get-LocalBoxAzInvocation -CommandPath (Join-Path $TestDrive 'az.cmd') } | Should -Throw '*bundled Python*'
    }
    It 'leaves non-batch CLI executables unchanged' {
        $invocation = Get-LocalBoxAzInvocation -CommandPath '/usr/bin/az'
        $invocation.Executable | Should -Be '/usr/bin/az'
        $invocation.Prefix.Count | Should -Be 0
    }
}

Describe 'Storage removal guard' {
    BeforeEach {
        $state = @{ NodesUp = $true; PoolHealth = 'Healthy'; StorageJobs = 0; SecondaryFiles = @(); UnhealthyPhysicalDisks = 0 }
    }
    It 'allows an empty idle lab' {
        { Assert-LocalBoxStorageRemoval $state @() } | Should -Not -Throw
    }
    It 'rejects files even when Azure has no workload record' {
        $state.SecondaryFiles = @('important.vhdx')
        { Assert-LocalBoxStorageRemoval $state @() } | Should -Throw '*not empty*'
    }
    It 'rejects existing AKS resources even if the volume appears empty' {
        { Assert-LocalBoxStorageRemoval $state @(@{ type = 'Microsoft.Kubernetes/connectedClusters' }) } | Should -Throw '*workloads*'
    }
    It 'rejects an incomplete inventory' {
        { Assert-LocalBoxStorageRemoval @{} @() } | Should -Throw
    }
    It 'rejects ongoing storage jobs' {
        $state.StorageJobs = 1
        { Assert-LocalBoxStorageRemoval $state @() } | Should -Throw '*idle*'
    }
    It 'rejects unhealthy physical disks' {
        $state.UnhealthyPhysicalDisks = 1
        { Assert-LocalBoxStorageRemoval $state @() } | Should -Throw '*healthy*'
    }
}

Describe 'Generated Azure Local storage names' {
    BeforeEach {
        Mock Get-LocalBoxResource { @{ id = $Id; extendedLocation = @{ name = '/custom/jumpstart' }; properties = @{ provisioningState = 'Succeeded' } } }
        $resources = @(@{ name = 'UserStorage1-ae41ccf444cc4b64a24de6d2a4b69e07'; type = 'Microsoft.AzureStackHCI/storageContainers'; id = '/storage/primary' })
    }
    It 'resolves a generated storage name to its real resource ID' {
        (Resolve-LocalBoxStoragePath $resources UserStorage1 '/custom/jumpstart').id | Should -Be '/storage/primary'
    }
    It 'refuses ambiguous storage paths' {
        $resources += @{ name = 'UserStorage1'; type = 'Microsoft.AzureStackHCI/storageContainers'; id = '/storage/another' }
        { Resolve-LocalBoxStoragePath $resources UserStorage1 '/custom/jumpstart' } | Should -Throw '*exactly one*'
    }
    It 'refuses storage from another custom location' {
        { Resolve-LocalBoxStoragePath $resources UserStorage1 '/custom/other' } | Should -Throw '*different custom location*'
    }
    It 'allows an absent secondary path only when explicitly requested' {
        Resolve-LocalBoxStoragePath $resources UserStorage2 '/custom/jumpstart' -AllowMissing | Should -BeNullOrEmpty
        { Resolve-LocalBoxStoragePath $resources UserStorage2 '/custom/jumpstart' } | Should -Throw '*exactly one*'
    }
}

Describe 'Health checks do not report false readiness' {
    It 'accepts one Ready control-plane node and three Ready workers' {
        $control = @{ metadata = @{ labels = @{ 'node-role.kubernetes.io/control-plane' = '' } }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }
        $worker = @{ metadata = @{ labels = @{} }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }
        { Assert-SovereignLocalNodeCount @{ items = @($control, $worker, $worker, $worker) } 3 1 } | Should -Not -Throw
    }
    It 'rejects four Ready nodes with the wrong roles' {
        $worker = @{ metadata = @{ labels = @{} }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }
        { Assert-SovereignLocalNodeCount @{ items = @($worker, $worker, $worker, $worker) } 3 1 } | Should -Throw '*found 0 and 4*'
    }
    It 'rejects a pending worker even when the node count matches' {
        $control = @{ metadata = @{ labels = @{ 'node-role.kubernetes.io/control-plane' = '' } }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }
        $worker = @{ metadata = @{ labels = @{} }; status = @{ conditions = @(@{ type = 'Ready'; status = 'False' }) } }
        { Assert-SovereignLocalNodeCount @{ items = @($control, $worker, $worker, $worker) } 3 1 } | Should -Throw '*not Ready*'
    }
    It 'accepts a fork and branch for the health suite download' {
        . "$PSScriptRoot/../test-sovereign-cloud.ps1" -GitHubRepository 'janegilring/MicroHack' -GitHubRef 'sov-cloud-localbox-post-automation'
        $GitHubRepository | Should -Be 'janegilring/MicroHack'
        $GitHubRef | Should -Be 'sov-cloud-localbox-post-automation'
        $source = Get-Content "$PSScriptRoot/../test-sovereign-cloud.ps1" -Raw
        $source | Should -Match 'https://raw.githubusercontent.com/\$GitHubRepository/\$GitHubRef/'
    }
    It 'rejects empty node collections and NotReady nodes' {
        { Assert-SovereignNodes @{ items = @() } 1 } | Should -Throw
        { Assert-SovereignNodes @{ items = @(@{ metadata = @{ name = 'worker' }; status = @{ conditions = @(@{ type = 'Ready'; status = 'False' }) } }) } 1 } | Should -Throw '*not Ready*'
    }
    It 'accepts a ready node' {
        { Assert-SovereignNodes @{ items = @(@{ metadata = @{ name = 'worker' }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }) } 1 } | Should -Not -Throw
    }
    It 'rejects empty or pending system pods' {
        { Assert-SovereignSystemPods @{ items = @() } } | Should -Throw
        { Assert-SovereignSystemPods @{ items = @(@{ metadata = @{ namespace = 'kube-system'; name = 'dns' }; status = @{ phase = 'Pending' } }) } } | Should -Throw '*not healthy*'
    }
    It 'allows completed system jobs without accepting failed workloads' {
        { Assert-SovereignSystemPods @{ items = @(@{ metadata = @{ namespace = 'kube-system' }; status = @{ phase = 'Succeeded' } }) } } | Should -Not -Throw
    }
    It 'never calls control-plane-only results full readiness' {
        $result = @{ TotalCount = 5; PassedCount = 5; FailedCount = 0; SkippedCount = 0; NotRunCount = 0 }
        Get-SovereignReadiness $result 'ControlPlane' | Should -BeFalse
        Get-SovereignReadiness $result 'Full' | Should -BeTrue
        $result.SkippedCount = 1
        Get-SovereignReadiness $result 'Full' | Should -BeFalse
    }
    It 'rejects missing inventory instead of discovering an empty successful lab' {
        { Get-SovereignLabOutputs @{ SubscriptionId = 'test'; ResourceGroupName = 'test' } } | Should -Throw '*DeploymentName*'
    }
    It 'does not retry permission failures' {
        Mock Start-Sleep {}
        { Wait-SovereignCheck { throw 'AuthorizationFailed' } } | Should -Throw '*AuthorizationFailed*'
        Should -Invoke Start-Sleep -Times 0
    }
    It 'keeps the requested health mode when helper functions are loaded' {
        $mode = 'ControlPlane'
        . "$PSScriptRoot/../test-sovereign-cloud.ps1" -Mode $mode -AllowGuestRunCommand
        $Mode | Should -Be 'ControlPlane'
        $AllowGuestRunCommand | Should -BeTrue
    }
}

Describe 'Storage execution safety' {
    It 'uses the documented volume label parameter in nested script blocks' {
        $source = Get-Content "$PSScriptRoot/../prepare-localbox.ps1" -Raw
        $source | Should -Not -Match 'Get-Volume\s+-FriendlyName'
        $source | Should -Match 'Get-Volume\s+-FileSystemLabel'
    }
    BeforeAll {
        function Get-Volume { param($DriveLetter) }
        function Get-VHD { param($Path) }
        function New-VHD { param($Path, $SizeBytes, [switch]$Dynamic) }
        function Get-VMHardDiskDrive { param($VMName) }
        function Add-VMHardDiskDrive { param($VMName, $Path) }
    }
    BeforeEach {
        $configuration = @{ NodeHostConfig = @(@{ Hostname = 'AzLHOST1' }, @{ Hostname = 'AzLHOST2' }); HostVMDriveLetter = 'V'; HostVMPath = $TestDrive }
        $credential = [pscredential]::new('test-user', [Security.SecureString]::new())
        Mock Get-Volume { @{ HealthStatus = 'Healthy'; SizeRemaining = 300GB } }
        Mock Test-Path { $false }
        Mock Get-VHD { @{ Size = 1TB; VhdType = 'Dynamic' } }
        Mock Get-VMHardDiskDrive { @() }
        Mock New-VHD {}
        Mock Add-VMHardDiskDrive {}
        Mock Invoke-Command {}
        Mock Get-LocalBoxNodeState { @{ PoolHealth = 'Healthy'; DiskHealth = 'Healthy'; VolumeHealth = 'Healthy'; NodesUp = $true; StorageJobs = 0; UnhealthyPhysicalDisks = 0; Size = 679GB } }
    }
    It 'does not create, attach or resize anything during WhatIf' {
        Initialize-LocalBoxStorage -Configuration $configuration -Credential $credential -DesiredSizeGB 1024 -WhatIf
        Should -Invoke New-VHD -Times 0
        Should -Invoke Add-VMHardDiskDrive -Times 0
        Should -Invoke Invoke-Command -Times 0
    }
    It 'does not duplicate disks or grow an already sized virtual disk on rerun' {
        Mock Test-Path { $true }
        Mock Get-VMHardDiskDrive { @(@{ Path = Join-Path $TestDrive "$VMName-microhack-s2d.vhdx" }) }
        Mock Get-LocalBoxNodeState { @{ PoolHealth = 'Healthy'; DiskHealth = 'Healthy'; VolumeHealth = 'Healthy'; NodesUp = $true; StorageJobs = 0; UnhealthyPhysicalDisks = 0; Size = 1TB } }
        Initialize-LocalBoxStorage -Configuration $configuration -Credential $credential -DesiredSizeGB 1024 -Confirm:$false
        Should -Invoke New-VHD -Times 0
        Should -Invoke Add-VMHardDiskDrive -Times 0
        Should -Invoke Invoke-Command -Times 0 -ParameterFilter { $ScriptBlock.ToString() -match 'Resize-VirtualDisk' }
    }
}

Describe 'Storage convergence' {
    It 'ignores retained completed storage jobs' {
        Mock Invoke-Command { @{ StorageJobs = 0; StorageJobStates = @('Completed', 'Completed') } }
        $credential = [pscredential]::new('test-user', [Security.SecureString]::new())
        (Get-LocalBoxNodeState 'node' $credential).StorageJobs | Should -Be 0
    }
    It 'does not ignore active, failed or suspended storage jobs' {
        Mock Invoke-Command { @{ StorageJobs = 0; StorageJobStates = @('Completed', 'Running', 'Exception', 'Suspended') } }
        $credential = [pscredential]::new('test-user', [Security.SecureString]::new())
        (Get-LocalBoxNodeState 'node' $credential).StorageJobs | Should -Be 3
    }
    It 'waits for post-attachment storage jobs without ignoring health' {
        $script:storagePoll = 0
        Mock Start-Sleep {}
        Mock Get-LocalBoxNodeState {
            $script:storagePoll++
            @{ PoolHealth = 'Healthy'; DiskHealth = 'Healthy'; VolumeHealth = 'Healthy'; NodesUp = $true; UnhealthyPhysicalDisks = 0; StorageJobs = $(if ($script:storagePoll -eq 1) { 1 } else { 0 }) }
        }
        (Wait-LocalBoxStorageReady 'node').StorageJobs | Should -Be 0
        Should -Invoke Start-Sleep -Times 1
    }
    It 'fails when storage never becomes healthy' {
        Mock Get-LocalBoxNodeState { @{ PoolHealth = 'Warning'; StorageJobs = 1 } }
        { Wait-LocalBoxStorageReady 'node' -TimeoutSeconds 0 } | Should -Throw '*Timed out*'
    }
}