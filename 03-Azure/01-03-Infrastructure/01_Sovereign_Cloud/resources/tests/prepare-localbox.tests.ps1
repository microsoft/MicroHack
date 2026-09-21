BeforeAll {
    . "$PSScriptRoot/../prepare-localbox.ps1"
    . "$PSScriptRoot/../test-sovereign-cloud.ps1"
    . "$PSScriptRoot/../../labautomation/localbox-credentials.ps1"
}

Describe 'LocalBox capacity safety' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $snapshot = @{ HostHealthy = $true; HostFreeGB = 1200; Nodes = @(
            @{ Name = 'node1'; Healthy = $true; CsvFreeGB = 926; Copies = 2; FreeMemoryGB = 48 }
            @{ Name = 'node2'; Healthy = $true; CsvFreeGB = 926; Copies = 2; FreeMemoryGB = 48 }
        ) }
        $limits = @{ MinimumHostFreeGB = 300; MinimumCsvFreeGB = 150; MinimumNodeFreeGB = 12; DiskBudgetGB = 40; MemoryMB = 4096 }
    }
    It 'allows one VM within all reserves' {
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Not -Throw
    }
    It 'reserves mirrored growth on the backing host, not just CSV free space' {
        $snapshot.HostFreeGB = 379
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Throw '*backing-volume*'
    }
    It 'reserves disk growth for the entire in-flight batch' {
        $snapshot.HostFreeGB = 699
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits -AdditionalVMs 5 } | Should -Throw '*backing-volume*'
        $snapshot.HostFreeGB = 700
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits -AdditionalVMs 5 } | Should -Not -Throw
    }
    It 'reserves batch memory on each node without assuming balanced placement' {
        $snapshot.Nodes[0].FreeMemoryGB = 31
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits -AdditionalVMs 5 } | Should -Throw '*node1*'
    }
    It 'reserves primary CSV space for every in-flight VM' {
        $snapshot.Nodes[0].CsvFreeGB = 349
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits -AdditionalVMs 5 } | Should -Throw '*UserStorage_1*'
    }
    It 'protects the primary CSV' {
        $snapshot.Nodes[0].CsvFreeGB = 189
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Throw '*UserStorage_1*'
    }
    It 'requires placement headroom on each node' {
        $snapshot.Nodes[1].FreeMemoryGB = 15
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Throw '*node2*'
    }
    It 'stops on an unhealthy node or storage' {
        $snapshot.Nodes[1].Healthy = $false
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Throw '*not healthy*'
    }
    It 'does not estimate capacity without a known resiliency factor' {
        $snapshot.Nodes | ForEach-Object { $_.Copies = 0 }
        { Assert-LocalBoxCapacityHeadroom $snapshot $limits } | Should -Throw '*copy count*'
    }
}

Describe 'LocalBox capacity lifecycle' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $runId = '123456781234123412341234567890ab'
        $groupId = "/subscriptions/test/resourceGroups/rg-lbcap-$runId"
        $clusterId = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.AzureStackHCI/clusters/localboxcluster'
        $entry = @{ Index = 1; Name = 'lc12345678-001'; Status = 'Submitting'; SubmittedAt = [datetime]::UtcNow.AddSeconds(-60).ToString('o') }
        $state = @{ SchemaVersion = 1; RunId = $runId; SubscriptionId = 'test'; ResourceGroupName = "rg-lbcap-$runId"; ClusterId = $clusterId; VMs = @($entry) }
        $localBox = @{ SubscriptionId = 'test'; ResourceGroupName = 'localbox'; ClusterId = $clusterId }
        $group = @{ id = $groupId; tags = @{ MicroHackPurpose = 'LocalBoxCapacityTest'; MicroHackRunId = $runId } }
        $machineId = "$groupId/providers/Microsoft.HybridCompute/machines/$($entry.Name)"
        $resources = @(@{ id = $machineId }, @{ id = "$groupId/providers/Microsoft.AzureStackHCI/networkInterfaces/$($entry.Name)-nic" })
        Mock Invoke-LocalBoxAz { throw 'Unexpected CLI call' }
        Mock Save-LocalBoxCapacityState {}
    }
    It 'accepts only matching run ownership' {
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Not -Throw
    }
    It 'rejects mismatched tags' {
        $group.tags.MicroHackRunId = 'another-run'
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*ownership*'
    }
    It 'cannot target the shared resource group' {
        $state.ResourceGroupName = 'localbox'
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*mismatched*'
    }
    It 'cannot target another LocalBox or subscription' -TestCases @(
        @{ Key = 'SubscriptionId'; Value = 'other' }
        @{ Key = 'ClusterId'; Value = '/subscriptions/test/resourceGroups/another-cluster' }
    ) {
        param($Key, $Value)
        $state[$Key] = $Value
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*mismatched*'
    }
    It 'rejects unrelated resources even inside a tagged group' {
        $resources += @{ id = "$groupId/providers/Microsoft.HybridCompute/machines/student-vm" }
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*Unrelated resource*'
    }
    It 'accepts only children of its own machines' {
        $resources += @{ id = "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default" }
        $resources += @{ id = "$machineId/extensions/MDE.Windows" }
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Not -Throw
        $resources += @{ id = "$groupId/providers/Microsoft.HybridCompute/machines/student-vm/extensions/MDE.Windows" }
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*Unrelated resource*'
    }
    It 'rejects journal VM names that do not belong to this run' {
        $entry.Name = 'student-vm'
        { Assert-LocalBoxCapacityOwnership $state $localBox $group $resources } | Should -Throw '*Invalid VM name*'
    }
    It 'does not delete under WhatIf' {
        Mock Invoke-LocalBoxAz { $true } -ParameterFilter { $Arguments[0] -eq 'group' -and $Arguments[1] -eq 'exists' }
        Mock Invoke-LocalBoxAz { $group } -ParameterFilter { $Arguments[0] -eq 'group' -and $Arguments[1] -eq 'show' }
        Mock Invoke-LocalBoxAz { $resources } -ParameterFilter { $Arguments[0] -eq 'resource' -and $Arguments[1] -eq 'list' }
        Remove-LocalBoxCapacityRun $state $localBox 'state.json' -WhatIf
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'delete' }
        Should -Invoke Save-LocalBoxCapacityState -Times 0
    }
    It 'refuses cleanup when an unrelated resource exists' {
        $resources += @{ id = "$groupId/providers/Microsoft.Storage/storageAccounts/unrelated" }
        Mock Invoke-LocalBoxAz { $true } -ParameterFilter { $Arguments[1] -eq 'exists' }
        Mock Invoke-LocalBoxAz { $group } -ParameterFilter { $Arguments[1] -eq 'show' }
        Mock Invoke-LocalBoxAz { $resources } -ParameterFilter { $Arguments[1] -eq 'list' }
        { Remove-LocalBoxCapacityRun $state $localBox 'state.json' -Confirm:$false } | Should -Throw '*Unrelated*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'delete' }
    }
    It 'deletes only the exact owned group and verifies it is gone' {
        $checks = @{ Count = 0 }
        Mock Invoke-LocalBoxAz { $checks.Count++; return $checks.Count -eq 1 } -ParameterFilter { $Arguments[1] -eq 'exists' }
        Mock Invoke-LocalBoxAz { $group } -ParameterFilter { $Arguments[1] -eq 'show' }
        Mock Invoke-LocalBoxAz { $resources } -ParameterFilter { $Arguments[1] -eq 'list' }
        Mock Invoke-LocalBoxAz {} -ParameterFilter { $Arguments[1] -eq 'delete' }
        Remove-LocalBoxCapacityRun $state $localBox 'state.json' -Confirm:$false
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments[0] -eq 'group' -and $Arguments[1] -eq 'delete' -and $Arguments -contains $state.ResourceGroupName -and $Arguments -contains 'test'
        }
        $state.Status | Should -Be 'Deleted'
        Should -Invoke Save-LocalBoxCapacityState -Times 1
    }
    It 'requires running and connected status after deployment succeeds' -TestCases @(
        @{ Power = 'Running'; Guest = 'Connected'; Expected = 'Ready' }
        @{ Power = 'Stopped'; Guest = 'Connected'; Expected = 'WaitingForGuest' }
        @{ Power = 'Running'; Guest = 'Disconnected'; Expected = 'WaitingForGuest' }
    ) {
        param($Power, $Guest, $Expected)
        Mock Invoke-LocalBoxAz { @{ properties = @{ provisioningState = 'Succeeded' } } } -ParameterFilter { $Arguments[0] -eq 'deployment' }
        Mock Invoke-LocalBoxAz { @{ properties = @{ provisioningState = 'Succeeded'; status = @{ powerState = $Power } } } } -ParameterFilter { $Arguments -contains '2024-01-01' }
        Mock Invoke-LocalBoxAz { @{ properties = @{ status = $Guest } } } -ParameterFilter { $Arguments -contains '2023-10-03-preview' }
        Update-LocalBoxCapacityVM $state $entry
        $entry.Status | Should -Be $Expected
        if ($Expected -eq 'Ready') { $entry.ElapsedSeconds | Should -BeGreaterOrEqual 60 }
    }
    It 'does not count a pending or failed deployment as ready' -TestCases @(
        @{ DeploymentState = 'Running'; Expected = 'Provisioning' }
        @{ DeploymentState = 'Failed'; Expected = 'Failed' }
    ) {
        param($DeploymentState, $Expected)
        Mock Invoke-LocalBoxAz { @{ properties = @{ provisioningState = $DeploymentState } } } -ParameterFilter { $Arguments[0] -eq 'deployment' }
        Update-LocalBoxCapacityVM $state $entry
        $entry.Status | Should -Be $Expected
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[0] -eq 'resource' }
    }
    It 'uses a secure password parameter and explicitly targets the prepared storage and network' {
        $template = New-LocalBoxCapacityTemplate
        $template.parameters.adminPassword.type | Should -Be 'securestring'
        $template.resources.Count | Should -Be 3
        $vm = $template.resources | Where-Object type -eq 'Microsoft.AzureStackHCI/virtualMachineInstances'
        $vm.properties.storageProfile.vmConfigStoragePathId | Should -Be "[parameters('storageId')]"
        $vm.properties.storageProfile.imageReference.id | Should -Be "[parameters('imageId')]"
        $vm.properties.hardwareProfile.memoryMB | Should -Be "[parameters('memoryMB')]"
        $vm.properties.hardwareProfile.ContainsKey('dynamicMemoryConfig') | Should -BeFalse
        $vm.properties.osProfile.windowsConfiguration.provisionVMAgent | Should -BeTrue
        $vm.properties.osProfile.windowsConfiguration.provisionVMConfigAgent | Should -BeTrue
        $nic = $template.resources | Where-Object type -eq 'Microsoft.AzureStackHCI/networkInterfaces'
        $nic.properties.ipConfigurations[0].properties.subnet.id | Should -Be "[parameters('networkId')]"
        $nic.properties.ipConfigurations[0].properties.ContainsKey('privateIPAddress') | Should -BeFalse
    }
}

