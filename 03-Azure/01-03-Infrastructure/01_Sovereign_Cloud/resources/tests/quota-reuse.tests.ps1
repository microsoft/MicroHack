BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    . "$root/labautomation/quota-helpers.ps1"
    function Invoke-AzRestMethod { [CmdletBinding()]param($Path, $Uri, $Method) }
    function Get-AzTag { [CmdletBinding()]param($ResourceId) }
    function Update-MhhToken {}
    function Get-AzContext { [CmdletBinding()]param() }
    function Get-MhhStableHash { param($Value, $Length) "$($Value[0])0000000000000000" }
    function Get-AzResourceProvider { [CmdletBinding()]param($ProviderNamespace) }
    function Get-AzComputeResourceSku { [CmdletBinding()]param($Location) }
    function Get-AzVMUsage { [CmdletBinding()]param($Location) }
    function Initialize-MhhHostedTagPolicy { param($SubscriptionId, $Location) }
    function Initialize-MhhHostedDefender { param($SubscriptionId) }
    function New-MhhStablePassword { param($Purpose, $Length) 'test-only-password' }
    function Invoke-MhhDeploymentWithRegionFallback {
        param($PreferredLocations, $ResourceGroupName, $RgOwnerEntraObjectIds, $TemplateFile, $TemplateParameterObject, $DeploymentNamePrefix, $Tag)
    }
    function Get-AzRoleAssignment { [CmdletBinding()]param($ObjectId, $RoleDefinitionId, $Scope) }
    function New-AzSubscriptionDeployment { param($Name, $Location, $TemplateFile, $TemplateParameterObject) }
    $scripts = Join-Path $TestDrive 'scripts'
    New-Item -ItemType Directory $scripts | Out-Null
    foreach ($name in @('deploy-lab.ps1', 'shared-deploy-lab.ps1', 'lab-defaults.json')) {
        Copy-Item "$root/labautomation/$name" $scripts
    }
    foreach ($name in @('quota-helpers.ps1', 'hosted-tag-policy.ps1', 'hosted-defender.ps1', 'resource-providers.ps1')) {
        Set-Content "$scripts/$name" ''
    }
    $subscription = '10000000-0000-0000-0000-000000000001'
    $scope = "/subscriptions/$subscription"
    $candidate = [pscustomobject]@{ Location = 'spaincentral'; VmSize = 'Standard_DC2as_v6'; QuotaName = 'standardDCasv6Family' }
    function New-TestInventory {
        param([int]$Participants = 1, [int]$ConfidentialNodes = 2, [int]$SystemNodes = 2, [int]$K3sVms = 1)
        [pscustomobject]@{
            Resources = @([pscustomobject]@{ location = 'spaincentral' })
            ConfidentialVmSizes = @('Standard_DC2as_v6')
            Allocations = @(
                [pscustomobject]@{ Location = 'spaincentral'; VmSize = 'Standard_D4s_v5'; Count = ($SystemNodes + $K3sVms) * $Participants }
                [pscustomobject]@{ Location = 'spaincentral'; VmSize = 'Standard_DC2as_v6'; Count = $ConfidentialNodes * $Participants }
            )
        }
    }
}

