BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    . "$root/labautomation/hosted-tag-policy.ps1"

    function Update-MhhToken {}
    function Get-AzContext { [CmdletBinding()] param() }
    function New-AzSubscriptionDeployment { [CmdletBinding()] param($Name, $Location, $TemplateFile) }
    function New-AzResourceGroup { [CmdletBinding()] param($Name, $Location, $Tag, [switch]$Force) }
    function New-AzNetworkSecurityGroup { [CmdletBinding()] param($Name, $ResourceGroupName, $Location, $Tag, [switch]$Force) }
    function Get-AzResourceGroup { [CmdletBinding()] param($Name) }
    function Get-AzNetworkSecurityGroup { [CmdletBinding()] param($Name, $ResourceGroupName) }
    function Remove-AzResourceGroup { [CmdletBinding()] param($Name, [switch]$Force) }
}

Describe 'Hosted control-tag setup' {
    BeforeEach {
        $script:probeGroupName = $null
        $script:groupTags = @{ SecurityControl = 'Ignore'; CostControl = 'Ignore'; MicroHackPurpose = 'HostedTagPolicyCheck' }
        $script:resourceTags = $script:groupTags.Clone()
        Mock Update-MhhToken {}
        Mock Get-AzContext { @{ Subscription = @{ Id = 'hosted-subscription' } } }
        Mock New-AzSubscriptionDeployment { @{ ProvisioningState = 'Succeeded' } }
        Mock New-AzResourceGroup { $script:probeGroupName = $Name }
        Mock New-AzNetworkSecurityGroup {}
        Mock Get-AzResourceGroup { [pscustomobject]@{ Tags = $script:groupTags } }
        Mock Get-AzNetworkSecurityGroup { [pscustomobject]@{ Tag = $script:resourceTags } }
        Mock Remove-AzResourceGroup {}
        Mock Start-Sleep {}
    }

    It 'verifies resource group Tags and network resource Tag without supplying the required tags' {
        Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral'
        Should -Invoke New-AzSubscriptionDeployment -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'sov-hosted-tags-swedencentral' -and
            $Location -eq 'swedencentral' -and
            $TemplateFile -like '*/infra/hosted-tag-policy.bicep'
        }
        Should -Invoke New-AzResourceGroup -Times 1 -Exactly -ParameterFilter {
            $Tag.Count -eq 1 -and $Tag.MicroHackPurpose -eq 'HostedTagPolicyCheck' -and
            $Name -match '^rg-sov-tag-check-[a-f0-9]{32}$' -and $Force
        }
        Should -Invoke New-AzNetworkSecurityGroup -Times 1 -Exactly -ParameterFilter {
            $Tag.Count -eq 1 -and $Tag.MicroHackPurpose -eq 'HostedTagPolicyCheck' -and
            $ResourceGroupName -eq $script:probeGroupName -and $Name -eq 'tag-policy-check'
        }
        Should -Invoke Get-AzResourceGroup -Times 1 -Exactly
        Should -Invoke Get-AzNetworkSecurityGroup -Times 1 -Exactly
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly -ParameterFilter {
            $Name -eq $script:probeGroupName -and $Force
        }
        Should -Invoke Start-Sleep -Times 0
    }

    It 'waits for propagation before reporting success' {
        $script:reads = 0
        Mock Get-AzNetworkSecurityGroup {
            $script:reads++
            if ($script:reads -eq 1) { return [pscustomobject]@{ Tag = @{} } }
            return [pscustomobject]@{ Tag = $script:resourceTags }
        }
        Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral'
        Should -Invoke New-AzNetworkSecurityGroup -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly
    }

    It 'fails closed for missing or incorrect tags and cleans up' -TestCases @(
        @{ Target = 'group'; Key = 'SecurityControl'; Value = $null }
        @{ Target = 'group'; Key = 'CostControl'; Value = 'Enforce' }
        @{ Target = 'group'; Key = 'MicroHackPurpose'; Value = $null }
        @{ Target = 'resource'; Key = 'SecurityControl'; Value = 'ignore' }
        @{ Target = 'resource'; Key = 'CostControl'; Value = $null }
        @{ Target = 'resource'; Key = 'MicroHackPurpose'; Value = $null }
    ) {
        param($Target, $Key, $Value)
        if ($Target -eq 'group') { $script:groupTags[$Key] = $Value }
        else { $script:resourceTags[$Key] = $Value }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*after 30 attempts*'
        Should -Invoke New-AzNetworkSecurityGroup -Times 30 -Exactly
        Should -Invoke Start-Sleep -Times 29 -Exactly
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly
    }

    It 'reports the target and observed value when verification times out' {
        $script:resourceTags.SecurityControl = 'Enforce'
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw "*subscription hosted-subscription: network security group/SecurityControl: expected 'Ignore', observed 'Enforce'*assignment sov-hosted-control-tags*"
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly
    }

    It 'fails closed when the tag collection is null' -TestCases @(
        @{ Target = 'group'; Label = 'resource group' }
        @{ Target = 'resource'; Label = 'network security group' }
    ) {
        param($Target, $Label)
        if ($Target -eq 'group') { $script:groupTags = $null }
        else { $script:resourceTags = $null }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw "*${Label}/SecurityControl: expected 'Ignore', observed '<missing>'*"
        Should -Invoke Start-Sleep -Times 29 -Exactly
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly
    }

    It 'rejects a different subscription before deployment' {
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'another-subscription' -Location 'swedencentral' } |
            Should -Throw '*Azure context must target*'
        Should -Invoke New-AzSubscriptionDeployment -Times 0
        Should -Invoke New-AzResourceGroup -Times 0
    }

    It 'stops on deployment failure without creating probe resources' {
        Mock New-AzSubscriptionDeployment { throw 'Policy assignment denied' }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*Policy assignment denied*'
        Should -Invoke New-AzResourceGroup -Times 0
    }

    It 'rejects a non-successful deployment result' {
        Mock New-AzSubscriptionDeployment { @{ ProvisioningState = 'Failed' } }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*did not succeed*'
        Should -Invoke New-AzResourceGroup -Times 0
    }

    It 'does not delete a group whose creation failed' {
        Mock New-AzResourceGroup { throw 'Group creation denied' }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*Group creation denied*'
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'cleans up and surfaces resource creation or read errors' -TestCases @(
        @{ Command = 'New-AzNetworkSecurityGroup' }
        @{ Command = 'Get-AzNetworkSecurityGroup' }
        @{ Command = 'Get-AzResourceGroup' }
    ) {
        param($Command)
        Mock $Command { throw 'Probe operation failed' }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*Probe operation failed*'
        Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0
    }

    It 'does not report successful setup if probe cleanup fails' {
        Mock Remove-AzResourceGroup { throw 'Probe cleanup failed' }
        { Initialize-MhhHostedTagPolicy -SubscriptionId 'hosted-subscription' -Location 'swedencentral' } |
            Should -Throw '*Probe cleanup failed*'
    }
}

