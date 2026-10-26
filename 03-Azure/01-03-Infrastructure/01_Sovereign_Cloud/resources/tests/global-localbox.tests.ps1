BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    $fixture = Join-Path $TestDrive 'lab'
    New-Item -ItemType Directory -Path $fixture | Out-Null
    foreach ($name in @('global-event-deploy.ps1', 'shared-deploy-lab.ps1', 'lab-defaults.json')) {
        Copy-Item "$root/labautomation/$name" $fixture
    }
    foreach ($name in @('quota-helpers.ps1', 'localbox-credentials.ps1', 'hosted-tag-policy.ps1', 'hosted-defender.ps1')) {
        Set-Content "$fixture/$name" ''
    }
    Set-Content "$fixture/resource-providers.ps1" 'Register-TestProviders'
    @'
param($SubscriptionId, $ResourceGroupName, $Location, $AzureLocalResourceProviderObjectId, $AzureLocalInstanceLocation, [switch]$UseConsoleCredentials, [switch]$NoWait)
Submit-TestLocalBox @PSBoundParameters
'@ | Set-Content "$fixture/deploy-localbox.ps1"
    function Update-MhhToken {}
    function Get-AzContext {}
    function Get-LocalBoxConsoleGroupCredential {}
    function Register-TestProviders {}
    function Initialize-MhhHostedTagPolicy { param($SubscriptionId, $Location) }
    function Initialize-MhhHostedDefender { param($SubscriptionId) }
    function Get-AzResourceGroup { param($Name) }
    function Get-AzResourceGroupDeployment { param($ResourceGroupName) }
    function Get-AzResource { param($ResourceGroupName, $ResourceType) }
    function Update-AzTag { param($ResourceId, $Operation, $Tag) }
    function Get-AzResourceProvider { param($ProviderNamespace) }
    function Get-AzRoleAssignment { param($ObjectId, $RoleDefinitionName, $RoleDefinitionId, $Scope) }
    function New-AzRoleAssignment { param($ObjectId, $RoleDefinitionName, $Scope) }
    function Wait-LocalBoxDeployment { param($ResourceGroupName, $DeploymentName) }
    function Submit-TestLocalBox {
        param($SubscriptionId, $ResourceGroupName, $Location, $AzureLocalResourceProviderObjectId, $AzureLocalInstanceLocation, [switch]$UseConsoleCredentials, [switch]$NoWait)
    }
    function az {}
    . "$root/labautomation/quota-helpers.ps1"
    function Get-AzComputeResourceSku { param($Location) }
    function Get-AzVMUsage { param($Location) }
}