Describe 'LocalBox capacity orchestration' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $oldSubscription = $env:subscriptionId
        $oldGroup = $env:resourceGroup
        $oldConfigPath = $env:LocalBoxConfigFile
        $env:subscriptionId = 'test'
        $env:resourceGroup = 'localbox'
        $env:LocalBoxConfigFile = 'mock-config.psd1'
        $localBox = @{
            SubscriptionId = 'test'; ResourceGroupName = 'localbox'; ClusterId = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.AzureStackHCI/clusters/localboxcluster'
            CustomLocationId = 'custom-location'; StorageId = 'storage1'; ImageId = 'image'; NodeNames = @('node1', 'node2')
            Networks = @(@{ Name = 'localbox-vm-lnet-vlan200'; Id = 'vm-network' })
        }
        $credential = [pscredential]::new('localadmin', [Security.SecureString]::new())
        $settings = @{
            Mode = 'Deploy'; LocalBoxManifestPath = 'manifest.json'; StatePath = 'state.json'; VmCount = 2
            ProcessorCount = 2; MemoryMB = 4096; MinimumHostFreeGB = 300; MinimumCsvFreeGB = 150
            MinimumNodeFreeGB = 12; DiskBudgetGB = 40; TimeoutMinutes = 1; NodeCredential = $credential; VmCredential = $credential
        }
        $snapshot = @{ HostHealthy = $true; HostFreeGB = 1200; Nodes = @(
            @{ Name = 'node1'; Healthy = $true; CsvFreeGB = 926; Copies = 2; FreeMemoryGB = 48 }
            @{ Name = 'node2'; Healthy = $true; CsvFreeGB = 926; Copies = 2; FreeMemoryGB = 48 }
        ) }
        $journal = @{ State = $null }
        Mock Assert-LocalBoxCapacityHost {}
        Mock Import-PowerShellDataFile { @{} }
        Mock Resolve-LocalBoxNodeCredential { $credential }
        Mock Get-LocalBoxCapacitySnapshot { $snapshot }
        Mock Test-Path { $false }
        Mock Get-Content { $localBox | ConvertTo-Json -Depth 10 }
        Mock Get-LocalBoxResource { @{ location = 'westeurope'; properties = @{ provisioningState = 'Succeeded'; containerId = 'storage1'; status = @{ progressPercentage = 100 } } } }
        Mock Invoke-LocalBoxAz { $false }
        Mock Submit-LocalBoxCapacityVM {}
        Mock Update-LocalBoxCapacityVM { $Entry.Status = 'Ready'; $Entry.GuestStatus = 'Connected'; $Entry.PowerState = 'Running' }
        Mock Save-LocalBoxCapacityState { $journal.State = $State }
        Mock Start-Sleep { throw 'Unexpected sleep' }
        Mock Get-Credential { throw 'Unexpected prompt' }
    }
    AfterEach { $env:subscriptionId = $oldSubscription; $env:resourceGroup = $oldGroup; $env:LocalBoxConfigFile = $oldConfigPath }
    It 'creates a bounded run and records only nonsecret state' {
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 2 -Exactly
        $journal.State.VMs.Count | Should -Be 2
        $journal.State.Status | Should -Be 'TargetReached'
        $journal.State.ResourceGroupName | Should -Match '^rg-lbcap-[a-f0-9]{32}$'
        ($journal.State | ConvertTo-Json -Depth 20) | Should -Not -Match 'Password|Credential'
    }
    It 'does no writes or credential prompts during WhatIf' {
        $settings.VmCredential = $null
        Invoke-LocalBoxCapacityRun $settings -WhatIf
        Should -Invoke Submit-LocalBoxCapacityVM -Times 0
        Should -Invoke Save-LocalBoxCapacityState -Times 0
        Should -Invoke Get-Credential -Times 0
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'submits only one additional VM without a long-running local monitor' {
        $settings.SubmitNext = $true
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0
        $journal.State.Status | Should -Be 'AwaitingReadiness'
        $journal.State.VMs.Count | Should -Be 1
        $journal.State.VMs[0].Status | Should -Be 'Submitted'
    }
    It 'submits five VMs before checking their readiness' {
        $settings.VmCount = 5
        $settings.BatchSize = 5
        $submissions = @{ Count = 0 }
        Mock Submit-LocalBoxCapacityVM { $submissions.Count++ }
        Mock Update-LocalBoxCapacityVM {
            $submissions.Count | Should -Be 5
            $Entry.Status = 'Ready'
        }
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 5 -Exactly
        $journal.State.Status | Should -Be 'TargetReached'
        @($journal.State.VMs.BatchId | Select-Object -Unique).Count | Should -Be 1
    }
    It 'submits one bounded batch and exits without starting a second' {
        $settings.VmCount = 10
        $settings.BatchSize = 5
        $settings.SubmitBatch = $true
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 5 -Exactly
        Should -Invoke Start-Sleep -Times 0
        $journal.State.Status | Should -Be 'AwaitingReadiness'
        $journal.State.VMs.Count | Should -Be 5
    }
    It 'limits the last batch to the remaining target count' {
        $settings.VmCount = 3
        $settings.BatchSize = 5
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 3 -Exactly
        $journal.State.VMs.Count | Should -Be 3
    }
    It 'does not submit any of a batch that cannot fit the reserves' {
        $settings.VmCount = 5
        $settings.BatchSize = 5
        $snapshot.HostFreeGB = 600
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*backing-volume*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 0
    }
    It 'does not start a second batch after a failure in the first' {
        $settings.VmCount = 10
        $settings.BatchSize = 5
        Mock Update-LocalBoxCapacityVM { $Entry.Status = 'Failed' }
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*batch deployment failed*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 5 -Exactly
    }
    It 'stops after one submission fails and preserves the journal' {
        Mock Submit-LocalBoxCapacityVM { throw 'Submission failed; inspect deployment' }
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*Submission failed*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 1
        $journal.State.Status | Should -Be 'Stopped'
        $journal.State.VMs.Count | Should -Be 1
    }
    It 'stops on readiness timeout without retrying VM creation' {
        $settings.TimeoutMinutes = 0
        Mock Update-LocalBoxCapacityVM { $Entry.Status = 'WaitingForGuest' }
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*Timed out*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 1
        Should -Invoke Start-Sleep -Times 0
        $journal.State.VMs[0].Status | Should -Be 'WaitingForGuest'
    }
    It 'does not create the resource group when headroom is insufficient' {
        $snapshot.HostFreeGB = 250
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*backing-volume*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
        Should -Invoke Submit-LocalBoxCapacityVM -Times 0
    }
    It 'rechecks headroom before each subsequent VM' {
        $samples = @{ Count = 0 }
        Mock Get-LocalBoxCapacitySnapshot {
            $samples.Count++
            if ($samples.Count -gt 2) { $snapshot.HostFreeGB = 350 }
            $snapshot
        }
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*backing-volume*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 1
        $journal.State.Status | Should -Be 'Stopped'
    }
    It 'extends an existing ready run without recreating its VMs' {
        $settings.VmCount = 1
        Invoke-LocalBoxCapacityRun $settings
        $saved = $journal.State | ConvertTo-Json -Depth 20
        Mock Test-Path { $true }
        Mock Get-Content { $saved } -ParameterFilter { $LiteralPath -eq 'state.json' }
        Mock Assert-LocalBoxCapacityOwnership {}
        $settings.VmCount = 2
        Invoke-LocalBoxCapacityRun $settings
        Should -Invoke Submit-LocalBoxCapacityVM -Times 2 -Exactly
        $journal.State.VMs.Count | Should -Be 2
        $journal.State.VMs[0].Name | Should -Not -Be $journal.State.VMs[1].Name
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[0] -eq 'group' -and $Arguments[1] -eq 'create' }
    }
    It 'refuses to extend a run whose existing VM is unhealthy' {
        $settings.VmCount = 1
        Invoke-LocalBoxCapacityRun $settings
        $saved = $journal.State | ConvertTo-Json -Depth 20
        Mock Test-Path { $true }
        Mock Get-Content { $saved } -ParameterFilter { $LiteralPath -eq 'state.json' }
        Mock Assert-LocalBoxCapacityOwnership {}
        Mock Update-LocalBoxCapacityVM { $Entry.Status = 'Failed' }
        $settings.VmCount = 2
        { Invoke-LocalBoxCapacityRun $settings } | Should -Throw '*Existing test VM*'
        Should -Invoke Submit-LocalBoxCapacityVM -Times 1
    }
}