Describe 'Existing participant compute discovery' {
    BeforeEach {
        $vmId = "$scope/resourceGroups/lab/providers/Microsoft.Compute/virtualMachines/vm-k3s-12345678"
        $clusterId = "$scope/resourceGroups/lab/providers/Microsoft.ContainerService/managedClusters/aks-sovereign-12345678"
        $setId = "$scope/resourceGroups/nodes/providers/Microsoft.Compute/virtualMachineScaleSets/aks-cvm"
        $vm = @{ id = $vmId; name = 'vm-k3s-12345678'; type = 'Microsoft.Compute/virtualMachines'; location = 'SpainCentral'
            tags = @{ workload = 'sovereign-lab' }; properties = @{ hardwareProfile = @{ vmSize = 'Standard_D4s_v5' } } }
        $pool = @{ name = 'cvmnodepool'; vmSize = 'Standard_DC2as_v6'; count = 2 }
        $cluster = @{ id = $clusterId; name = 'aks-sovereign-12345678'; type = 'Microsoft.ContainerService/managedClusters'; location = 'spaincentral'
            tags = @{ workload = 'sovereign-lab' }; properties = @{ nodeResourceGroup = 'nodes'; agentPoolProfiles = @($pool) } }
        $scaleSet = @{ id = $setId; location = 'spaincentral'; sku = @{ name = 'Standard_DC2as_v6' }; tags = @{ 'aks-managed-poolName' = 'cvmnodepool' } }
        $routes = @{
            "$scope/providers/Microsoft.Compute/virtualMachines?api-version=2024-11-01" = @{ value = @($vm) }
            "$scope/providers/Microsoft.ContainerService/managedClusters?api-version=2024-10-01" = @{ value = @($cluster) }
            "$scope/providers/Microsoft.Network/virtualNetworks?api-version=2024-05-01" = @{ value = @() }
            "$scope/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2024-11-01" = @{ value = @($scaleSet) }
            "$vmId/instanceView?api-version=2024-11-01" = @{ statuses = @(@{ code = 'PowerState/running' }) }
            "$setId/virtualMachines?api-version=2024-11-01&`$expand=instanceView" = @{ value = @(
                @{ id = "$setId/virtualMachines/0"; properties = @{ instanceView = @{ statuses = @(@{ code = 'PowerState/running' }) } } }
                @{ id = "$setId/virtualMachines/1"; properties = @{ instanceView = @{ statuses = @(@{ code = 'PowerState/stopped' }) } } }
            ) }
        }
        Mock Invoke-AzRestMethod {
            $key = if ($Uri) { $Uri } else { $Path }
            if (-not $routes.ContainsKey($key)) { throw "Unexpected request: $key" }
            @{ StatusCode = 200; Content = ($routes[$key] | ConvertTo-Json -Depth 20 -Compress) }
        }
    }
    It 'credits allocated VMs and actual node instances, including stopped but allocated nodes' {
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678
        ($inventory.Allocations | Where-Object VmSize -eq 'Standard_D4s_v5').Count | Should -Be 1
        ($inventory.Allocations | Where-Object VmSize -eq 'Standard_DC2as_v6').Count | Should -Be 2
        Should -Invoke Invoke-AzRestMethod -Times 0 -ParameterFilter { $Method -ne 'GET' }
    }
    It 'does not credit desired nodes that were not allocated or a deallocated K3s VM' {
        $routes["$vmId/instanceView?api-version=2024-11-01"].statuses[0].code = 'PowerState/deallocated'
        $routes["$setId/virtualMachines?api-version=2024-11-01&`$expand=instanceView"].value[1].properties.instanceView.statuses[0].code = 'PowerState/deallocated'
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678
        @($inventory.Allocations | Where-Object VmSize -eq 'Standard_D4s_v5').Count | Should -Be 0
        ($inventory.Allocations | Where-Object VmSize -eq 'Standard_DC2as_v6').Count | Should -Be 1
    }
    It 'caps surge instances at the two nodes this participant requires' {
        $page = $routes["$setId/virtualMachines?api-version=2024-11-01&`$expand=instanceView"]
        $page.value += $page.value[0]
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678
        ($inventory.Allocations | Where-Object VmSize -eq 'Standard_DC2as_v6').Count | Should -Be 2
    }
    It 'follows pagination when listing actual instances' {
        $page = $routes["$setId/virtualMachines?api-version=2024-11-01&`$expand=instanceView"]
        $routes['https://management.azure.com/next-page'] = @{ value = @($page.value[1]) }
        $page.value = @($page.value[0])
        $page.nextLink = 'https://management.azure.com/next-page'
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678
        ($inventory.Allocations | Where-Object VmSize -eq 'Standard_DC2as_v6').Count | Should -Be 2
    }
    It 'ignores unrelated resources and other participant resource groups' {
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 87654321
        $inventory.Resources.Count | Should -Be 0
        $inventory.Allocations.Count | Should -Be 0
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678 -ResourceGroupName other
        $inventory.Resources.Count | Should -Be 0
    }
    It 'requires participant identities when existing labs are present' {
        { Get-MhhSovereignExistingCompute -SubscriptionId $subscription } | Should -Throw '*Participant IDs are required*'
    }
    It 'rejects incompatible K3s sizes' {
        $vm.properties.hardwareProfile.vmSize = 'Standard_D8s_v5'
        { Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678 } | Should -Throw '*incompatible size*'
    }
    It 'rejects conflicting ownership rather than borrowing unrelated quota' {
        $vm.tags.workload = 'other'
        { Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678 } | Should -Throw '*ownership tag*'
    }
    It 'propagates inventory API failures' {
        Mock Invoke-AzRestMethod { throw 'Forbidden' }
        { Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678 } | Should -Throw '*Forbidden*'
    }
    It 'warns and withholds quota credit for missing power-state evidence' {
        Mock Write-Warning {}
        $routes["$vmId/instanceView?api-version=2024-11-01"].statuses = @()
        $inventory = Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678
        @($inventory.Allocations | Where-Object VmSize -eq 'Standard_D4s_v5').Count | Should -Be 0
        Should -Invoke Write-Warning -Times 1 -Exactly
    }
    It 'rejects duplicate participant resources across groups' {
        $copy = $vm.Clone()
        $copy.id = $vmId.Replace('/lab/', '/other/')
        $routes["$scope/providers/Microsoft.Compute/virtualMachines?api-version=2024-11-01"].value += $copy
        { Get-MhhSovereignExistingCompute -SubscriptionId $subscription -NameSuffixes 12345678 } | Should -Throw '*Ambiguous participant compute*'
    }
    It 'rejects non-success and malformed inventory responses' {
        Mock Invoke-AzRestMethod { @{ StatusCode = 403; Content = '{}' } }
        { Get-MhhSovereignArmData -Path '/test' } | Should -Throw '*HTTP 403*'
        Mock Invoke-AzRestMethod { @{ StatusCode = 200; Content = '{"value":null}' } }
        { Get-MhhSovereignArmData -Path '/test' } | Should -Throw '*Invalid compute inventory*'
    }
}