Describe 'Hosted-only policy wiring' {
    It 'calls policy setup before any shared LocalBox deployment' {
        $source = Get-Content "$root/labautomation/shared-deploy-lab.ps1" -Raw
        $source | Should -Match "Join-Path .+ 'hosted-tag-policy.ps1'"
        $setup = $source.IndexOf('Initialize-MhhHostedTagPolicy -SubscriptionId $SubscriptionId -Location $selectedCandidate.Location')
        $setup | Should -BeGreaterThan -1
        $setup | Should -BeLessThan $source.IndexOf('$localBoxResourceGroupName =')
    }

    It 'does not wire hosted policies into BYOS setup or participant deployment' {
        $paths = @("$root/labautomation/deploy-lab.ps1") +
            @(Get-ChildItem "$root/resources/manual-setup" -Recurse -File | Select-Object -ExpandProperty FullName)
        foreach ($path in $paths) {
            Get-Content $path -Raw | Should -Not -Match 'Initialize-MhhHostedTagPolicy|hosted-tag-policy.bicep'
        }
    }

    It 'uses only the four built-in tag modifications without remediation or DataClassification changes' {
        $template = Get-Content "$root/labautomation/infra/hosted-tag-policy.bicep" -Raw
        $template | Should -Match "targetScope = 'subscription'"
        $template | Should -Match 'Microsoft.Authorization/policySetDefinitions@2026-06-01'
        $template | Should -Match 'Microsoft.Authorization/policyAssignments@2026-06-01'
        $template | Should -Match '5ffd78d9-436d-4b41-a421-5baa819e3008'
        $template | Should -Match 'd157c373-a6c4-483d-aaad-570756956268'
        ([regex]::Matches($template, 'referenceId:')).Count | Should -Be 4
        ([regex]::Matches($template, "tagName: 'SecurityControl'")).Count | Should -Be 2
        ([regex]::Matches($template, "tagName: 'CostControl'")).Count | Should -Be 2
        $template | Should -Match "(?s)tagValue:\s*\{\s*value: 'Ignore'"
        $template | Should -Match "enforcementMode: 'Default'"
        $template | Should -Match 'location: deployment\(\).location'
        $template | Should -Match "(?s)identity:\s*\{\s*type: 'SystemAssigned'"
        $template | Should -Not -Match 'DataClassification|roleAssignments|Microsoft.PolicyInsights/remediations'
    }
}
