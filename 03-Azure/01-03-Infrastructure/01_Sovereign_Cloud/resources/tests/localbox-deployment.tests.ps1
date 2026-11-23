BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    $azExecutable = (Get-Command az -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $compiledPath = Join-Path $TestDrive 'network.json'
    & $azExecutable bicep build --file "$root/labautomation/localbox-network.bicep" --outfile $compiledPath --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw 'LocalBox network Bicep compilation failed.' }
    $network = Get-Content $compiledPath -Raw | ConvertFrom-Json -AsHashtable

    $fixture = Join-Path $TestDrive 'lab'
    New-Item -ItemType Directory -Path "$fixture/labautomation", "$fixture/resources/manual-setup/localbox" -Force | Out-Null
    Copy-Item "$root/labautomation/deploy-localbox.ps1" "$fixture/labautomation"
    Copy-Item "$root/labautomation/localbox-startup.ps1" "$fixture/labautomation"
    Copy-Item "$root/labautomation/localbox-automation.ps1" "$fixture/labautomation"
    Copy-Item "$root/resources/manual-setup/localbox/deploy-localbox.ps1" "$fixture/resources/manual-setup/localbox"
    function az {}
}

Describe 'Compiled LocalBox Developer network' {
    It 'uses the Developer virtual-network binding without dedicated Bastion IP configuration' {
        $bastion = @($network.resources | Where-Object type -eq 'Microsoft.Network/bastionHosts')
        $bastion.Count | Should -Be 1
        $bastion[0].name | Should -Be 'LocalBox-Bastion'
        $bastion[0].sku.name | Should -Be 'Developer'
        $bastion[0].properties.virtualNetwork.id | Should -Match 'Microsoft.Network/virtualNetworks'
        $bastion[0].properties.ContainsKey('ipConfigurations') | Should -BeFalse
    }
    It 'retains the NAT public IP and gateway but no dedicated Bastion resources' {
        $ips = @($network.resources | Where-Object type -eq 'Microsoft.Network/publicIPAddresses')
        $ips.Count | Should -Be 1
        $ips[0].name | Should -Match 'natGatewayName'
        $ips[0].sku.name | Should -Be 'Standard'
        @($network.resources | Where-Object type -eq 'Microsoft.Network/natGateways').Count | Should -Be 1
        @($network.resources | Where-Object type -eq 'Microsoft.Network/networkSecurityGroups').Count | Should -Be 1
        $vnet = $network.resources | Where-Object type -eq 'Microsoft.Network/virtualNetworks'
        $vnet.properties.addressSpace.addressPrefixes | Should -Contain '172.16.0.0/16'
        $vnet.properties.subnets.Count | Should -Be 1
        $subnet = $vnet.properties.subnets[0].properties
        $subnet.addressPrefix | Should -Be '172.16.1.0/24'
        $subnet.defaultOutboundAccess | Should -BeFalse
        $subnet.natGateway | Should -Match 'Microsoft.Network/natGateways'
        $subnet.networkSecurityGroup.id | Should -Match 'Microsoft.Network/networkSecurityGroups'
    }
    It 'preserves disabled-Bastion resource conditions and upstream module outputs' {
        $conditional = @($network.resources | Where-Object { $_.ContainsKey('condition') })
        $conditional.Count | Should -Be 3
        foreach ($resource in $conditional) { $resource.condition | Should -Be "[parameters('deployBastion')]" }
        $network.outputs.vnetId.value | Should -Match 'Microsoft.Network/virtualNetworks'
        $network.outputs.subnetId.value | Should -Match 'subnets'
        foreach ($resource in $network.resources) { $resource.tags | Should -Be "[parameters('resourceTags')]" }
    }
}