Describe 'LocalBox capacity pending submission recovery' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $scope = '/subscriptions/test/resourceGroups/rg-test'
        $pending = @{ Name = 'lc-test-002'; Status = 'Submitting'; SubmittedAt = '2026-09-21T00:00:00Z' }
        $state = @{ SubscriptionId = 'test'; ResourceGroupName = 'rg-test'; VMs = @(@{ Name = 'lc-test-001'; Status = 'Ready' }, $pending) }
        Mock Invoke-LocalBoxAz { @() }
    }
    It 'retries only a verified absent trailing submission and retains its history' {
        Repair-LocalBoxCapacityPendingSubmission $state
        $state.VMs.Count | Should -Be 1
        $state.VMs[0].Name | Should -Be 'lc-test-001'
        $state.UnsubmittedAttempts[0].Name | Should -Be 'lc-test-002'
        Should -Invoke Invoke-LocalBoxAz -Times 2 -Exactly
    }
    It 'does not resubmit when a deployment record exists' {
        Mock Invoke-LocalBoxAz { @(@{ name = 'lc-test-002' }) } -ParameterFilter { $Arguments[0] -eq 'deployment' }
        Repair-LocalBoxCapacityPendingSubmission $state
        $state.VMs.Count | Should -Be 2
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[0] -eq 'resource' }
    }
    It 'refuses to retry when any resource already exists' -TestCases @(
        @{ Suffix = '/providers/Microsoft.HybridCompute/machines/lc-test-002' }
        @{ Suffix = '/providers/Microsoft.AzureStackHCI/networkInterfaces/lc-test-002-nic' }
        @{ Suffix = '/providers/Microsoft.HybridCompute/machines/lc-test-002/extensions/MDE.Windows' }
    ) {
        param($Suffix)
        Mock Invoke-LocalBoxAz { @(@{ id = "$scope$Suffix" }) } -ParameterFilter { $Arguments[0] -eq 'resource' }
        { Repair-LocalBoxCapacityPendingSubmission $state } | Should -Throw '*resources but no deployment*'
        $state.VMs.Count | Should -Be 2
    }
    It 'does not treat a failed read as an absent deployment' {
        Mock Invoke-LocalBoxAz { throw 'AuthorizationFailed' }
        { Repair-LocalBoxCapacityPendingSubmission $state } | Should -Throw '*AuthorizationFailed*'
        $state.VMs.Count | Should -Be 2
    }
    It 'rejects ambiguous journal entries' {
        $state.VMs[0].Status = 'Submitting'
        { Repair-LocalBoxCapacityPendingSubmission $state } | Should -Throw '*Ambiguous*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
}

Describe 'LocalBox capacity remote execution' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $cluster = '/subscriptions/a0000000-0000-0000-0000-000000000001/resourceGroups/localbox/providers/Microsoft.AzureStackHCI/clusters/cluster'
        $context = @{ LocalBox = @{ ClusterId = $cluster; SubscriptionId = 'a0000000-0000-0000-0000-000000000001'; ResourceGroupName = 'localbox' }; Snapshot = @{ HostFreeGB = 1200 } }
        Mock Invoke-LocalBoxAz { @{ value = @(@{ message = "[stdout]`nLB_CAPACITY_BEGIN`n$($context | ConvertTo-Json -Depth 8 -Compress)`nLB_CAPACITY_END`n[stderr]" }) } }
    }
    It 'targets the exact subscription and Client and returns only parsed telemetry' {
        $result = Get-LocalBoxRemoteCapacityContext $cluster 'C:\LocalBox\sovereign-localbox.json'
        $result.Snapshot.HostFreeGB | Should -Be 1200
        $result.LocalBox.RemoteClusterId | Should -Be $cluster
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments -contains 'run-command' -and $Arguments -contains 'a0000000-0000-0000-0000-000000000001' -and
            $Arguments -contains 'localbox' -and $Arguments -contains 'LocalBox-Client'
        }
    }
    It 'fails closed on truncated telemetry' {
        Mock Invoke-LocalBoxAz { @{ value = @(@{ message = 'LB_CAPACITY_BEGIN {}' }) } }
        { Get-LocalBoxRemoteCapacityContext $cluster 'manifest.json' } | Should -Throw '*no complete result*'
    }
    It 'rejects a result from another cluster' {
        $context.LocalBox.ClusterId = '/some/other/cluster'
        { Get-LocalBoxRemoteCapacityContext $cluster 'manifest.json' } | Should -Throw '*does not match*'
    }
    It 'rejects an invalid target before invoking Run Command' {
        { Get-LocalBoxRemoteCapacityContext '/subscriptions/other/resourceGroups/shared' 'manifest.json' } | Should -Throw '*exact Azure Local cluster*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
}

