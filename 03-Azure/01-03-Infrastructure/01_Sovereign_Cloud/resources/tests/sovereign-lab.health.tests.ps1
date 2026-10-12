param([hashtable]$Lab, [string]$Mode, [int]$TimeoutSeconds, [string]$ResourceRoot, [bool]$AllowGuestRunCommand)

BeforeAll {
    . "$ResourceRoot/prepare-localbox.ps1"
    . "$ResourceRoot/test-sovereign-cloud.ps1" -Mode $Mode -AllowGuestRunCommand:$AllowGuestRunCommand
    $outputs = Get-SovereignLabOutputs $Lab
    foreach ($required in @('aksClusterName', 'confidentialNodePoolName', 'k3sVmName', 'k3sInstallStatusResource', 'bastionName', 'natEgressIp')) {
        if (-not $outputs[$required]) { throw "Missing deployment output $required." }
    }
    $scopeId = "/subscriptions/$($Lab.SubscriptionId)/resourceGroups/$($Lab.ResourceGroupName)"
    $common = @('--subscription', $Lab.SubscriptionId, '--resource-group', $Lab.ResourceGroupName)
    $resources = @(Invoke-LocalBoxAz (@('resource', 'list') + $common))
}

Describe 'Participant lab control plane' {
    It 'has a running K3s VM with a healthy agent' {
        foreach ($name in @($outputs.k3sVmName)) {
            $vm = Invoke-LocalBoxAz (@('vm', 'get-instance-view', '--name', $name) + $common)
            $vm.provisioningState | Should -Be 'Succeeded'
            $vm.instanceView.statuses.code | Should -Contain 'PowerState/running'
            $vm.instanceView.vmAgent.statuses.code | Should -Contain 'ProvisioningState/succeeded'
        }
    }
    It 'has completed the K3s install extension' {
        Wait-LocalBoxResource $outputs.k3sInstallStatusResource -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty
    }
    It 'has the Azure AKS platform and confidential pool specified by the template' {
        $aksId = "$scopeId/providers/Microsoft.ContainerService/managedClusters/$($outputs.aksClusterName)"
        $aks = Wait-LocalBoxResource $aksId -TimeoutSeconds $TimeoutSeconds
        $aks.properties.enableRBAC | Should -BeTrue
        $aks.properties.oidcIssuerProfile.enabled | Should -BeTrue
        $aks.properties.securityProfile.workloadIdentity.enabled | Should -BeTrue
        $aks.properties.serviceMeshProfile.mode | Should -Be 'Istio'
        $aks.properties.networkProfile.networkPluginMode | Should -Be 'overlay'
        $aks.properties.autoUpgradeProfile.upgradeChannel | Should -Be 'stable'
        $aks.properties.autoUpgradeProfile.nodeOSUpgradeChannel | Should -Be 'NodeImage'
        $system = Wait-LocalBoxResource "$aksId/agentPools/system" -TimeoutSeconds $TimeoutSeconds
        $system.properties.count | Should -Be 2
        $system.properties.mode | Should -Be 'System'
        $system.properties.vmSize | Should -Be 'Standard_D4s_v5'
        $pool = Wait-LocalBoxResource "$aksId/agentPools/$($outputs.confidentialNodePoolName)" -TimeoutSeconds $TimeoutSeconds
        $pool.properties.count | Should -Be 2
        $pool.properties.osSKU | Should -Be 'Ubuntu'
        $pool.properties.mode | Should -Be 'User'
        $pool.properties.nodeLabels.workload | Should -Be 'confidential'
        $pool.properties.vmSize | Should -Match '^Standard_DC2as_v[56]$'
    }
    It 'has all expected network components and private VM NICs' {
        foreach ($type in @('Microsoft.Network/virtualNetworks', 'Microsoft.Network/networkSecurityGroups', 'Microsoft.Network/networkInterfaces', 'Microsoft.Network/natGateways', 'Microsoft.Network/publicIPAddresses', 'Microsoft.Network/bastionHosts')) {
            @($resources | Where-Object type -ieq $type).Count | Should -BeGreaterThan 0 -Because "$type must exist"
        }
        foreach ($name in @($outputs.k3sVmName)) {
            $vm = Get-LocalBoxResource "$scopeId/providers/Microsoft.Compute/virtualMachines/$name"
            $nicId = $vm.properties.networkProfile.networkInterfaces[0].id
            $nic = Wait-LocalBoxResource $nicId -TimeoutSeconds $TimeoutSeconds
            $nic.properties.networkSecurityGroup.id | Should -Not -BeNullOrEmpty
            $nic.properties.ipConfigurations[0].properties.publicIPAddress | Should -BeNullOrEmpty
            $nic.properties.ipConfigurations[0].properties.privateIPAddress | Should -Be '10.42.0.4'
            $subnetId = $nic.properties.ipConfigurations[0].properties.subnet.id
            $subnet = Get-LocalBoxResource $subnetId
            $subnet.properties.networkSecurityGroup.id | Should -Be $nic.properties.networkSecurityGroup.id
            if ($name -eq $outputs.k3sVmName) {
                $subnet.properties.defaultOutboundAccess | Should -BeFalse
                $nat = Wait-LocalBoxResource $subnet.properties.natGateway.id -TimeoutSeconds $TimeoutSeconds
                $ip = Get-LocalBoxResource $nat.properties.publicIpAddresses[0].id
                $ip.properties.ipAddress | Should -Be $outputs.natEgressIp
            }
            $nsg = Get-LocalBoxResource $nic.properties.networkSecurityGroup.id
            $ssh = @($nsg.properties.securityRules | Where-Object name -eq 'AllowBastionSsh')
            $ssh.Count | Should -Be 1
            $ssh[0].properties.sourceAddressPrefix | Should -Be '10.42.1.0/26'
            $ssh[0].properties.destinationPortRange | Should -Be '22'
        }
        $bastion = Wait-LocalBoxResource "$scopeId/providers/Microsoft.Network/bastionHosts/$($outputs.bastionName)" -TimeoutSeconds $TimeoutSeconds
        $bastion.sku.name | Should -Be 'Standard'
        $bastion.properties.enableTunneling | Should -BeTrue
        $bastionSubnet = Get-LocalBoxResource $bastion.properties.ipConfigurations[0].properties.subnet.id
        $bastionSubnet.properties.addressPrefix | Should -Be '10.42.1.0/26'
    }
}