Describe 'Reuse-aware compute demand and selection' {
    BeforeEach {
        Mock Get-MhhConfidentialComputeSelection { $candidate }
    }
    It 'needs no extra quota for four fully allocated labs' {
        $demand = @(Get-MhhSovereignAdditionalCompute -Candidate $candidate -ExistingCompute (New-TestInventory -Participants 4) -ParticipantCount 4)
        $demand.Additional | Should -Be @(0, 0, 0)
        $demand.Existing | Should -Be @(16, 48, 64)
    }
    It 'requires the complete quota for fresh labs' {
        $demand = @(Get-MhhSovereignAdditionalCompute -Candidate $candidate -ExistingCompute @{ Allocations = @() } -ParticipantCount 4)
        $demand.Additional | Should -Be @(16, 48, 64)
    }
    It 'reserves only missing resources for a partial participant' {
        $demand = @(Get-MhhSovereignAdditionalCompute -Candidate $candidate -ExistingCompute (New-TestInventory -ConfidentialNodes 1 -K3sVms 0))
        $demand.Additional | Should -Be @(2, 4, 6)
    }
    It 'does not borrow allocations from another location or confidential family' {
        $inventory = New-TestInventory
        $inventory.Allocations[0].Location = 'westus2'
        $inventory.Allocations[1].VmSize = 'Standard_DC2as_v5'
        $demand = @(Get-MhhSovereignAdditionalCompute -Candidate $candidate -ExistingCompute $inventory)
        $demand.Additional | Should -Be @(4, 12, 16)
    }
    It 'preserves a valid saved selection' {
        (Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute (New-TestInventory)).Location | Should -Be spaincentral
    }
    It 'rejects mismatched regions and confidential sizes' {
        $inventory = New-TestInventory
        $inventory.Resources[0].location = 'westus2'
        { Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute $inventory } | Should -Throw '*conflict*'
        $inventory.Resources[0].location = 'spaincentral'
        $inventory.ConfidentialVmSizes = @('Standard_DC2as_v5')
        { Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute $inventory } | Should -Throw '*conflict*'
    }
    It 'refuses existing resources without valid selection tags but allows fresh discovery' {
        Mock Get-MhhConfidentialComputeSelection { $null }
        { Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute (New-TestInventory) } | Should -Throw '*Restore*selection tags*'
        Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute @{ Resources = @() } | Should -BeNullOrEmpty
        Mock Get-MhhConfidentialComputeSelection { @{ Location = 'spaincentral'; VmSize = 'Standard_DC2as_v6'; QuotaName = 'wrong' } }
        { Get-MhhSovereignResumeCandidate -SubscriptionId $subscription -ExistingCompute (New-TestInventory) } | Should -Throw '*invalid*'
    }
}