Describe 'LocalBox capacity secure submission' {
    BeforeAll { . "$PSScriptRoot/../test-localbox-capacity.ps1" }
    BeforeEach {
        $state = @{
            SubscriptionId = 'test'; ResourceGroupName = 'rg-test'; Location = 'westeurope'; RunId = 'test'
            CustomLocationId = 'custom'; ImageId = 'image'; NetworkId = 'network'; StorageId = 'storage'
            ProcessorCount = 2; MemoryMB = 4096
        }
        $entry = @{ Name = 'lc-test-001' }
        $mockPassword = [Security.SecureString]::new()
        foreach ($character in 'Mock!Password9-not-real'.GetEnumerator()) { $mockPassword.AppendChar($character) }
        $mockPassword.MakeReadOnly()
        $credential = [pscredential]::new('localadmin', $mockPassword)
        $paths = [Collections.Generic.List[string]]::new()
        $machineId = '/subscriptions/test/resourceGroups/rg-test/providers/Microsoft.HybridCompute/machines/lc-test-001'
        $preview = @{ status = 'Succeeded'; changes = @(
            @{ resourceId = $machineId; changeType = 'Create' }
            @{ resourceId = "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default"; changeType = 'Create' }
            @{ resourceId = '/subscriptions/test/resourceGroups/rg-test/providers/Microsoft.AzureStackHCI/networkInterfaces/lc-test-001-nic'; changeType = 'Create' }
        ) }
        Mock Invoke-LocalBoxAz {
            $Arguments | Should -Not -Contain 'Mock!Password9-not-real'
            $parameterFile = $Arguments[$Arguments.IndexOf('--parameters') + 1].Substring(1)
            $paths.Add($parameterFile)
            (Get-Content -LiteralPath $parameterFile -Raw | ConvertFrom-Json).parameters.adminPassword.value | Should -Be 'Mock!Password9-not-real'
            if (-not $IsWindows) {
                $directory = [IO.Path]::GetDirectoryName($parameterFile)
                [int][IO.File]::GetUnixFileMode($directory) | Should -Be 448
            }
            if ($Arguments[2] -eq 'what-if') { $preview }
        }
    }
    It 'previews then submits and removes credential files' {
        Submit-LocalBoxCapacityVM $state $entry $credential
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'what-if' }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'create' -and $NoOutput -and $Arguments -contains '--no-wait' }
        foreach ($path in $paths) { Test-Path -LiteralPath $path | Should -BeFalse }
    }
    It 'rejects changes outside the three new VM resources' -TestCases @(
        @{ Field = 'changeType'; Value = 'Modify' }
        @{ Field = 'resourceId'; Value = '/subscriptions/test/resourceGroups/shared/providers/Microsoft.HybridCompute/machines/student' }
    ) {
        param($Field, $Value)
        $preview.changes[0][$Field] = $Value
        { Submit-LocalBoxCapacityVM $state $entry $credential } | Should -Throw '*submission failed*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
        foreach ($path in $paths) { Test-Path -LiteralPath $path | Should -BeFalse }
    }
    It 'permits harmless existing-resource entries during incremental deployment' -TestCases @(
        @{ ChangeType = 'Ignore' }
        @{ ChangeType = 'NoChange' }
    ) {
        param($ChangeType)
        $preview.changes += @{ resourceId = '/subscriptions/test/resourceGroups/rg-test/providers/Microsoft.HybridCompute/machines/earlier-vm'; changeType = $ChangeType }
        Submit-LocalBoxCapacityVM $state $entry $credential
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'still rejects modifications or deletions of an existing VM' -TestCases @(
        @{ ChangeType = 'Modify' }
        @{ ChangeType = 'Delete' }
        @{ ChangeType = 'Unsupported' }
    ) {
        param($ChangeType)
        $preview.changes += @{ resourceId = '/subscriptions/test/resourceGroups/rg-test/providers/Microsoft.HybridCompute/machines/earlier-vm'; changeType = $ChangeType }
        { Submit-LocalBoxCapacityVM $state $entry $credential } | Should -Throw '*submission failed*'
        $entry.SubmissionError | Should -Match 'ARM what-if'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'rejects duplicate create entries instead of accepting a missing resource' {
        $preview.changes[2] = $preview.changes[0]
        { Submit-LocalBoxCapacityVM $state $entry $credential } | Should -Throw '*submission failed*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'redacts CLI errors and cleans credential files on failure' {
        Mock Invoke-LocalBoxAz {
            $paths.Add($Arguments[$Arguments.IndexOf('--parameters') + 1].Substring(1))
            throw 'Mock!Password9-not-real'
        }
        try { Submit-LocalBoxCapacityVM $state $entry $credential; throw 'Expected failure' }
        catch {
            $_.Exception.Message | Should -Match 'CLI details are withheld'
            $_.Exception.Message | Should -Not -Match 'Mock!Password9-not-real'
        }
        foreach ($path in $paths) { Test-Path -LiteralPath $path | Should -BeFalse }
    }
}

Describe 'Health runner defaults and feedback' {
    BeforeAll {
        function kubectl {}
    }
    It 'defaults to the home kubeconfig and downloads without side effects when dot-sourced' {
        Mock Invoke-WebRequest { throw 'Unexpected download' }
        . "$PSScriptRoot/../test-sovereign-cloud.ps1"
        $LocalBoxKubeconfig | Should -Be (Join-Path $HOME '.kube/config')
        [bool]$DownloadTests | Should -BeTrue
        Should -Invoke Invoke-WebRequest -Times 0
    }
    It 'accepts an explicit kubeconfig and disables downloads for a local checkout' {
        . "$PSScriptRoot/../test-sovereign-cloud.ps1" -LocalBoxKubeconfig 'custom.kubeconfig' -DownloadTests:$false
        $LocalBoxKubeconfig | Should -Be 'custom.kubeconfig'
        [bool]$DownloadTests | Should -BeFalse
    }
    It 'preserves inventory precedence and only applies the default to LocalBox scopes' -TestCases @(
        @{ TestScope = 'LocalBox'; Existing = 'inventory.kubeconfig'; Explicit = $false; Expected = 'inventory.kubeconfig' }
        @{ TestScope = 'All'; Existing = 'inventory.kubeconfig'; Explicit = $true; Expected = 'chosen.kubeconfig' }
        @{ TestScope = 'LocalBox'; Existing = $null; Explicit = $false; Expected = 'chosen.kubeconfig' }
        @{ TestScope = 'ParticipantLabs'; Existing = 'inventory.kubeconfig'; Explicit = $true; Expected = 'inventory.kubeconfig' }
        @{ TestScope = 'ParticipantLabs'; Existing = $null; Explicit = $false; Expected = $null }
    ) {
        param($TestScope, $Existing, $Explicit, $Expected)
        $ast = [Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../test-sovereign-cloud.ps1", [ref]$null, [ref]$null)
        $assignment = $ast.Find({ param($node)
            $node -is [Management.Automation.Language.IfStatementAst] -and
            $node.Clauses[0].Item1.Extent.Text -eq '$Scope -in @(''LocalBox'', ''All'') -and $inventory.LocalBox'
        }, $true)
        $assignment | Should -Not -BeNullOrEmpty
        $Scope = $TestScope
        $inventory = if ($TestScope -eq 'ParticipantLabs' -and -not $Existing) { @{ Labs = @() } } else { @{ LocalBox = @{ Kubeconfig = $Existing } } }
        $parameters = if ($Explicit) { @{ LocalBoxKubeconfig = 'chosen.kubeconfig' } } else { @{} }
        $resolve = [scriptblock]::Create('param([string]$LocalBoxKubeconfig = ''chosen.kubeconfig'')' + "`n" + $assignment.Extent.Text)
        & $resolve @parameters
        $inventory.LocalBox.Kubeconfig | Should -Be $Expected
        if ($TestScope -eq 'ParticipantLabs' -and -not $Existing) { $inventory.ContainsKey('LocalBox') | Should -BeFalse }
    }
    It 'reports the waiting condition and remaining time before retrying' {
        Mock Write-Host {}
        Mock Start-Sleep {}
        $attempts = @{ Count = 0 }
        $output = @(Wait-SovereignCheck -TimeoutSeconds 60 -Check {
            $attempts.Count++
            if ($attempts.Count -eq 1) { throw 'System pod kube-system/test-pod is not healthy.' }
        })
        $attempts.Count | Should -Be 2
        $output.Count | Should -Be 0
        Should -Invoke Write-Host -Times 1 -ParameterFilter {
            $Object -match 'attempt 1 not ready.*remaining; retry in 15s.*test-pod'
        }
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 15 }
    }
    It 'does not retry terminal authorization errors' {
        Mock Write-Host {}
        Mock Start-Sleep {}
        { Wait-SovereignCheck -Check { throw 'Forbidden: cannot list pods' } } | Should -Throw '*Forbidden*'
        Should -Invoke Start-Sleep -Times 0
        Should -Invoke Write-Host -Times 0
    }
    It 'throws the final failed condition at the timeout instead of claiming readiness' {
        Mock Write-Host {}
        Mock Start-Sleep {}
        { Wait-SovereignCheck -TimeoutSeconds 0 -Check { throw 'Deployment coredns is unavailable.' } } | Should -Throw '*coredns*'
        Should -Invoke Start-Sleep -Times 0
    }
    It 'shows the Kubernetes query without mixing progress into JSON results' {
        Mock Test-Path { $true }
        Mock Write-Host {}
        Mock kubectl {
            $global:LASTEXITCODE = 0
            '{"items":[{"metadata":{"name":"node-1"}}]}'
        }
        $result = @(Invoke-SovereignKubectl 'test.kubeconfig' @('get', 'nodes'))
        $result.Count | Should -Be 1
        $result[0].items[0].metadata.name | Should -Be 'node-1'
        Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -match 'Querying Kubernetes: kubectl get nodes.*20s' }
        Should -Invoke kubectl -Times 1 -ParameterFilter { $args -contains '--request-timeout=20s' -and $args -contains 'test.kubeconfig' }
    }
    It 'does not claim authentication when the default kubeconfig is absent' {
        Mock Test-Path { $false }
        Mock kubectl {}
        { Invoke-SovereignKubectl (Join-Path $HOME '.kube/config') @('get', 'nodes') } | Should -Throw '*independently authenticated*'
        Should -Invoke kubectl -Times 0
    }
}

