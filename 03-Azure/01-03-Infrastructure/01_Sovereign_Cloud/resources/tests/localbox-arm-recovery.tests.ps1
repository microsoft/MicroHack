BeforeAll {
    . "$PSScriptRoot/../../labautomation/localbox-credentials.ps1"
    . "$PSScriptRoot/../../labautomation/localbox-automation.ps1"
    function Update-MhhToken {}
    function Get-AzContext { [CmdletBinding()] param() }
    function Get-AzResourceGroupDeployment { [CmdletBinding()] param($ResourceGroupName, $Name) }
    function Get-AzResourceGroupDeploymentOperation { [CmdletBinding()] param($ResourceGroupName, $DeploymentName) }
}

Describe 'LocalBox asynchronous ARM failures' {
    BeforeEach {
        Mock Update-MhhToken {}
        Mock Get-AzContext { @{ Subscription = @{ Id = 'test' } } }
        Mock Get-AzResourceGroupDeployment { @{ ProvisioningState = 'Failed' } }
        $state = @{
            Message = 'VM size Standard_E32s_v6 has Capacity Restrictions in SpainCentral'
            Codes = @('SkuNotAvailable')
            Serialize = $false
        }
        Mock Get-AzResourceGroupDeploymentOperation {
            $status = @{ error = @{ code = 'InvalidTemplateDeployment'; details = @(
                foreach ($code in $state.Codes) { @{ code = $code; message = $state.Message } }
            ) } }
            if ($state.Serialize) { $status = $status | ConvertTo-Json -Depth 10 }
            @{ Properties = @{ ProvisioningState = 'Failed'; StatusMessage = $status } }
        }
    }
    It 'reports nested capacity details and classifies both object and JSON-string status messages' -TestCases @(
        @{ Serialize = $false }; @{ Serialize = $true }
    ) {
        param($Serialize)
        $state.Serialize = $Serialize
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -BeLike '*ended as Failed*[SkuNotAvailable]*Standard_E32s_v6*SpainCentral*'
        Test-LocalBoxCapacityFailure $caught | Should -BeTrue
    }
    It 'does not retry mixed policy, unknown or authorization failures' -TestCases @(
        @{ Code = 'RequestDisallowedByPolicy' }
        @{ Code = 'AuthorizationFailed' }
        @{ Code = 'OperationNotAllowed' }
        @{ Code = '' }
    ) {
        param($Code)
        $state.Codes = @('SkuNotAvailable', $Code)
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
    }
    It 'fails closed on unavailable diagnostics and reports the read error' {
        Mock Get-AzResourceGroupDeploymentOperation { throw 'AuthorizationFailed reading operations' }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*Could not retrieve*AuthorizationFailed*'
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
    }
    It 'never retries canceled deployments' {
        Mock Get-AzResourceGroupDeployment { @{ ProvisioningState = 'Canceled' } }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
        Should -Invoke Get-AzResourceGroupDeploymentOperation -Times 0
    }
    It 'follows a same-group nested deployment when the parent only reports a wrapper error' {
        Mock Get-AzResourceGroupDeploymentOperation {
            @{ Properties = @{
                ProvisioningState = 'Failed'
                StatusMessage = @{ error = @{ code = 'DeploymentFailed'; message = 'See operations' } }
                TargetResource = @{
                    ResourceType = 'Microsoft.Resources/deployments'; ResourceName = 'hostVmDeployment'
                    Id = '/subscriptions/test/resourceGroups/shared/providers/Microsoft.Resources/deployments/hostVmDeployment'
                }
            } }
        } -ParameterFilter { $DeploymentName -eq 'localbox-test' }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeTrue
        Should -Invoke Get-AzResourceGroupDeploymentOperation -Times 1 -Exactly -ParameterFilter { $DeploymentName -eq 'hostVmDeployment' }
    }
    It 'redacts sensitive values from deployment error messages' {
        $state.Message = 'Capacity unavailable. password=private-fixture-value https://example.invalid/?sig=private-signature'
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        $caught.Exception.Message | Should -Not -Match 'private-fixture-value|private-signature'
    }
    It 'fails closed on empty or malformed operation diagnostics' -TestCases @(
        @{ Malformed = $false }; @{ Malformed = $true }
    ) {
        param($Malformed)
        Mock Get-AzResourceGroupDeploymentOperation {
            if ($Malformed) { @{ Properties = @{ ProvisioningState = 'Failed'; StatusMessage = 'not-json' } } }
        }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
    }
    It 'bounds nested deployment traversal and does not infer a capacity failure' {
        Mock Get-AzResourceGroupDeploymentOperation {
            @{ Properties = @{
                ProvisioningState = 'Failed'
                StatusMessage = @{ error = @{ code = 'DeploymentFailed' } }
                TargetResource = @{
                    ResourceType = 'Microsoft.Resources/deployments'; ResourceName = 'loop'
                    Id = '/subscriptions/test/resourceGroups/shared/providers/Microsoft.Resources/deployments/loop'
                }
            } }
        }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
        Should -Invoke Get-AzResourceGroupDeploymentOperation -Times 6 -Exactly
    }
    It 'does not follow a nested target outside the original subscription or group' -TestCases @(
        @{ Target = '/subscriptions/other/resourceGroups/shared/providers/Microsoft.Resources/deployments/host' }
        @{ Target = '/subscriptions/test/resourceGroups/other/providers/Microsoft.Resources/deployments/host' }
    ) {
        param($Target)
        Mock Get-AzResourceGroupDeploymentOperation {
            @{ Properties = @{
                ProvisioningState = 'Failed'; StatusMessage = @{ error = @{ code = 'DeploymentFailed' } }
                TargetResource = @{ ResourceType = 'Microsoft.Resources/deployments'; ResourceName = 'host'; Id = $Target }
            } }
        }
        $caught = $null
        try { Wait-LocalBoxDeployment -ResourceGroupName 'shared' -DeploymentName 'localbox-test' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
        Should -Invoke Get-AzResourceGroupDeploymentOperation -Times 1 -Exactly
    }
    It 'does not treat an authorization failure mentioning a capacity error as retryable' {
        $caught = $null
        try { throw 'AuthorizationFailed while looking up SkuNotAvailable' }
        catch { $caught = $_ }
        Test-LocalBoxCapacityFailure $caught | Should -BeFalse
    }
}