Describe 'Shared and participant quota retry orchestration' {
    BeforeEach {
        $inventory = New-TestInventory -Participants 4
        $usage = @(
            @{ Name = @{ Value = 'standardDCasv6Family' }; CurrentValue = 16; Limit = 16 }
            @{ Name = @{ Value = 'StandardDSv5Family' }; CurrentValue = 48; Limit = 100 }
            @{ Name = @{ Value = 'cores' }; CurrentValue = 96; Limit = 120 }
        )
        Mock Get-AzContext { @{ Subscription = @{ Id = $subscription } } }
        Mock Get-MhhSovereignExistingCompute { $inventory }
        Mock Get-MhhConfidentialComputeSelection { $candidate }
        Mock Get-AzResourceProvider { @{ RegistrationState = 'Registered' } }
        Mock Get-AzComputeResourceSku {
            foreach ($size in @('Standard_D4s_v5', 'Standard_DC2as_v5', 'Standard_DC2as_v6')) {
                @{ ResourceType = 'virtualMachines'; Name = $size; Restrictions = @() }
            }
        }
        Mock Get-AzVMUsage { $usage }
        Mock Request-MhhComputeQuota { @{ Succeeded = $true } }
        Mock Set-MhhConfidentialComputeSelection {}
        Mock Initialize-MhhHostedTagPolicy {}
        Mock Initialize-MhhHostedDefender {}
        Mock Invoke-MhhDeploymentWithRegionFallback { @{ LocationUsed = 'spaincentral'; Outputs = @{} } }
        Mock Get-AzRoleAssignment { @() }
        Mock New-AzSubscriptionDeployment {}
        Mock Start-Sleep {}
        $users = @('12345678', '23456789', '34567890', '45678901')
    }
    It 'does not request doubled quota on a complete rerun or switch to a newly preferred region' {
        & "$scripts/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation westus2,spaincentral -AllowedEntraUserIds $users
        Should -Invoke Request-MhhComputeQuota -Times 0
        Should -Invoke Set-MhhConfidentialComputeSelection -Times 1 -Exactly -ParameterFilter {
            $Candidate.Location -eq 'spaincentral' -and $Candidate.VmSize -eq 'Standard_DC2as_v6'
        }
    }
    It 'waits for inventory providers on fresh subscriptions before querying their resources' {
        Mock Get-AzResourceProvider { @{ RegistrationState = 'Registering' } } -ParameterFilter { $ProviderNamespace -eq 'Microsoft.ContainerService' }
        { & "$scripts/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation spaincentral -AllowedEntraUserIds $users } | Should -Throw '*Microsoft.ContainerService did not reach Registered*'
        Should -Invoke Get-MhhSovereignExistingCompute -Times 0
        Should -Invoke Request-MhhComputeQuota -Times 0
    }
    It 'requests only missing capacity while retaining unrelated LocalBox usage' {
        $inventory = New-TestInventory -Participants 3
        $usage[0].CurrentValue = 12
        $usage[0].Limit = 12
        $usage[1].CurrentValue = 36
        $usage[2].CurrentValue = 80
        $usage[2].Limit = 80
        & "$scripts/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation spaincentral -AllowedEntraUserIds $users
        Should -Invoke Request-MhhComputeQuota -Times 2 -Exactly
        Should -Invoke Request-MhhComputeQuota -Times 1 -Exactly -ParameterFilter { $QuotaName -eq 'standardDCasv6Family' -and $NewLimit -eq 16 }
        Should -Invoke Request-MhhComputeQuota -Times 1 -Exactly -ParameterFilter { $QuotaName -eq 'cores' -and $NewLimit -eq 96 }
    }
    It 'does not change region when a remaining quota request fails' {
        $inventory = New-TestInventory -Participants 3
        Mock Request-MhhComputeQuota { @{ Succeeded = $false; ErrorCode = 'QuotaNotAvailableForResource' } }
        { & "$scripts/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation westus2,spaincentral -AllowedEntraUserIds $users } | Should -Throw '*No preferred region*'
        Should -Invoke Request-MhhComputeQuota -Times 1 -Exactly -ParameterFilter { $Location -eq 'spaincentral' }
        Should -Invoke Set-MhhConfidentialComputeSelection -Times 0
    }
    It 'still reserves the full requirement on a fresh deployment' {
        $inventory = [pscustomobject]@{ Resources = @(); Allocations = @(); ConfidentialVmSizes = @() }
        Mock Get-MhhConfidentialComputeSelection { $null }
        & "$scripts/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation spaincentral -AllowedEntraUserIds $users
        Should -Invoke Request-MhhComputeQuota -Times 1 -Exactly -ParameterFilter { $QuotaName -eq 'standardDCASv5Family' -and $NewLimit -eq 16 }
    }
    It 'lets an allocated participant reach deployment RBAC and credential output at full quota' {
        $inventory = New-TestInventory
        Mock Get-AzComputeResourceSku { @() }
        $result = @(& "$scripts/deploy-lab.ps1" -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab -PreferredLocation westus2 -AllowedEntraUserIds @($users[0]))
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 1 -Exactly -ParameterFilter { $PreferredLocations -eq 'spaincentral' }
        Should -Invoke New-AzSubscriptionDeployment -Times 1 -Exactly
        @($result.HackboxCredential | Where-Object name -eq 'K3s VM Admin Password').Count | Should -Be 1
    }
    It 'still blocks missing confidential nodes without additional quota' {
        $inventory = New-TestInventory -ConfidentialNodes 1
        { & "$scripts/deploy-lab.ps1" -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab -AllowedEntraUserIds @($users[0]) } | Should -Throw '*2 additional standardDCasv6Family*'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
    }
    It 'blocks missing compute when its SKU is unavailable instead of submitting anyway' {
        $inventory = New-TestInventory -K3sVms 0
        Mock Get-AzComputeResourceSku { @() }
        { & "$scripts/deploy-lab.ps1" -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab -AllowedEntraUserIds @($users[0]) } | Should -Throw '*unavailable VM sizes*'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
    }
}
