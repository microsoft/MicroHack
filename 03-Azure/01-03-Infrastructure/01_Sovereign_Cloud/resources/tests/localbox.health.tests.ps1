param([hashtable]$LocalBox, [pscredential]$NodeCredential, [string]$Mode, [int]$TimeoutSeconds, [string]$ResourceRoot)

BeforeAll {
    . "$ResourceRoot/prepare-localbox.ps1" -NodeCredential $NodeCredential
    . "$ResourceRoot/test-sovereign-cloud.ps1" -NodeCredential $NodeCredential -Mode $Mode
}

Describe 'Shared LocalBox control plane' {
    It 'has all mandatory manifest fields' {
        $LocalBox.AksPreparationSkipped | Should -Not -BeTrue -Because 'a partial preparation is not full LocalBox readiness'
        foreach ($field in @('SubscriptionId', 'ResourceGroupName', 'ClusterId', 'BridgeId', 'ExtensionId', 'CustomLocationId', 'StorageId', 'ImageId', 'AksId', 'AksInstanceId', 'AksAdminGroupObjectId', 'ImageExpected', 'AksExpected', 'NodeNames', 'StorageSizeGB')) {
            $LocalBox[$field] | Should -Not -BeNullOrEmpty -Because "$field is part of the expected inventory"
        }
        @($LocalBox.Networks).Count | Should -Be 2
    }
    It 'has a running Client with managed identity and successful bootstrap' {
        $hostVm = Invoke-LocalBoxAz @('vm', 'get-instance-view', '--subscription', $LocalBox.SubscriptionId, '--resource-group', $LocalBox.ResourceGroupName, '--name', 'LocalBox-Client')
        $hostVm.instanceView.statuses.code | Should -Contain 'PowerState/running'
        $hostVm.identity.principalId | Should -Not -BeNullOrEmpty
        $bootstrap = Invoke-LocalBoxAz @('vm', 'extension', 'show', '--subscription', $LocalBox.SubscriptionId, '--resource-group', $LocalBox.ResourceGroupName, '--vm-name', 'LocalBox-Client', '--name', 'Bootstrap')
        $bootstrap.provisioningState | Should -Be 'Succeeded'
    }
    It 'has provisioned connected Azure Local and a running Arc bridge' {
        $cluster = Wait-LocalBoxResource $LocalBox.ClusterId -TimeoutSeconds $TimeoutSeconds
        $cluster.properties.connectivityStatus | Should -Be 'Connected'
        $bridge = Wait-LocalBoxResource $LocalBox.BridgeId -TimeoutSeconds $TimeoutSeconds
        $bridge.properties.status | Should -Be 'Running'
        Wait-LocalBoxResource $LocalBox.CustomLocationId -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty
        Wait-LocalBoxResource $LocalBox.ExtensionId -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty
    }
    It 'has a ready image on the expected storage path' {
        Wait-LocalBoxResource $LocalBox.StorageId -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty
        $image = Wait-LocalBoxResource $LocalBox.ImageId -TimeoutSeconds $TimeoutSeconds
        Assert-LocalBoxProperties $image $LocalBox.ImageExpected
        $image.properties.status.progressPercentage | Should -Be 100
    }
    It 'has two matching logical networks with valid static pools' {
        @($LocalBox.Networks).Count | Should -Be 2
        foreach ($network in $LocalBox.Networks) {
            Test-LocalBoxAddressPool $network.Prefix $network.Start $network.End $network.Gateway
            $actual = Wait-LocalBoxResource $network.Id -TimeoutSeconds $TimeoutSeconds
            Assert-LocalBoxProperties $actual $network.Expected
        }
        $LocalBox.Networks[0].Vlan | Should -Not -Be $LocalBox.Networks[1].Vlan
        $LocalBox.Networks[0].Prefix | Should -Not -Be $LocalBox.Networks[1].Prefix
    }
    It 'has the expected AKS cluster, admin group and Arc connection' {
        $instance = Wait-LocalBoxResource $LocalBox.AksInstanceId -TimeoutSeconds $TimeoutSeconds
        Assert-LocalBoxProperties $instance $LocalBox.AksExpected
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check {
            $cluster = Get-LocalBoxResource $LocalBox.AksId
            $cluster.properties.connectivityStatus | Should -Be 'Connected'
            Assert-LocalBoxProperties $cluster @{ properties = @{ aadProfile = @{ adminGroupObjectIDs = @($LocalBox.AksAdminGroupObjectId) } } }
        }
    }
    It 'has healthy supporting Azure resources' {
        $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $LocalBox.SubscriptionId, '--resource-group', $LocalBox.ResourceGroupName))
        foreach ($type in @('Microsoft.Network/virtualNetworks', 'Microsoft.Network/networkInterfaces', 'Microsoft.Storage/storageAccounts', 'Microsoft.OperationalInsights/workspaces')) {
            $selected = @($resources | Where-Object type -ieq $type)
            $selected.Count | Should -BeGreaterThan 0 -Because "$type must exist"
            foreach ($resource in $selected) { Wait-LocalBoxResource $resource.id -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty }
        }
    }
}