Describe 'Console lab group credentials' {
    BeforeAll {
        function Get-MhhDefaultLabGroup { [CmdletBinding()] param() }
    }
    BeforeEach {
        Mock Get-MhhDefaultLabGroup {
            @{ ObjectId = 'a0000000-0000-0000-0000-000000000001'; GroupName = 'lab-group'; DisplayName = 'Test event' }
        }
    }
    It 'emits the three separate Console credential hashtables' {
        $credentials = @(Get-LocalBoxConsoleGroupCredential)
        $credentials.Count | Should -Be 3
        foreach ($credential in $credentials) {
            $credential | Should -BeOfType [hashtable]
            $credential.HackboxCredential | Should -BeOfType [hashtable]
        }
        $credentials[0].HackboxCredential.name | Should -Be 'Lab Group ObjectId'
        $credentials[0].HackboxCredential.value | Should -Be 'a0000000-0000-0000-0000-000000000001'
        $credentials[1].HackboxCredential.name | Should -Be 'Lab Group GroupName'
        $credentials[1].HackboxCredential.value | Should -Be 'lab-group'
        $credentials[2].HackboxCredential.name | Should -Be 'Lab Group DisplayName'
        $credentials[2].HackboxCredential.value | Should -Be 'Test event'
        Should -Invoke Get-MhhDefaultLabGroup -Times 1 -Exactly
    }
    It 'rejects incomplete or invalid group metadata before emitting anything' -TestCases @(
        @{ Group = $null }
        @{ Group = @{ ObjectId = 'not-a-guid'; GroupName = 'lab'; DisplayName = 'Event' } }
        @{ Group = @{ ObjectId = [guid]::Empty; GroupName = 'lab'; DisplayName = 'Event' } }
        @{ Group = @{ ObjectId = 'a0000000-0000-0000-0000-000000000001'; GroupName = ''; DisplayName = 'Event' } }
        @{ Group = @{ ObjectId = 'a0000000-0000-0000-0000-000000000001'; GroupName = 'lab'; DisplayName = '' } }
    ) {
        param($Group)
        Mock Get-MhhDefaultLabGroup { $Group }
        $captured = [System.Collections.Generic.List[object]]::new()
        { Get-LocalBoxConsoleGroupCredential | ForEach-Object { $captured.Add($_) } } | Should -Throw '*valid default lab group*'
        $captured.Count | Should -Be 0
    }
    It 'stops if the Console helper fails' {
        Mock Get-MhhDefaultLabGroup { throw 'Console unavailable' }
        { Get-LocalBoxConsoleGroupCredential } | Should -Throw '*Console unavailable*'
    }
}