Describe 'Global LocalBox Console contract' {
    It 'uses the exact supported global parameter contract and opt-in threshold' {
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile("$fixture/global-event-deploy.ps1", [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $parameters = $ast.ParamBlock.Parameters
        @($parameters.Name.VariablePath.UserPath) -join ',' | Should -Be 'SubscriptionId,PreferredLocation,AllowedEntraUserIds'
        $command = Get-Command "$fixture/global-event-deploy.ps1"
        $command.Parameters.SubscriptionId.ParameterType | Should -Be ([string])
        $command.Parameters.PreferredLocation.ParameterType | Should -Be ([string[]])
        $command.Parameters.AllowedEntraUserIds.ParameterType | Should -Be ([string[]])
        foreach ($name in @('SubscriptionId', 'PreferredLocation')) {
            ($command.Parameters[$name].Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
        }
        ($command.Parameters.AllowedEntraUserIds.Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] }).Mandatory | Should -BeFalse
        $parameters[1].DefaultValue.Extent.Text | Should -Be '@()'
        $parameters[2].DefaultValue.Extent.Text | Should -Be '@()'
        $defaults = Get-Content "$fixture/lab-defaults.json" -Raw
        $defaults | Test-Json -SchemaFile "$root/../../../lab-defaults-schema.json" | Should -BeTrue
        $config = $defaults | ConvertFrom-Json
        $config.estimatedGlobalDeploymentDailyCostsUsd | Should -BeGreaterThan 5
        $config.estimatedGlobalDeploymentDailyCostsUsd | Should -Be 110
        $config.estimatedSharedDeploymentDailyCostsUsd | Should -Be 0
    }
}

Describe 'Event-wide LocalBox orchestration' {
    BeforeEach {
        $state = @{
            Subscription = '10000000-0000-0000-0000-000000000001'
            Events = [Collections.Generic.List[string]]::new()
            Assignments = [Collections.Generic.List[object]]::new()
        }
        $users = @('20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002')
        $scope = "/subscriptions/$($state.Subscription)/resourceGroups/rg-localbox-shared"
        Mock Update-MhhToken {}
        Mock Get-AzContext { @{ Subscription = @{ Id = $state.Subscription } } }
        Mock Get-LocalBoxConsoleGroupCredential { @{ HackboxCredential = @{ name = 'Lab Group ObjectId'; value = '30000000-0000-0000-0000-000000000001' } } }
        Mock Register-TestProviders { $state.Events.Add('providers') }
        Mock Initialize-MhhHostedTagPolicy { $state.Events.Add("tags:$SubscriptionId") }
        Mock Initialize-MhhHostedDefender { $state.Events.Add("defender:$SubscriptionId") }
        Mock Get-AzResourceGroup {}
        Mock Get-AzResourceGroupDeployment { @{ DeploymentName = 'localbox-existing'; ProvisioningState = 'Succeeded'; Timestamp = Get-Date } }
        Mock Get-AzResource { @{ Name = 'LocalBox-Client'; ResourceId = "$scope/providers/Microsoft.Compute/virtualMachines/LocalBox-Client" } }
        Mock Update-AzTag {}
        Mock Get-AzResourceProvider { @{ RegistrationState = 'Registered' } }
        Mock Get-AzRoleAssignment {}
        Mock New-AzRoleAssignment { $state.Assignments.Add(@{ User = $ObjectId; Role = $RoleDefinitionName; Scope = $Scope }) }
        Mock Wait-LocalBoxDeployment { $state.Events.Add('wait') }
        Mock Submit-TestLocalBox {
            $state.Events.Add("deploy:$SubscriptionId")
            @{ DeploymentName = 'localbox-new'; ProvisioningState = 'Submitted' }
        }
        Mock az { $global:LASTEXITCODE = 0; '40000000-0000-0000-0000-000000000001' }
        Mock Start-Sleep {}
        Mock Get-AzComputeResourceSku { @(@{ ResourceType = 'virtualMachines'; Name = 'Standard_DC2as_v5'; Restrictions = @() }, @{ ResourceType = 'virtualMachines'; Name = 'Standard_D4s_v5'; Restrictions = @() }) }
        Mock Get-AzVMUsage {
            foreach ($name in @('standardDCasv5Family', 'StandardDSv5Family', 'cores')) {
                @{ Name = @{ Value = $name }; CurrentValue = 36; Limit = 200 }
            }
        }
        Mock Set-MhhConfidentialComputeSelection {}
        Mock Request-MhhComputeQuota { throw 'Unexpected quota request' }
    }
    It 'deploys once for an event and gives users from every subscription the same discovery scope' {
        $result = @(& "$fixture/global-event-deploy.ps1" -SubscriptionId $state.Subscription -PreferredLocation spaincentral -AllowedEntraUserIds ($users + $users[0]))
        Should -Invoke Submit-TestLocalBox -Times 1 -Exactly -ParameterFilter {
            $SubscriptionId -eq $state.Subscription -and $ResourceGroupName -eq 'rg-localbox-shared' -and
            $AzureLocalInstanceLocation -eq 'australiaeast' -and $UseConsoleCredentials -and $NoWait
        }
        $state.Events -join ',' | Should -Be "providers,tags:$($state.Subscription),defender:$($state.Subscription),deploy:$($state.Subscription),wait"
        $state.Assignments.Count | Should -Be 6
        foreach ($user in $users) {
            @($state.Assignments | Where-Object { $_.User -eq $user -and $_.Scope -eq $scope -and $_.Role -in @('Reader', 'Azure Stack HCI VM Contributor') }).Count | Should -Be 2
            @($state.Assignments | Where-Object { $_.User -eq $user -and $_.Scope -eq "/subscriptions/$($state.Subscription)" -and $_.Role -eq 'Security Reader' }).Count | Should -Be 1
        }
        ($result.HackboxCredential | Where-Object name -eq 'Shared LocalBox Subscription ID').value | Should -Be $state.Subscription
        ($result.HackboxCredential | Where-Object name -eq 'Shared LocalBox Resource Group ID').value | Should -Be $scope
        $result | ConvertTo-Json -Depth 10 | Should -Not -Match 'password|arcdemo'
        Should -Invoke Request-MhhComputeQuota -Times 0
        Should -Invoke Set-MhhConfidentialComputeSelection -Times 0
        foreach ($subscription in @($state.Subscription, '10000000-0000-0000-0000-000000000002')) {
            $state.Subscription = $subscription
            & "$fixture/shared-deploy-lab.ps1" -SubscriptionId $subscription -PreferredLocation spaincentral -AllowedEntraUserIds @($users[0])
        }
        Should -Invoke Submit-TestLocalBox -Times 1 -Exactly
        Should -Invoke Set-MhhConfidentialComputeSelection -Times 2 -Exactly
        Should -Invoke Initialize-MhhHostedDefender -Times 3 -Exactly
        Should -Invoke Initialize-MhhHostedTagPolicy -Times 3 -Exactly
    }
    It 'reuses running or succeeded deployments and existing grants on rerun' -TestCases @(
        @{ ProvisioningState = 'Running' }; @{ ProvisioningState = 'Succeeded' }
    ) {
        param($ProvisioningState)
        Mock Get-AzResourceGroup { @{ ResourceId = $scope } }
        Mock Get-AzResourceGroupDeployment { @{ DeploymentName = 'localbox-existing'; ProvisioningState = $ProvisioningState } }
        Mock Get-AzRoleAssignment { @{ RoleAssignmentId = 'existing' } }
        & "$fixture/global-event-deploy.ps1" -SubscriptionId $state.Subscription -PreferredLocation spaincentral -AllowedEntraUserIds $users | Out-Null
        Should -Invoke Submit-TestLocalBox -Times 0
        Should -Invoke New-AzRoleAssignment -Times 0
        Should -Invoke Wait-LocalBoxDeployment -Times 1 -ParameterFilter { $DeploymentName -eq 'localbox-existing' }
    }
    It 'tries the next host region without changing the global subscription' {
        Mock Submit-TestLocalBox { throw 'SkuNotAvailable' } -ParameterFilter { $Location -eq 'spaincentral' }
        & "$fixture/global-event-deploy.ps1" -SubscriptionId $state.Subscription -PreferredLocation @('spaincentral, swedencentral') -AllowedEntraUserIds $users | Out-Null
        Should -Invoke Submit-TestLocalBox -Times 2 -Exactly
        Should -Invoke Submit-TestLocalBox -Times 1 -ParameterFilter { $Location -eq 'swedencentral' -and $SubscriptionId -eq $state.Subscription }
    }
    It 'stops without publishing discovery credentials when <Stage> fails' -TestCases @(
        @{ Stage = 'tags' }; @{ Stage = 'defender' }; @{ Stage = 'roles' }; @{ Stage = 'wait' }; @{ Stage = 'deploy' }; @{ Stage = 'graph' }
    ) {
        param($Stage)
        switch ($Stage) {
            'tags' { Mock Initialize-MhhHostedTagPolicy { throw 'Test failure' } }
            'defender' { Mock Initialize-MhhHostedDefender { throw 'Test failure' } }
            'roles' { Mock Get-AzRoleAssignment { throw 'Test failure' } }
            'wait' { Mock Wait-LocalBoxDeployment { throw 'Test failure' } }
            'deploy' { Mock Submit-TestLocalBox { throw 'Test failure' } }
            'graph' { Mock az { $global:LASTEXITCODE = 1 } }
        }
        $captured = [Collections.Generic.List[object]]::new()
        { & "$fixture/global-event-deploy.ps1" -SubscriptionId $state.Subscription -PreferredLocation spaincentral -AllowedEntraUserIds $users |
            ForEach-Object { $captured.Add($_) } } | Should -Throw
        $captured.Count | Should -Be 0
        if ($Stage -in @('tags', 'defender', 'graph')) { Should -Invoke Submit-TestLocalBox -Times 0 }
    }
    It 'rejects the wrong subscription context before mutating resources' -TestCases @(
        @{ Hook = 'global-event-deploy.ps1' }; @{ Hook = 'shared-deploy-lab.ps1' }
    ) {
        param($Hook)
        { & "$fixture/$Hook" -SubscriptionId 'wrong-subscription' -PreferredLocation spaincentral -AllowedEntraUserIds $users } | Should -Throw '*context must target*'
        Should -Invoke Register-TestProviders -Times 0
        Should -Invoke Submit-TestLocalBox -Times 0
    }
    It 'rejects invalid event participant IDs before provisioning' {
        { & "$fixture/global-event-deploy.ps1" -SubscriptionId $state.Subscription -PreferredLocation spaincentral -AllowedEntraUserIds @('invalid') } | Should -Throw '*valid event participant*'
        Should -Invoke Register-TestProviders -Times 0
    }
}

Describe 'Cross-subscription participant commands' {
    It 'targets the global proxy while keeping team namespaces unique by participant subscription' -Skip:(-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        $guide = Get-Content "$root/walkthrough/challenge-06/solution-06.md" -Raw
        $section = ($guide -split '### Task 5.3:')[1] -split '### Task 5.4:' | Select-Object -First 1
        $blocks = [regex]::Matches($section, '```bash\r?\n(.*?)```', 'Singleline')
        $blocks.Count | Should -Be 2
        $harness = @'
set -e
PARTICIPANT_SUB="$1"
SHARED_SUB="$2"
export HOME="$3"
az() {
  if [[ "$1 $2" == "account show" ]]; then
    if [[ "$*" == *"tenantId"* ]]; then printf '%s\n' "test-tenant"
    else printf '%s\n' "$PARTICIPANT_SUB"; fi
  elif [[ "$1 $2" == "group show" ]]; then
    [[ "$4" == "$PARTICIPANT_SUB" ]] || return 41
  elif [[ "$1 $2" == "connectedk8s show" || "$1 $2" == "connectedk8s proxy" ]]; then
    [[ "$4" == "$SHARED_SUB" ]] || return 42
    if [[ "$2" == "proxy" ]]; then printf 'PROXY_OK\n'; fi
  else
    echo "Unexpected Azure command" >&2
    return 43
  fi
}
'@
        $scriptPath = Join-Path $TestDrive 'participant-proxy.sh'
        $harness + "`n" + ($blocks | ForEach-Object { $_.Groups[1].Value } | Join-String -Separator "`n") |
            Set-Content -LiteralPath $scriptPath
        $shared = '10000000-0000-0000-0000-000000000001'
        $namespaces = @(
            foreach ($participant in @($shared, '10000000-0000-0000-0000-000000000002')) {
                $homePath = Join-Path $TestDrive $participant
                $output = "rg-labuser-same`n$shared`n" | & bash $scriptPath $participant $shared $homePath
                $LASTEXITCODE | Should -Be 0
                $output | Should -Contain 'PROXY_OK'
                $settings = Get-Content "$homePath/.config/microhack/challenge06.env" -Raw
                $settings | Should -Match "export SUBSCRIPTION_ID=$participant"
                $settings | Should -Match "export LOCALBOX_SUBSCRIPTION_ID=$shared"
                [regex]::Match($settings, 'export TEAM_NAMESPACE=(\S+)').Groups[1].Value
            }
        )
        $namespaces[0] | Should -Not -BeNullOrEmpty
        $namespaces[0] | Should -Not -Be $namespaces[1]
    }
}

Describe 'Participant Security Reader reuse after global setup' {
    BeforeAll {
        $source = Get-Content "$root/labautomation/deploy-lab.ps1" -Raw
        $start = $source.IndexOf('Write-Host "Assigning subscription-scoped lab RBAC')
        $end = $source.IndexOf('@{"HackboxCredential" = @{ name = "Sovereign Lab Region"')
        if ($start -lt 0 -or $end -le $start) { throw 'Participant RBAC block was not found.' }
        $rbacBlock = Join-Path $fixture 'participant-rbac.ps1'
        $source.Substring($start, $end - $start) | Set-Content -LiteralPath $rbacBlock
        function New-AzSubscriptionDeployment { param($Name, $Location, $TemplateFile, $TemplateParameterObject) }
    }
    BeforeEach {
        $SubscriptionId = '10000000-0000-0000-0000-000000000001'
        $AllowedEntraUserIds = @('20000000-0000-0000-0000-000000000001')
        $ResourceGroupName = 'rg-labuser-test'
        $deploymentName = 'lab-test'
        $effectiveLocation = 'spaincentral'
        $existing = @{
            ObjectId = $AllowedEntraUserIds[0]
            Scope = "/subscriptions/$SubscriptionId"
            RoleDefinitionId = '39bc4728-0917-49c7-9d2c-d95423bc2eb4'
            RoleAssignmentId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleAssignments/c868cdb5-b1ed-4d61-8aea-d192f49de4e5"
        }
        Mock Update-MhhToken {}
        Mock Get-AzRoleAssignment { $existing }
        Mock New-AzSubscriptionDeployment {}
    }
    It 'preserves the global grant instead of redeploying the same role under the Bicep GUID' {
        & $rbacBlock
        Should -Invoke Get-AzRoleAssignment -Times 1 -Exactly -ParameterFilter {
            $Scope -eq "/subscriptions/$SubscriptionId" -and
            $ObjectId -eq $AllowedEntraUserIds[0] -and
            $RoleDefinitionId -eq '39bc4728-0917-49c7-9d2c-d95423bc2eb4'
        }
        Should -Invoke New-AzSubscriptionDeployment -Times 1 -Exactly -ParameterFilter {
            $TemplateParameterObject.assignSecurityReader -eq $false -and
            $TemplateParameterObject.userObjectId -eq $AllowedEntraUserIds[0] -and
            $TemplateParameterObject.resourceGroupName -eq $ResourceGroupName
        }
    }
    It 'still grants Security Reader in another subscription where no grant exists' {
        Mock Get-AzRoleAssignment { @() }
        & $rbacBlock
        Should -Invoke New-AzSubscriptionDeployment -Times 1 -Exactly -ParameterFilter {
            $TemplateParameterObject.assignSecurityReader -eq $true
        }
    }
    It 'does not skip the grant based on a different <Field>' -TestCases @(
        @{ Field = 'Scope'; Value = '/subscriptions/other' }
        @{ Field = 'Scope'; Value = '/subscriptions/10000000-0000-0000-0000-000000000001/resourceGroups/child' }
        @{ Field = 'ObjectId'; Value = 'another-user' }
        @{ Field = 'RoleDefinitionId'; Value = 'another-role' }
    ) {
        param($Field, $Value)
        $existing[$Field] = $Value
        & $rbacBlock
        Should -Invoke New-AzSubscriptionDeployment -Times 1 -Exactly -ParameterFilter {
            $TemplateParameterObject.assignSecurityReader -eq $true
        }
    }
    It 'fails closed when existing role assignments cannot be read' {
        Mock Get-AzRoleAssignment { throw 'AuthorizationFailed' }
        { & $rbacBlock } | Should -Throw '*AuthorizationFailed*'
        Should -Invoke New-AzSubscriptionDeployment -Times 0
    }
    It 'keeps the default grant and other RBAC resources unchanged in the template' {
        $template = Get-Content "$root/labautomation/main.bicep" -Raw
        $template | Should -Match 'param assignSecurityReader bool = true'
        $template | Should -Match "resource securityReaderAssignment [^\r\n]+ = if \(assignSecurityReader\)"
        $template | Should -Match "resource resourcePolicyContributorAssignment [^\r\n]+ = \{"
        $template | Should -Match "module resourceGroupRbac 'rg-rbac.bicep' = \{"
    }
}