Describe 'LocalBox runtime health' -Skip:($Mode -ne 'Full') {
    It 'has running healthy nested nodes and sufficient storage' {
        $IsWindows | Should -BeTrue -Because 'Full LocalBox tests run on LocalBox-Client'
        $NodeCredential | Should -Not -BeNullOrEmpty -Because 'Windows guest access is separate from managed identity'
        foreach ($node in $LocalBox.NodeNames) {
            (Get-VM -Name $node -ErrorAction Stop).State | Should -Be 'Running'
            $state = Get-LocalBoxNodeState $node $NodeCredential
            $state.NodesUp | Should -BeTrue
            $state.PoolHealth | Should -Be 'Healthy'
            $state.DiskHealth | Should -Be 'Healthy'
            $state.VolumeHealth | Should -Be 'Healthy'
            $state.StorageJobs | Should -Be 0
            $state.UnhealthyPhysicalDisks | Should -Be 0
            $state.Size | Should -BeGreaterOrEqual ($LocalBox.StorageSizeGB * 1GB)
            $state.Free | Should -BeGreaterOrEqual 100GB
        }
    }
    It 'allows the supplied AKS kubeconfig to query the expected ready workers, control plane and system workloads' {
        $workers = [int]$LocalBox.AksExpected.properties.agentPoolProfiles[0].count
        $controlPlane = [int]$LocalBox.AksExpected.properties.controlPlane.count
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check {
            Assert-SovereignLocalNodeCount (Invoke-SovereignKubectl $LocalBox.Kubeconfig @('get', 'nodes')) $workers $controlPlane
            Test-SovereignKubernetes $LocalBox.Kubeconfig ($workers + $controlPlane)
        }
    }
    It 'can resolve Azure and reach configured gateways from the nested environment' {
        $NodeCredential | Should -Not -BeNullOrEmpty
        $result = Invoke-Command -VMName $LocalBox.NodeNames[0] -Credential $NodeCredential -ArgumentList (, $LocalBox.Networks) -ErrorAction Stop -ScriptBlock {
            param($Networks)
            $ErrorActionPreference = 'Stop'
            Resolve-DnsName management.azure.com -ErrorAction Stop | Out-Null
            foreach ($network in $Networks) {
                if (-not (Test-Connection -ComputerName $network.Gateway -Count 2 -Quiet)) { throw "Gateway $($network.Gateway) is unreachable." }
            }
            (Invoke-WebRequest 'https://management.azure.com/metadata/endpoints?api-version=2020-06-01' -UseBasicParsing -TimeoutSec 30).StatusCode
        }
        $result | Should -Be 200
    }
}