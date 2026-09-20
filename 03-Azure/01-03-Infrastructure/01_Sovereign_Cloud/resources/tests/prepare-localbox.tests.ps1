BeforeAll {
    . "$PSScriptRoot/../prepare-localbox.ps1"
    . "$PSScriptRoot/../test-sovereign-cloud.ps1"
    . "$PSScriptRoot/../../labautomation/localbox-credentials.ps1"
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
        $source | Should -Match "(?s)resource confidentialNodePool .*?properties: \{\s+count: 1\s+tags: tags"
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