Describe 'Console LocalBox credential isolation' {
    BeforeAll {
        function New-MhhStablePassword { [CmdletBinding()] param($Purpose, $Length) }
        function Update-MhhToken { [CmdletBinding()] param() }
        function Get-AzResourceGroupDeployment { [CmdletBinding()] param($ResourceGroupName, $Name) }
    }
    BeforeEach {
        $deployment = @{
            ProvisioningState = 'Succeeded'
        }
        Mock Update-MhhToken {}
        Mock Get-AzResourceGroupDeployment { $deployment }
        Mock New-MhhStablePassword { 'mock-password-not-a-secret' }
        Mock Start-Sleep {}
    }
    It 'emits no administrator credentials on success or reruns' {
        $first = @(Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test')
        $second = @(Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test')
        $first.Count | Should -Be 0
        $second.Count | Should -Be 0
        Should -Invoke New-MhhStablePassword -Times 0
        Should -Invoke Get-AzResourceGroupDeployment -Times 2 -Exactly -ParameterFilter { $ResourceGroupName -eq 'shared' -and $Name -eq 'localbox-test' }
    }
    It 'waits for ARM success and refreshes authentication before each check' {
        $deployment.ProvisioningState = 'Running'
        Mock Start-Sleep { $deployment.ProvisioningState = 'Succeeded' }
        @(Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test').Count | Should -Be 0
        Should -Invoke Update-MhhToken -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly
        Should -Invoke New-MhhStablePassword -Times 0
    }
    It 'does not publish passwords from failed or canceled deployments' -TestCases @(
        @{ State = 'Failed' }
        @{ State = 'Canceled' }
    ) {
        param($State)
        $deployment.ProvisioningState = $State
        { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' } | Should -Throw '*ended as*'
        Should -Invoke New-MhhStablePassword -Times 0
    }
    It 'times out without publishing a password' {
        $deployment.ProvisioningState = 'Running'
        $script:clock = [DateTime]'2026-01-01T00:00:00Z'
        Mock Get-Date {
            $script:clock = $script:clock.AddSeconds(2)
            $script:clock
        }
        { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' -TimeoutSeconds 1 } | Should -Throw '*Timed out*'
        Should -Invoke New-MhhStablePassword -Times 0
    }
    It 'propagates deployment lookup errors without publishing a password' {
        Mock Get-AzResourceGroupDeployment { throw 'Deployment lookup failed' }
        { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' } | Should -Throw '*Deployment lookup failed*'
        Should -Invoke New-MhhStablePassword -Times 0
    }
    It 'keeps group metadata and deployment checks without password publication in the shared hook' {
        $source = Get-Content "$PSScriptRoot/../../labautomation/shared-deploy-lab.ps1" -Raw
        $source | Should -Match '-UseConsoleCredentials'
        $source | Should -Match 'Get-LocalBoxConsoleGroupCredential'
        $source | Should -Match 'Wait-LocalBoxDeployment -ResourceGroupName \$localBoxResourceGroupName -DeploymentName \$localBoxDeployment.DeploymentName'
        $source | Should -Not -Match 'Get-LocalBoxConsoleCredential|LocalBox Admin Password|LocalBox Client Username'
        $helper = Get-Content "$PSScriptRoot/../../labautomation/localbox-credentials.ps1" -Raw
        $helper | Should -Not -Match 'New-MhhStablePassword|LocalBox Admin Password|LocalBox Client Username'
        $deployer = Get-Content "$PSScriptRoot/../../labautomation/deploy-localbox.ps1" -Raw
        $deployer | Should -Match "New-MhhStablePassword -Purpose 'localbox-admin-v1' -Length 24"
    }
}

Describe 'Console LocalBox password selection' {
    BeforeAll {
        function New-MhhStablePassword { [CmdletBinding()] param($Purpose, $Length) }
        $deployer = [System.Management.Automation.Language.Parser]::ParseFile(
            "$PSScriptRoot/../../labautomation/deploy-localbox.ps1", [ref]$null, [ref]$null)
        $selection = $deployer.Find({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
            $node.Clauses[0].Item1.Extent.Text -eq '$UseConsoleCredentials' -and
            $node.Extent.Text -match 'New-MhhStablePassword'
        }, $true)
        $passwordSelection = [scriptblock]::Create($selection.Extent.Text)
    }
    BeforeEach {
        $originalEnvironmentPassword = $env:LOCALBOX_ADMIN_PASSWORD
        $env:LOCALBOX_ADMIN_PASSWORD = $null
        $UseConsoleCredentials = $true
        $WindowsAdminPassword = $null
        Mock New-MhhStablePassword { 'mock-password-not-a-secret' }
    }
    AfterEach { $env:LOCALBOX_ADMIN_PASSWORD = $originalEnvironmentPassword }
    It 'assigns the stable password to the secure template input without emitting it' {
        $output = @(. $passwordSelection)
        $output.Count | Should -Be 0
        $WindowsAdminPassword | Should -Be 'mock-password-not-a-secret'
        Should -Invoke New-MhhStablePassword -Times 1 -Exactly -ParameterFilter { $Purpose -eq 'localbox-admin-v1' -and $Length -eq 24 }
    }
    It 'rejects competing explicit or environment passwords' -TestCases @(
        @{ Source = 'Parameter' }
        @{ Source = 'Environment' }
    ) {
        param($Source)
        if ($Source -eq 'Parameter') { $WindowsAdminPassword = 'mock-existing-password' }
        else { $env:LOCALBOX_ADMIN_PASSWORD = 'mock-existing-password' }
        { . $passwordSelection } | Should -Throw '*cannot be combined*'
        Should -Invoke New-MhhStablePassword -Times 0
    }
    It 'preserves manually supplied passwords outside Console' {
        $UseConsoleCredentials = $false
        $WindowsAdminPassword = 'mock-manual-password'
        . $passwordSelection
        $WindowsAdminPassword | Should -Be 'mock-manual-password'
        Should -Invoke New-MhhStablePassword -Times 0
    }
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
        $source | Should -Match "(?s)resource confidentialNodePool .*?properties: \{\s+count: 2\s+tags: tags"
    }
}

Describe 'Nested LocalBox credential resolution' {
    It 'constructs only a credential from the installed configuration without printing secrets' {
        $configuration = @{ SDNDomainFQDN = 'jumpstart.local'; SDNAdminPassword = 'mock-config-password' }
        $output = @(Resolve-LocalBoxNodeCredential -Configuration $configuration *>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [pscredential]
        $output[0].UserName | Should -Be 'jumpstart\Administrator'
        $output[0].GetNetworkCredential().Password | Should -Be 'mock-config-password'
    }
    It 'uses the configured domain rather than a hardcoded account' {
        $credential = Resolve-LocalBoxNodeCredential -Configuration @{ SDNDomainFQDN = 'event.example.test'; SDNAdminPassword = 'mock-config-password' }
        $credential.UserName | Should -Be 'event\Administrator'
    }
    It 'preserves an explicit credential even when configuration credentials are missing' {
        $explicit = [pscredential]::new('custom\operator', [Security.SecureString]::new())
        $actual = Resolve-LocalBoxNodeCredential -Configuration @{} -Credential $explicit
        [object]::ReferenceEquals($actual, $explicit) | Should -BeTrue
    }
    It 'fails without exposing configuration values when credentials are missing or invalid' -TestCases @(
        @{ Configuration = @{} }
        @{ Configuration = @{ SDNDomainFQDN = 'jumpstart.local'; SDNAdminPassword = '' } }
        @{ Configuration = @{ SDNDomainFQDN = '.local'; SDNAdminPassword = 'mock-config-password' } }
        @{ Configuration = @{ SDNDomainFQDN = 'invalid\domain'; SDNAdminPassword = 'mock-config-password' } }
    ) {
        param($Configuration)
        { Resolve-LocalBoxNodeCredential -Configuration $Configuration } | Should -Throw '*Supply -NodeCredential*'
        try { Resolve-LocalBoxNodeCredential -Configuration $Configuration }
        catch { $_.ToString() | Should -Not -Match 'mock-config-password' }
    }
    It 'uses the resolver during preparation without an unconditional credential prompt' {
        ${function:Invoke-LocalBoxPreparation}.ToString() | Should -Match 'Resolve-LocalBoxNodeCredential -Configuration \$config -Credential \$Settings.NodeCredential'
        ${function:Invoke-LocalBoxPreparation}.ToString() | Should -Not -Match 'Get-Credential'
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

Describe 'AKS Local Arc proxy RBAC' {
    BeforeEach {
        $clusterId = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks'
        $groupId = 'a0000000-0000-0000-0000-000000000001'
        $roleId = '/subscriptions/test/providers/Microsoft.Authorization/roleDefinitions/00493d72-78f6-4148-b6c5-d3ce8e4799dd'
        $assignment = @{ scope = $clusterId; principalId = $groupId; principalType = 'Group'; roleDefinitionId = $roleId }
        Mock Invoke-LocalBoxAz { @() }
        Mock Invoke-LocalBoxAz { $assignment } -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'creates only the group proxy role at connected-cluster scope without Graph lookups' {
        Sync-LocalBoxAksProxyRole $clusterId $groupId
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments[2] -eq 'list' -and $Arguments -contains '--include-inherited' -and
            $Arguments[$Arguments.IndexOf('--fill-principal-name') + 1] -eq 'false' -and
            $Arguments[$Arguments.IndexOf('--fill-role-definition-name') + 1] -eq 'false'
        }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments[2] -eq 'create' -and $Arguments -contains '--assignee-object-id' -and $Arguments -notcontains '--assignee' -and
            $Arguments[$Arguments.IndexOf('--assignee-object-id') + 1] -eq $groupId -and
            $Arguments[$Arguments.IndexOf('--assignee-principal-type') + 1] -eq 'Group' -and
            $Arguments[$Arguments.IndexOf('--scope') + 1] -eq $clusterId -and
            $Arguments[$Arguments.IndexOf('--role') + 1] -eq $roleId -and
            $Arguments[$Arguments.IndexOf('--subscription') + 1] -eq 'test' -and
            $Arguments[$Arguments.IndexOf('--name') + 1] -match '^[0-9a-f-]{36}$'
        }
    }
    It 'reuses direct and inherited grants without writes' -TestCases @(
        @{ AssignmentScope = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks' }
        @{ AssignmentScope = '/subscriptions/test/resourceGroups/localbox' }
        @{ AssignmentScope = '/subscriptions/test' }
    ) {
        param($AssignmentScope)
        $assignment.scope = $AssignmentScope.ToUpperInvariant()
        Mock Invoke-LocalBoxAz { @($assignment) } -ParameterFilter { $Arguments[2] -eq 'list' }
        Sync-LocalBoxAksProxyRole $clusterId $groupId
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'does not accept a grant for another group, role or resource' -TestCases @(
        @{ Property = 'principalId'; Value = 'b0000000-0000-0000-0000-000000000002' }
        @{ Property = 'roleDefinitionId'; Value = '/subscriptions/test/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000001' }
        @{ Property = 'scope'; Value = '/subscriptions/test/resourceGroups/other' }
    ) {
        param($Property, $Value)
        $other = $assignment.Clone()
        $other[$Property] = $Value
        Mock Invoke-LocalBoxAz { @($other) } -ParameterFilter { $Arguments[2] -eq 'list' }
        Sync-LocalBoxAksProxyRole $clusterId $groupId
        Should -Invoke Invoke-LocalBoxAz -Times 1 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'uses a stable assignment name on retries regardless of ID casing' {
        $names = [Collections.Generic.List[string]]::new()
        Mock Invoke-LocalBoxAz {
            $names.Add($Arguments[$Arguments.IndexOf('--name') + 1])
            $assignment
        } -ParameterFilter { $Arguments[2] -eq 'create' }
        Sync-LocalBoxAksProxyRole $clusterId $groupId
        Sync-LocalBoxAksProxyRole $clusterId.ToUpperInvariant() $groupId.ToUpperInvariant()
        $names.Count | Should -Be 2
        $names[0] | Should -Be $names[1]
    }
    It 'does not query or create RBAC in WhatIf even before the cluster exists' {
        Sync-LocalBoxAksProxyRole $clusterId $groupId -WhatIf
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects resource-group scope and malformed groups before CLI calls' {
        { Sync-LocalBoxAksProxyRole '/subscriptions/test/resourceGroups/localbox' $groupId } | Should -Throw '*connected-cluster*'
        { Sync-LocalBoxAksProxyRole $clusterId 'not-a-group-id' } | Should -Throw '*object ID*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'does not replace or bypass an existing conditional grant' -TestCases @(
        @{ AssignmentScope = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks' }
        @{ AssignmentScope = '/subscriptions/test/resourceGroups/localbox' }
    ) {
        param($AssignmentScope)
        $assignment.scope = $AssignmentScope
        $assignment.condition = 'restricted'
        Mock Invoke-LocalBoxAz { @($assignment) } -ParameterFilter { $Arguments[2] -eq 'list' }
        { Sync-LocalBoxAksProxyRole $clusterId $groupId } | Should -Throw '*will not replace*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'stops on read authorization failures without attempting creation' {
        Mock Invoke-LocalBoxAz { throw 'AuthorizationFailed' } -ParameterFilter { $Arguments[2] -eq 'list' }
        { Sync-LocalBoxAksProxyRole $clusterId $groupId } | Should -Throw '*roleAssignments/read*AuthorizationFailed*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'create' }
    }
    It 'reports missing write permission without elevating the managed identity' {
        Mock Invoke-LocalBoxAz { throw 'AuthorizationFailed' } -ParameterFilter { $Arguments[2] -eq 'create' }
        { Sync-LocalBoxAksProxyRole $clusterId $groupId } | Should -Throw '*roleAssignments/write*does not elevate*AuthorizationFailed*'
        Should -Invoke Invoke-LocalBoxAz -Times 2 -Exactly
    }
    It 'rejects an empty or mismatched creation response' -TestCases @(
        @{ Response = $null }
        @{ Response = @{ scope = '/subscriptions/test/resourceGroups/localbox' } }
    ) {
        param($Response)
        Mock Invoke-LocalBoxAz { $Response } -ParameterFilter { $Arguments[2] -eq 'create' }
        { Sync-LocalBoxAksProxyRole $clusterId $groupId } | Should -Throw
    }
    It 'wires reconciliation for existing and new AKS clusters but skips it with SkipAks' {
        $ast = [Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../prepare-localbox.ps1", [ref]$null, [ref]$null)
        $guard = $ast.Find({ param($node)
            $node -is [Management.Automation.Language.IfStatementAst] -and
            $node.Clauses[0].Item1.Extent.Text -eq '-not $Settings.SkipAks'
        }, $true)
        $guard | Should -Not -BeNullOrEmpty
        $reconcile = [scriptblock]::Create($guard.Extent.Text)
        $aksId = $clusterId
        $Settings = @{ SkipAks = $true }
        Mock Sync-LocalBoxAksProxyRole {}
        & $reconcile
        Should -Invoke Sync-LocalBoxAksProxyRole -Times 0
        $Settings.SkipAks = $false
        & $reconcile
        Should -Invoke Sync-LocalBoxAksProxyRole -Times 1 -Exactly -ParameterFilter { $ClusterId -eq $aksId -and $GroupObjectId -eq $groupId }
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

Describe 'LocalBox image storage conflicts' {
    BeforeEach {
        $scope = '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.AzureStackHCI'
        $imageName = '2025-datacenter-azure-edition-smalldisk-01'
        $imageId = "$scope/marketplaceGalleryImages/$imageName"
        $storageId = "$scope/storageContainers/UserStorage1-generated"
        $resources = @(@{ id = $imageId })
        Mock Get-LocalBoxResource { @{ properties = @{ containerId = "$scope/storageContainers/UserStorage2-generated" } } }
        Mock Invoke-LocalBoxAz { $resources }
    }
    It 'rejects an existing image on secondary storage even in WhatIf with actionable guidance' {
        $WhatIfPreference = $true
        { Assert-LocalBoxImagePlacement -Resources $resources -ImageId $imageId -StorageId $storageId } | Should -Throw '*review image dependencies*documented image name*never deleted or moved automatically*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'accepts matching storage IDs case-insensitively without writes' {
        Mock Get-LocalBoxResource { @{ properties = @{ containerId = $storageId.ToUpperInvariant() } } }
        { Assert-LocalBoxImagePlacement -Resources $resources -ImageId $imageId -StorageId $storageId } | Should -Not -Throw
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects missing placement instead of assuming primary storage' {
        Mock Get-LocalBoxResource { @{ properties = @{} } }
        { Assert-LocalBoxImagePlacement -Resources $resources -ImageId $imageId -StorageId $storageId } | Should -Throw '*preparation requires*'
    }
    It 'permits the documented image when it does not yet exist without writes' {
        Assert-LocalBoxImagePlacement -Resources @() -ImageId $imageId -StorageId $storageId
        Should -Invoke Get-LocalBoxResource -Times 0
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'checks placement before storage mutations' {
        $source = ${function:Invoke-LocalBoxPreparation}.ToString()
        $source.IndexOf('Assert-LocalBoxImagePlacement -Resources') | Should -BeGreaterOrEqual 0
        $source.IndexOf('Assert-LocalBoxImagePlacement -Resources') | Should -BeLessThan $source.IndexOf('Initialize-LocalBoxStorage -Configuration')
    }
    It 'creates the documented image on primary storage when it does not yet exist' {
        Mock Invoke-LocalBoxAz { @() }
        $expected = @{ properties = @{ containerId = $storageId } }
        Mock Wait-LocalBoxResource { $expected }
        Sync-LocalBoxResource -Id $imageId -Expected $expected -CreateArguments @('stack-hci-vm', 'image', 'create', '--name', $imageName, '--storage-path-id', $storageId) | Out-Null
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments[2] -eq 'create' -and $Arguments -contains $imageName -and $Arguments -contains $storageId
        }
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'delete' -or $Arguments -contains 'update' }
        Should -Invoke Wait-LocalBoxResource -Times 1 -Exactly -ParameterFilter { $Id -eq $imageId }
    }
    It 'does not import the documented image during WhatIf' {
        Mock Invoke-LocalBoxAz { @() }
        Sync-LocalBoxResource -Id $imageId -Expected @{ properties = @{ containerId = $storageId } } `
            -CreateArguments @('stack-hci-vm', 'image', 'create') -WhatIf
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains 'create' }
    }
}
Describe 'CLI output streams' {
    BeforeEach {
        $script:cliTestExecutable = (Get-Process -Id $PID).Path
        Mock Get-LocalBoxAzInvocation {
            @{ Executable = $script:cliTestExecutable; Prefix = @('-NoProfile', '-NonInteractive', '-Command', ($script:cliTestCommand + "`n#")) }
        }
    }
    It 'parses JSON stdout when a successful native command also writes progress to stderr' {
        $script:cliTestCommand = {
            [Console]::Error.WriteLine('Progress: completing operation')
            [Console]::Out.WriteLine('{"name":"ready"}')
            exit 0
        }.ToString()
        (Invoke-LocalBoxAz @('resource', 'show')).name | Should -Be 'ready'
    }
    It 'parses array output without stderr records leaking into resource discovery' {
        $script:cliTestCommand = {
            [Console]::Error.WriteLine('Progress: completing discovery')
            [Console]::Out.WriteLine('[{"name":"first"},{"name":"second"}]')
            exit 0
        }.ToString()
        $result = @(Invoke-LocalBoxAz @('resource', 'list'))
        $result.Count | Should -Be 2
        $result[0].name | Should -Be 'first'
        $result[1].name | Should -Be 'second'
    }
    It 'accepts empty successful stdout without leaking stderr into results' {
        $script:cliTestCommand = {
            [Console]::Error.WriteLine('Progress: completing operation')
            exit 0
        }.ToString()
        @(Invoke-LocalBoxAz @('account', 'set')).Count | Should -Be 0
    }
    It 'accepts a first-use notice with no JSON for an exit-code-only validation command' {
        $script:cliTestCommand = {
            [Console]::Out.WriteLine('Privacy notice: first invocation')
            exit 0
        }.ToString()
        @(Invoke-LocalBoxAz @('aksarc', 'create', '--validate') -NoOutput).Count | Should -Be 0
    }
    It 'discards notice and JSON output when creation results are checked through ARM reads' {
        $script:cliTestCommand = {
            [Console]::Out.WriteLine('Privacy notice: first invocation')
            [Console]::Out.WriteLine('{"name":"cluster"}')
            exit 0
        }.ToString()
        @(Invoke-LocalBoxAz @('aksarc', 'create') -NoOutput).Count | Should -Be 0
    }
    It 'rejects a failed exit-code-only command and retains command context and stderr' {
        $script:cliTestCommand = {
            [Console]::Out.WriteLine('Privacy notice: first invocation')
            [Console]::Error.WriteLine('AuthorizationFailed: test failure')
            exit 17
        }.ToString()
        { Invoke-LocalBoxAz @('aksarc', 'create', '--validate') -NoOutput } | Should -Throw '*az aksarc create --validate*exit code 17*AuthorizationFailed*'
    }
    It 'rejects a nonzero exit even when stdout contains valid JSON' {
        $script:cliTestCommand = {
            [Console]::Out.WriteLine('{"name":"not-success"}')
            [Console]::Error.WriteLine('Resource read failed')
            exit 9
        }.ToString()
        { Invoke-LocalBoxAz @('resource', 'show') } | Should -Throw '*az resource show*exit code 9*Resource read failed*'
    }
    It 'rejects malformed read output with context but without exposing raw stdout' {
        $script:cliTestCommand = {
            [Console]::Out.WriteLine('mock-sensitive-payload')
            exit 0
        }.ToString()
        $failure = $null
        try { Invoke-LocalBoxAz @('resource', 'show') }
        catch { $failure = $_ }
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'az resource show.*non-JSON stdout'
        $failure.Exception.Message | Should -Not -Match 'mock-sensitive-payload'
        $failure.Exception.Message | Should -Match 'Inspect the resource state before retrying'
    }
    It 'limits non-JSON handling to AKS validate and create while retaining ARM verification' {
        $source = ${function:Invoke-LocalBoxPreparation}.ToString()
        $source | Should -Match 'Invoke-LocalBoxAz \(\$arguments \+ @\(''--validate''\)\) -TimeoutSeconds \$timeout -NoOutput'
        $source | Should -Match 'Invoke-LocalBoxAz \$arguments -TimeoutSeconds \$timeout -NoOutput'
        $source | Should -Match 'Wait-LocalBoxResource \$instanceId'
        $source | Should -Match 'Assert-LocalBoxProperties \$instance \$aksExpected'
        $source | Should -Match 'Assert-LocalBoxProperties \$connected'
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

Describe 'Missing CLI extension installation' {
    BeforeEach {
        Mock Invoke-LocalBoxAz {
            if ($Arguments[1] -eq 'list') { return @(@{ name = 'customlocation'; version = '0.1.4' }) }
            if ($Arguments[1] -eq 'show') { return @{ name = $Arguments[3]; version = '1.0.0' } }
        }
    }
    It 'installs only missing extensions and verifies all required versions' {
        Initialize-LocalBoxCliExtension | Should -BeTrue
        Should -Invoke Invoke-LocalBoxAz -Times 2 -Exactly -ParameterFilter { $Arguments[1] -eq 'add' }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[1] -eq 'add' -and $Arguments[3] -eq 'stack-hci-vm' }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter { $Arguments[1] -eq 'add' -and $Arguments[3] -eq 'aksarc' }
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'add' -and $Arguments[3] -eq 'customlocation' }
        Should -Invoke Invoke-LocalBoxAz -Times 3 -Exactly -ParameterFilter { $Arguments[1] -eq 'show' }
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments -contains '--upgrade' -or $Arguments[1] -eq 'update' }
    }
    It 'leaves an already prepared Client unchanged' {
        Mock Invoke-LocalBoxAz { @(@{ name = 'stack-hci-vm' }, @{ name = 'customlocation' }, @{ name = 'aksarc' }) } -ParameterFilter { $Arguments[1] -eq 'list' }
        Initialize-LocalBoxCliExtension | Should -BeTrue
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'add' }
    }
    It 'installs all required extensions on a fresh Client' {
        Mock Invoke-LocalBoxAz { @() } -ParameterFilter { $Arguments[1] -eq 'list' }
        Initialize-LocalBoxCliExtension | Should -BeTrue
        Should -Invoke Invoke-LocalBoxAz -Times 3 -Exactly -ParameterFilter { $Arguments[1] -eq 'add' -and $TimeoutSeconds -eq 900 }
    }
    It 'honors helper-level WhatIf when the preparation override is not applied' {
        Initialize-LocalBoxCliExtension -WhatIf | Should -BeFalse
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'add' }
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'show' -and $Arguments[3] -in @('stack-hci-vm', 'aksarc') }
    }
    It 'installs missing prerequisites under inherited WhatIf without allowing resource creation' {
        $WhatIfPreference = $true
        Initialize-LocalBoxCliExtension -WhatIf:$false | Should -BeTrue
        $WhatIfPreference | Should -BeTrue
        Sync-LocalBoxResource -Id '/subscriptions/test/resourceGroups/localbox/providers/Microsoft.AzureStackHCI/logicalNetworks/test-net' `
            -Expected @{} -CreateArguments @('resource', 'create')
        Should -Invoke Invoke-LocalBoxAz -Times 2 -Exactly -ParameterFilter { $Arguments[0] -eq 'extension' -and $Arguments[1] -eq 'add' }
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[0] -eq 'resource' -and $Arguments[1] -eq 'create' }
    }
    It 'limits the preparation WhatIf exception to the extension-setup call' {
        ${function:Invoke-LocalBoxPreparation}.ToString() | Should -Match 'Initialize-LocalBoxCliExtension -WhatIf:\$false'
        ${function:Invoke-LocalBoxPreparation}.ToString() | Should -Not -Match '\$WhatIfPreference\s*=\s*\$false'
    }
    It 'allows a complete dry run when all required extensions already exist' {
        Mock Invoke-LocalBoxAz { @(@{ name = 'stack-hci-vm' }, @{ name = 'customlocation' }, @{ name = 'aksarc' }) } -ParameterFilter { $Arguments[1] -eq 'list' }
        Initialize-LocalBoxCliExtension -WhatIf | Should -BeTrue
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'add' }
    }
    It 'propagates discovery errors rather than assuming extensions are missing' {
        Mock Invoke-LocalBoxAz { throw 'Extension directory cannot be read' } -ParameterFilter { $Arguments[1] -eq 'list' }
        { Initialize-LocalBoxCliExtension } | Should -Throw '*cannot be read*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'add' }
    }
    It 'stops after a failed installation' {
        Mock Invoke-LocalBoxAz { throw 'Download failed' } -ParameterFilter { $Arguments[1] -eq 'add' }
        { Initialize-LocalBoxCliExtension } | Should -Throw '*Download failed*'
        Should -Invoke Invoke-LocalBoxAz -Times 0 -ParameterFilter { $Arguments[1] -eq 'show' }
    }
    It 'rejects an installation that cannot be verified' {
        Mock Invoke-LocalBoxAz { @{ name = 'stack-hci-vm' } } -ParameterFilter { $Arguments[1] -eq 'show' }
        { Initialize-LocalBoxCliExtension } | Should -Throw '*could not be verified*'
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

Describe 'Kubernetes DaemonSet readiness' {
    BeforeEach {
        $controllers = @{ items = @(
            @{ kind = 'DaemonSet'; metadata = @{ name = 'calico-node' }; status = @{ desiredNumberScheduled = 4; numberReady = 4 } }
            @{ kind = 'DaemonSet'; metadata = @{ name = 'calico-node-windows' }; spec = @{ template = @{ spec = @{ nodeSelector = @{ 'kubernetes.io/os' = 'windows' } } } }; status = @{ desiredNumberScheduled = 0; numberReady = 0 } }
            @{ kind = 'Deployment'; metadata = @{ name = 'coredns' }; spec = @{ replicas = 2 }; status = @{ availableReplicas = 2 } }
        ) }
        Mock Invoke-SovereignKubectl {
            switch ($Arguments[1]) {
                'nodes' { return @{ items = @(@{ metadata = @{ name = 'linux-node' }; status = @{ conditions = @(@{ type = 'Ready'; status = 'True' }) } }) } }
                'pods' { return @{ items = @(@{ metadata = @{ name = 'calico-node-pod'; namespace = 'kube-system' }; status = @{ phase = 'Running'; conditions = @(@{ type = 'Ready'; status = 'True' }); containerStatuses = @(@{ name = 'calico-node'; ready = $true; state = @{ running = @{} } }) } }) } }
                'deployments,daemonsets' { return $controllers }
                default { throw 'Unexpected query' }
            }
        }
    }
    It 'accepts healthy Linux controllers alongside a Windows DaemonSet with no eligible nodes' {
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Not -Throw
    }
    It 'uses scheduling counts rather than a special case for Windows controller names' {
        $controllers.items[1].metadata.name = 'optional-agent'
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Not -Throw
    }
    It 'fails when a Linux DaemonSet is missing a Ready pod' {
        $controllers.items[0].status.numberReady = 3
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Throw '*calico-node is unavailable (3 Ready / 4 desired)*'
    }
    It 'fails when a Windows DaemonSet has eligible nodes but no Ready pods' {
        $controllers.items[1].status.desiredNumberScheduled = 1
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Throw '*calico-node-windows is unavailable (0 Ready / 1 desired)*'
    }
    It 'does not treat missing or invalid status as zero desired pods' -TestCases @(
        @{ Status = @{} }
        @{ Status = @{ desiredNumberScheduled = 0 } }
        @{ Status = @{ numberReady = 0 } }
        @{ Status = @{ desiredNumberScheduled = -1; numberReady = 0 } }
        @{ Status = @{ desiredNumberScheduled = 0; numberReady = -1 } }
    ) {
        param($Status)
        $controllers.items[1].status = $Status
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Throw '*missing or invalid scheduling status*'
    }
    It 'still fails an unavailable deployment alongside a zero-target DaemonSet' {
        $controllers.items[2].status.availableReplicas = 1
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Throw '*Deployment coredns is unavailable*'
    }
    It 'still rejects an empty controller collection' {
        $controllers.items = @()
        { Test-SovereignKubernetes 'test.kubeconfig' 1 } | Should -Throw '*No kube-system controllers found*'
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