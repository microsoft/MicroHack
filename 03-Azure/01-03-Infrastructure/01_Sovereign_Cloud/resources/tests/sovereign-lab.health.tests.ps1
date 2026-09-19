param([hashtable]$Lab, [string]$Mode, [int]$TimeoutSeconds, [string]$ResourceRoot, [bool]$AllowGuestRunCommand)

BeforeAll {
    . "$ResourceRoot/prepare-localbox.ps1"
    . "$ResourceRoot/test-sovereign-cloud.ps1" -Mode $Mode -AllowGuestRunCommand:$AllowGuestRunCommand
    $outputs = Get-SovereignLabOutputs $Lab
    foreach ($required in @('aksClusterName', 'confidentialNodePoolName', 'confidentialVmName', 'k3sVmName', 'k3sInstallStatusResource', 'attestationProviderName', 'attestationProviderUri', 'bastionName', 'natEgressIp')) {
        if (-not $outputs[$required]) { throw "Missing deployment output $required." }
    }
    $scopeId = "/subscriptions/$($Lab.SubscriptionId)/resourceGroups/$($Lab.ResourceGroupName)"
    $common = @('--subscription', $Lab.SubscriptionId, '--resource-group', $Lab.ResourceGroupName)
    $resources = @(Invoke-LocalBoxAz (@('resource', 'list') + $common))
}

Describe 'Participant lab control plane' {
    It 'has both running VMs with healthy agents' {
        foreach ($name in @($outputs.k3sVmName, $outputs.confidentialVmName)) {
            $vm = Invoke-LocalBoxAz (@('vm', 'get-instance-view', '--name', $name) + $common)
            $vm.provisioningState | Should -Be 'Succeeded'
            $vm.instanceView.statuses.code | Should -Contain 'PowerState/running'
            $vm.instanceView.vmAgent.statuses.code | Should -Contain 'ProvisioningState/succeeded'
        }
    }
    It 'has a confidential VM with secure boot and vTPM' {
        $vm = Get-LocalBoxResource "$scopeId/providers/Microsoft.Compute/virtualMachines/$($outputs.confidentialVmName)"
        $vm.properties.securityProfile.securityType | Should -Be 'ConfidentialVM'
        $vm.properties.securityProfile.uefiSettings.secureBootEnabled | Should -BeTrue
        $vm.properties.securityProfile.uefiSettings.vTpmEnabled | Should -BeTrue
        $vm.properties.storageProfile.osDisk.managedDisk.securityProfile.securityEncryptionType | Should -Be 'VMGuestStateOnly'
        $vm.properties.hardwareProfile.vmSize | Should -Match '^Standard_DC\d+as_v[56]$'
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
        $system = Wait-LocalBoxResource "$aksId/agentPools/system" -TimeoutSeconds $TimeoutSeconds
        $system.properties.count | Should -Be 2
        $system.properties.mode | Should -Be 'System'
        $system.properties.vmSize | Should -Be 'Standard_D4s_v5'
        $pool = Wait-LocalBoxResource "$aksId/agentPools/$($outputs.confidentialNodePoolName)" -TimeoutSeconds $TimeoutSeconds
        $pool.properties.count | Should -Be 1
        $pool.properties.osSKU | Should -Be 'AzureLinux'
        $pool.properties.vmSize | Should -Match '^Standard_DC\d+as_v[56]$'
    }
    It 'has all expected network components and private VM NICs' {
        foreach ($type in @('Microsoft.Network/virtualNetworks', 'Microsoft.Network/networkSecurityGroups', 'Microsoft.Network/networkInterfaces', 'Microsoft.Network/natGateways', 'Microsoft.Network/publicIPAddresses', 'Microsoft.Network/bastionHosts')) {
            @($resources | Where-Object type -ieq $type).Count | Should -BeGreaterThan 0 -Because "$type must exist"
        }
        foreach ($name in @($outputs.k3sVmName, $outputs.confidentialVmName)) {
            $vm = Get-LocalBoxResource "$scopeId/providers/Microsoft.Compute/virtualMachines/$name"
            $nicId = $vm.properties.networkProfile.networkInterfaces[0].id
            $nic = Wait-LocalBoxResource $nicId -TimeoutSeconds $TimeoutSeconds
            $nic.properties.networkSecurityGroup.id | Should -Not -BeNullOrEmpty
            $nic.properties.ipConfigurations[0].properties.publicIPAddress | Should -BeNullOrEmpty
            $expectedIp = if ($name -eq $outputs.k3sVmName) { '10.42.0.4' } else { '10.42.2.4' }
            $nic.properties.ipConfigurations[0].properties.privateIPAddress | Should -Be $expectedIp
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
    It 'has a provisioned attestation provider and valid discovery endpoint' {
        Wait-LocalBoxResource "$scopeId/providers/Microsoft.Attestation/attestationProviders/$($outputs.attestationProviderName)" -TimeoutSeconds $TimeoutSeconds | Should -Not -BeNullOrEmpty
        $uri = [uri]$outputs.attestationProviderUri
        $uri.Scheme | Should -Be 'https'
        $discovery = Invoke-RestMethod -Uri "$($uri.AbsoluteUri.TrimEnd('/'))/.well-known/openid-configuration" -TimeoutSec 30
        $discovery.jwks_uri | Should -Not -BeNullOrEmpty
        ([uri]$discovery.jwks_uri).Host | Should -Be $uri.Host
        @((Invoke-RestMethod -Uri $discovery.jwks_uri -TimeoutSec 30).keys).Count | Should -BeGreaterThan 0
    }
}

Describe 'Participant lab runtime health' -Skip:($Mode -ne 'Full') {
    It 'has healthy Azure AKS nodes, confidential nodes and system workloads' {
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check {
            Test-SovereignKubernetes $Lab.AksKubeconfig 3
            $nodes = Invoke-SovereignKubectl $Lab.AksKubeconfig @('get', 'nodes')
            @($nodes.items | Where-Object { $_.metadata.labels.agentpool -eq 'system' }).Count | Should -Be 2
            @($nodes.items | Where-Object { $_.metadata.labels.agentpool -eq $outputs.confidentialNodePoolName }).Count | Should -Be 1
        }
    }
    It 'has a reachable healthy K3s API and system workloads' {
        Wait-SovereignCheck -TimeoutSeconds $TimeoutSeconds -Check { Test-SovereignKubernetes $Lab.K3sKubeconfig 1 }
    }
    It 'has working guest DNS and outbound connectivity, and an active K3s service' {
        $AllowGuestRunCommand | Should -BeTrue -Because 'Full guest probes require explicit -AllowGuestRunCommand; no resources are installed or changed'
        foreach ($name in @($outputs.k3sVmName, $outputs.confidentialVmName)) {
            $script = "set -eu`ngetent hosts management.azure.com >/dev/null`ncurl --fail --silent --show-error --max-time 30 'https://management.azure.com/metadata/endpoints?api-version=2020-06-01' >/dev/null`n"
            if ($name -eq $outputs.k3sVmName) { $script += "systemctl is-active --quiet k3s`n" }
            $script += "printf '\nMICROHACK_GUEST_HEALTH_OK\n'"
            $result = Invoke-LocalBoxAz (@('vm', 'run-command', 'invoke', '--name', $name, '--command-id', 'RunShellScript', '--scripts', $script) + $common) -TimeoutSeconds 300
            ($result.value.message -join "`n") | Should -Match '(?m)^MICROHACK_GUEST_HEALTH_OK\r?$'
        }
    }
}