Describe 'LocalBox deployment entry points' {
    BeforeEach {
        Copy-Item "$root/labautomation/localbox-network.bicep" "$fixture/labautomation" -Force
        $deploymentTestState = @{
            GroupExists = $false
            Bastions = @()
            Networks = @()
            Clients = @()
            Monitors = @()
            StartupTagUpdate = @()
            QueriesFail = $false
            ValidationFails = $false
            Restrictions = @()
            MissingSku = $false
            FamilyQuota = 64
            RegionalQuota = 64
            Submitted = 0
            Builds = 0
            Parameters = $null
            NetworkSource = $null
            HostSource = $null
            Downloads = [Collections.Generic.List[string]]::new()
        }
        $arguments = @{
            SubscriptionId = '10000000-0000-0000-0000-000000000001'
            ResourceGroupName = 'rg-localbox-test'
            Location = 'spaincentral'
            WindowsAdminPassword = 'fixture-password-not-a-credential'
            AzureLocalResourceProviderObjectId = '20000000-0000-0000-0000-000000000001'
            NoWait = $true
        }
        Mock Invoke-WebRequest {
            $deploymentTestState.Downloads.Add([string]$Uri)
            if ($Uri -like '*/host/host.bicep') {
                @'
var profile = {
  osProfile: {
    computerName: 'LocalBox-Client'
  }
}
var settings = {
  commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminPassword opaque'
}
'@ | Set-Content -LiteralPath $OutFile
            }
            else { Set-Content -LiteralPath $OutFile '// upstream fixture; full compilation is validated separately' }
        }
        Mock az {
            $global:LASTEXITCODE = 0
            $operation = ($args | Select-Object -First 3) -join ' '
            switch -Regex ($operation) {
                '^account show' { '{"name":"test","id":"10000000-0000-0000-0000-000000000001","tenantId":"30000000-0000-0000-0000-000000000001"}'; break }
                '^provider show' { 'Registered'; break }
                '^feature show' { 'Registered'; break }
                '^provider register' { '{}'; break }
                '^vm list-skus' {
                    if ($deploymentTestState.MissingSku) { '[]' }
                    else {
                        $size = $args[[array]::IndexOf($args, '--size') + 1]
                        ConvertTo-Json -InputObject @(@{ name = $size; restrictions = $deploymentTestState.Restrictions }) -Depth 10
                    }
                    break
                }
                '^vm list-usage' {
                    ConvertTo-Json -InputObject @(
                        @{ name = @{ value = 'standardEsv6Family' }; limit = $deploymentTestState.FamilyQuota; currentValue = 0 }
                        @{ name = @{ value = 'standardESv5Family' }; limit = $deploymentTestState.FamilyQuota; currentValue = 0 }
                        @{ name = @{ value = 'cores' }; limit = $deploymentTestState.RegionalQuota; currentValue = 0 }
                    )
                    break
                }
                '^ad sp list' { '[{"id":"20000000-0000-0000-0000-000000000001"}]'; break }
                '^group exists' { $deploymentTestState.GroupExists.ToString().ToLowerInvariant(); break }
                '^network bastion list' {
                    if ($deploymentTestState.QueriesFail) { throw 'AuthorizationFailed' }
                    ConvertTo-Json -InputObject @($deploymentTestState.Bastions) -Depth 10
                    break
                }
                '^network vnet list' { ConvertTo-Json -InputObject @($deploymentTestState.Networks) -Depth 10; break }
                '^resource list' { ConvertTo-Json -InputObject @($deploymentTestState.Clients) -Depth 10; break }
                '^vm run-command list' { ConvertTo-Json -InputObject @($deploymentTestState.Monitors) -Depth 10; break }
                '^group update' {
                    if ($args -contains 'tags.microhack-startup-version=1') { $deploymentTestState.StartupTagUpdate = @($args) }
                    '{"name":"rg-localbox-test","location":"spaincentral"}'
                    break
                }
                '^group (create|show|update)' { '{"name":"rg-localbox-test","location":"spaincentral"}'; break }
                '^bicep build' {
                    $deploymentTestState.Builds++
                    $path = $args[[array]::IndexOf($args, '--file') + 1]
                    $deploymentTestState.NetworkSource = Get-Content (Join-Path (Split-Path $path) 'network/network.bicep') -Raw
                    $deploymentTestState.HostSource = Get-Content (Join-Path (Split-Path $path) 'host/host.bicep') -Raw
                    break
                }
                '^deployment group validate' {
                    if ($deploymentTestState.ValidationFails) { throw 'Bastion Developer is not available in the requested region.' }
                    $path = $args[[array]::IndexOf($args, '--parameters') + 1].TrimStart('@')
                    $deploymentTestState.Parameters = (Get-Content $path -Raw | ConvertFrom-Json).parameters
                    '{}'
                    break
                }
                '^deployment group create' { $deploymentTestState.Submitted++; '{}'; break }
                default { throw "Unexpected az operation in test: $operation" }
            }
        }
    }
    It 'preserves the bootstrap of an existing unprotected VM' {
        $deploymentTestState.Clients = @(@{ name = 'LocalBox-Client'; tags = @{} })
        & "$fixture/labautomation/deploy-localbox.ps1" @arguments
        $deploymentTestState.HostSource | Should -Not -Match 'customData|SovereignStartup'
        $deploymentTestState.Parameters.tags.value.PSObject.Properties.Name | Should -Not -Contain 'microhack-startup-id'
        $deploymentTestState.StartupTagUpdate.Count | Should -Be 0
    }
    It 'rejects a region-restricted or missing SKU before creating infrastructure' -TestCases @(
        @{ Missing = $true; Restrictions = @() }
        @{ Missing = $false; Restrictions = @(@{ type = 'Location'; reasonCode = 'NotAvailableForSubscription' }) }
    ) {
        param($Missing, $Restrictions)
        $deploymentTestState.MissingSku = $Missing
        $deploymentTestState.Restrictions = $Restrictions
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*VM size*unavailable*'
        $deploymentTestState.Submitted | Should -Be 0
        $deploymentTestState.Builds | Should -Be 0
    }
    It 'permits zone-only restrictions for a non-zonal v5 deployment' {
        $deploymentTestState.Restrictions = @(@{ type = 'Zone' })
        $arguments.VmSize = 'Standard_E32s_v5'
        & "$fixture/labautomation/deploy-localbox.ps1" @arguments
        $deploymentTestState.Parameters.vmSize.value | Should -Be 'Standard_E32s_v5'
        $deploymentTestState.Submitted | Should -Be 1
    }
    It 'requires both regional and family headroom' -TestCases @(
        @{ Family = 31; Regional = 64 }
        @{ Family = 64; Regional = 31 }
    ) {
        param($Family, $Regional)
        $deploymentTestState.FamilyQuota = $Family
        $deploymentTestState.RegionalQuota = $Regional
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*At least 32 unused*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'does not redeploy a guarded VM whose progress update removed identity tags' {
        $deploymentTestState.Clients = @(@{ name = 'LocalBox-Client'; tags = @{} })
        $deploymentTestState.Monitors = @(@{ name = 'sovereign-localbox-startup-watch' })
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*startup monitor but no startup identity tags*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'retains the immutable startup identity on a guarded existing VM' {
        $deploymentTestState.Clients = @(@{ name = 'LocalBox-Client'; tags = @{
            'microhack-startup-version' = '1'; 'microhack-startup-id' = '40000000-0000-0000-0000-000000000001'
        } })
        & "$fixture/labautomation/deploy-localbox.ps1" @arguments
        $deploymentTestState.HostSource | Should -Match 'SovereignStartup'
        $deploymentTestState.HostSource | Should -Not -Match 'customData:'
        $deploymentTestState.Parameters.tags.value.'microhack-startup-id' | Should -Be '40000000-0000-0000-0000-000000000001'
    }
    It 'rejects unknown protection metadata without submitting deployment' {
        $deploymentTestState.Clients = @(@{ name = 'LocalBox-Client'; tags = @{ 'microhack-startup-version' = '2' } })
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*No bootstrap migration*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'packages the local module alongside upstream templates and preserves default Bastion/private-host parameters' {
        $result = & "$fixture/labautomation/deploy-localbox.ps1" @arguments
        $result.ProvisioningState | Should -Be 'Submitted'
        $result.BastionName | Should -Be 'LocalBox-Bastion'
        $deploymentTestState.Parameters.deployBastion.value | Should -BeTrue
        $deploymentTestState.Parameters.tags.value.SecurityControl | Should -Be 'Ignore'
        $deploymentTestState.Parameters.tags.value.CostControl | Should -Be 'Ignore'
        $deploymentTestState.Parameters.tags.value.'microhack-startup-version' | Should -Be '1'
        $deploymentTestState.Parameters.tags.value.'microhack-startup-id' | Should -Match '^[a-f0-9-]{36}$'
        $deploymentTestState.HostSource | Should -Match 'customData:'
        $deploymentTestState.StartupTagUpdate | Should -Contain 'tags.microhack-startup-version=1'
        $deploymentTestState.StartupTagUpdate | Should -Contain "tags.microhack-startup-id=$($deploymentTestState.Parameters.tags.value.'microhack-startup-id')"
        $deploymentTestState.StartupTagUpdate | Should -Contain '--set'
        $deploymentTestState.StartupTagUpdate | Should -Not -Contain '--tags'
        $deploymentTestState.NetworkSource | Should -Be (Get-Content "$root/labautomation/localbox-network.bicep" -Raw)
        $deploymentTestState.Downloads.Count | Should -Be 5
        @($deploymentTestState.Downloads | Where-Object { $_ -like '*/network/network.bicep' }).Count | Should -Be 0
        $deploymentTestState.Builds | Should -Be 1
        $deploymentTestState.Submitted | Should -Be 1
    }
    It 'preserves explicit disabled-Bastion behavior' {
        $result = & "$fixture/labautomation/deploy-localbox.ps1" @arguments -DeployBastion $false
        $deploymentTestState.Parameters.deployBastion.value | Should -BeFalse
        $result.BastionName | Should -BeNullOrEmpty
    }
    It 'allows a compatible existing Developer deployment' {
        $deploymentTestState.GroupExists = $true
        $deploymentTestState.Bastions = @(@{ name = 'LocalBox-Bastion'; sku = @{ name = 'Developer' } })
        $deploymentTestState.Networks = @(@{ name = 'LocalBox-VNet'; subnets = @(@{ name = 'LocalBox-Subnet' }) })
        & "$fixture/labautomation/deploy-localbox.ps1" @arguments | Out-Null
        $deploymentTestState.Submitted | Should -Be 1
    }
    It 'rejects existing <Sku> Bastion without changing or deleting it' -TestCases @(
        @{ Sku = 'Basic' }, @{ Sku = 'Standard' }, @{ Sku = 'Premium' }, @{ Sku = '' }
    ) {
        param($Sku)
        $deploymentTestState.GroupExists = $true
        $deploymentTestState.Bastions = @(@{ name = 'LocalBox-Bastion'; sku = @{ name = $Sku }; provisioningState = 'Failed' })
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*cannot be changed to Developer in place*'
        $deploymentTestState.Submitted | Should -Be 0
        $deploymentTestState.Downloads.Count | Should -Be 0
        Should -Invoke az -Times 0 -ParameterFilter { ($args -join ' ') -match 'delete|group update|deployment group create' }
    }
    It 'rejects a legacy subnet even when its dedicated Bastion has already been removed' {
        $deploymentTestState.GroupExists = $true
        $deploymentTestState.Networks = @(@{ name = 'LocalBox-VNet'; subnets = @(@{ name = 'AzureBastionSubnet' }) })
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*legacy AzureBastionSubnet*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'fails closed on existing network discovery errors' {
        $deploymentTestState.GroupExists = $true
        $deploymentTestState.QueriesFail = $true
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*AuthorizationFailed*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'does not fall back to a paid SKU when ARM validation rejects the region' {
        $deploymentTestState.ValidationFails = $true
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*not available*'
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'fails preflight when the Console package omits the local network module' {
        Remove-Item -LiteralPath "$fixture/labautomation/localbox-network.bicep"
        { & "$fixture/labautomation/deploy-localbox.ps1" @arguments } | Should -Throw '*Missing localbox-network.bicep*'
        Should -Invoke az -Times 0
    }
    It 'uses the same deployer and forwards manual settings with Bastion enabled=<Enabled>' -TestCases @(
        @{ Enabled = $true }, @{ Enabled = $false }
    ) {
        param($Enabled)
        Mock Read-Host { 'y' } -ParameterFilter { $Prompt -eq 'Continue? (y/N)' }
        Mock Read-Host { 'fixture-password-not-a-credential' } -ParameterFilter { $Prompt -eq 'Enter admin password for the host VM' }
        $result = & "$fixture/resources/manual-setup/localbox/deploy-localbox.ps1" `
            -ResourceGroupName 'rg-localbox-test' -Location spaincentral -DeployBastion $Enabled `
            -GithubAccount 'fixture-owner' -GithubBranch 'fixture-ref' -AzureLocalInstanceLocation westeurope
        $result.ProvisioningState | Should -Be 'Submitted'
        $deploymentTestState.Parameters.deployBastion.value | Should -Be $Enabled
        $deploymentTestState.Parameters.githubAccount.value | Should -Be 'fixture-owner'
        $deploymentTestState.Parameters.githubBranch.value | Should -Be 'fixture-ref'
        $deploymentTestState.Parameters.azureLocalInstanceLocation.value | Should -Be 'westeurope'
        @($deploymentTestState.Downloads | Where-Object { $_ -notlike 'https://raw.githubusercontent.com/fixture-owner/azure_arc/fixture-ref/*' }).Count | Should -Be 0
    }
    It 'preserves manual cancellation before password collection or deployment' {
        Mock Read-Host { 'n' }
        & "$fixture/resources/manual-setup/localbox/deploy-localbox.ps1" -ResourceGroupName 'rg-localbox-test'
        Should -Invoke Read-Host -Times 1 -Exactly
        Should -Invoke Invoke-WebRequest -Times 0
        $deploymentTestState.Submitted | Should -Be 0
    }
    It 'offers interactive login when needed and propagates sign-in failure' {
        Mock az { $global:LASTEXITCODE = 1 } -ParameterFilter { $args[0] -eq 'account' -or $args[0] -eq 'login' }
        { & "$fixture/resources/manual-setup/localbox/deploy-localbox.ps1" -ResourceGroupName 'rg-localbox-test' } |
            Should -Throw '*sign-in failed*'
        Should -Invoke az -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'login' }
        $deploymentTestState.Submitted | Should -Be 0
    }
}