Describe 'Participant lab runtime health' -Skip:($Mode -ne 'Full') {
    It 'has healthy Azure AKS nodes, confidential nodes and system workloads' {
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check {
            Test-SovereignKubernetes $Lab.AksKubeconfig 4
            $nodes = Invoke-SovereignKubectl $Lab.AksKubeconfig @('get', 'nodes')
            @($nodes.items | Where-Object { $_.metadata.labels.agentpool -eq 'system' }).Count | Should -Be 2
            $confidentialNodes = @($nodes.items | Where-Object { $_.metadata.labels.agentpool -eq $outputs.confidentialNodePoolName })
            $confidentialNodes.Count | Should -Be 2
            foreach ($node in $confidentialNodes) {
                $node.metadata.labels.workload | Should -Be 'confidential'
                $node.status.nodeInfo.osImage | Should -Match 'Ubuntu'
            }
        }
    }
    It 'has a reachable healthy K3s API and system workloads' {
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check { Test-SovereignKubernetes $Lab.K3sKubeconfig 1 }
    }
    It 'has working guest DNS and outbound connectivity, and an active K3s service' {
        $AllowGuestRunCommand | Should -BeTrue -Because 'Full guest probes require explicit -AllowGuestRunCommand; no resources are installed or changed'
        foreach ($name in @($outputs.k3sVmName)) {
            $script = "set -eu`ngetent hosts management.azure.com >/dev/null`ncurl --fail --silent --show-error --max-time 30 'https://management.azure.com/metadata/endpoints?api-version=2020-06-01' >/dev/null`n"
            if ($name -eq $outputs.k3sVmName) { $script += "systemctl is-active --quiet k3s`n" }
            $script += "printf '\nMICROHACK_GUEST_HEALTH_OK\n'"
            $result = Invoke-LocalBoxAz (@('vm', 'run-command', 'invoke', '--name', $name, '--command-id', 'RunShellScript', '--scripts', $script) + $common) -TimeoutSeconds 300
            ($result.value.message -join "`n") | Should -Match '(?m)^MICROHACK_GUEST_HEALTH_OK\r?$'
        }
    }
}