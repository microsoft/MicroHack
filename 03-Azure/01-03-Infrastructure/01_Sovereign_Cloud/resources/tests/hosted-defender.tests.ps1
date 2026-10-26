BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    . "$root/labautomation/hosted-defender.ps1"
    function Update-MhhToken {}
    function Get-AzContext { [CmdletBinding()] param() }
    function Invoke-AzRestMethod { [CmdletBinding()] param($Path, $Method, $Payload) }
}

Describe 'Hosted Defender setup' {
    BeforeEach {
        $script:pricing = @{ pricingTier = 'Free' }
        $script:endpoint = $false
        $script:writes = @()
        Mock Update-MhhToken {}
        Mock Get-AzContext { @{ Subscription = @{ Id = 'hosted-subscription' } } }
        Mock Start-Sleep {}
        Mock Invoke-AzRestMethod {
            $isPricing = $Path -like '*/pricings/VirtualMachines?*'
            if ($Method -eq 'PUT') {
                $body = $Payload | ConvertFrom-Json -AsHashtable
                $script:writes += @{ Path = $Path; Body = $body }
                if ($isPricing) { $script:pricing = $body.properties }
                else { $script:endpoint = $body.properties.enabled }
            }
            $properties = if ($isPricing) { $script:pricing } else { @{ enabled = $script:endpoint } }
            @{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 30) }
        }
    }

    It 'enables P2 and Endpoint protection only in the requested subscription' {
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        $script:writes.Count | Should -Be 2
        $script:writes[0].Path | Should -Be '/subscriptions/hosted-subscription/providers/Microsoft.Security/pricings/VirtualMachines?api-version=2024-01-01'
        $script:writes[0].Body.properties.pricingTier | Should -Be 'Standard'
        $script:writes[0].Body.properties.subPlan | Should -Be 'P2'
        $script:writes[1].Path | Should -Be '/subscriptions/hosted-subscription/providers/Microsoft.Security/settings/WDATP?api-version=2021-06-01'
        $script:writes[1].Body.kind | Should -Be 'DataExportSettings'
        $script:writes[1].Body.properties.enabled | Should -BeTrue
        Should -Invoke Invoke-AzRestMethod -Times 2 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/pricings/*' }
        Should -Invoke Invoke-AzRestMethod -Times 1 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/settings/WDATP?*' }
    }

    It 'upgrades P1 while preserving writable extension and enforcement settings' {
        $script:pricing = @{
            pricingTier = 'Standard'; subPlan = 'P1'; enforce = 'False'
            extensions = @(@{ name = 'AgentlessVmScanning'; isEnabled = 'False'; additionalExtensionProperties = @{ ExclusionTags = '[]' }; operationStatus = @{ code = 'Succeeded' } })
            freeTrialRemainingTime = 'PT0S'
        }
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        $properties = $script:writes[0].Body.properties
        $properties.enforce | Should -Be 'False'
        $properties.extensions.Count | Should -Be 1
        $properties.extensions[0].name | Should -Be 'AgentlessVmScanning'
        $properties.extensions[0].isEnabled | Should -Be 'False'
        $properties.extensions[0].additionalExtensionProperties.ExclusionTags | Should -Be '[]'
        $properties.extensions[0].ContainsKey('operationStatus') | Should -BeFalse
        $properties.ContainsKey('freeTrialRemainingTime') | Should -BeFalse
    }

    It 'does not rewrite P2 or disable Endpoint protection on reruns' {
        $script:pricing = @{ pricingTier = 'Standard'; subPlan = 'P2' }
        $script:endpoint = $true
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        Should -Invoke Invoke-AzRestMethod -Times 0 -ParameterFilter { $Method -eq 'PUT' -and $Path -like '*/pricings/*' }
        $script:writes.Count | Should -Be 2
        foreach ($write in $script:writes) { $write.Body.properties.enabled | Should -BeTrue }
    }

    It 'repairs disabled Endpoint protection when P2 is already enabled' {
        $script:pricing = @{ pricingTier = 'Standard'; subPlan = 'P2' }
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        $script:endpoint | Should -BeTrue
        $script:writes.Count | Should -Be 1
    }

    It 'refuses a different Azure context before any request' {
        { Initialize-MhhHostedDefender -SubscriptionId 'another-subscription' } | Should -Throw '*context must target*'
        Should -Invoke Invoke-AzRestMethod -Times 0
    }

    It 'propagates authorization errors and does not claim success' {
        Mock Invoke-AzRestMethod { throw 'AuthorizationFailed' }
        { Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription' } | Should -Throw '*AuthorizationFailed*'
    }

    It 'rejects unexpected HTTP status codes' -TestCases @(@{ Status = 403 }, @{ Status = 202 }, @{ Status = 500 }) {
        param($Status)
        Mock Invoke-AzRestMethod { @{ StatusCode = $Status; Content = 'test failure' } }
        { Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription' } | Should -Throw '*HTTP*test failure*'
    }

    It 'rejects malformed or missing pricing data before writes' -TestCases @(@{ Content = 'not json' }, @{ Content = '{}' }) {
        param($Content)
        Mock Invoke-AzRestMethod { @{ StatusCode = 200; Content = $Content } }
        { Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription' } | Should -Throw
        Should -Invoke Invoke-AzRestMethod -Times 0 -ParameterFilter { $Method -eq 'PUT' }
    }

    It 'accepts a created response to a PUT' {
        Mock Invoke-AzRestMethod { @{ StatusCode = 201; Content = '{"properties":{"enabled":true}}' } } -ParameterFilter { $Method -eq 'PUT' -and $Path -like '*/settings/*' }
        $script:endpoint = $true
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
    }

    It 'waits for read-back convergence' {
        $script:reads = 0
        Mock Invoke-AzRestMethod {
            $script:reads++
            @{ StatusCode = 200; Content = (@{ properties = @{ enabled = ($script:reads -gt 1) } } | ConvertTo-Json) }
        } -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/settings/*' }
        Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription'
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
    }

    It 'fails after bounded verification instead of trusting successful PUTs' -TestCases @(
        @{ Content = '{"properties":{"enabled":false}}' }
        @{ Content = '{"properties":{"enabled":"true"}}' }
        @{ Content = '{}' }
    ) {
        param($Content)
        Mock Invoke-AzRestMethod { @{ StatusCode = 200; Content = $Content } } -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/settings/*' }
        { Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription' } | Should -Throw '*after 12 attempts*'
        Should -Invoke Start-Sleep -Times 11 -Exactly
        Should -Invoke Invoke-AzRestMethod -Times 12 -Exactly -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/settings/*' }
    }

    It 'fails if the plan does not persist even with Endpoint protection enabled' {
        Mock Invoke-AzRestMethod { @{ StatusCode = 200; Content = '{"properties":{"pricingTier":"Standard","subPlan":"P1"}}' } } -ParameterFilter { $Method -eq 'GET' -and $Path -like '*/pricings/*' }
        { Initialize-MhhHostedDefender -SubscriptionId 'hosted-subscription' } | Should -Throw '*plan=P1*'
    }

    It 'wires Defender after hosted tag setup and before LocalBox deployment' {
        $hook = Get-Content "$root/labautomation/global-event-deploy.ps1" -Raw
        $hook | Should -Match "Join-Path \`$PSScriptRoot 'hosted-defender.ps1'"
        $call = $hook.IndexOf('Initialize-MhhHostedDefender -SubscriptionId $SubscriptionId')
        $call | Should -BeGreaterThan $hook.IndexOf('Initialize-MhhHostedTagPolicy -SubscriptionId')
        $call | Should -BeLessThan $hook.IndexOf("`$localBoxResourceGroupName = 'rg-localbox-shared'")
        $shared = Get-Content "$root/labautomation/shared-deploy-lab.ps1" -Raw
        $shared | Should -Match 'Initialize-MhhHostedDefender -SubscriptionId \$SubscriptionId'
    }
}
