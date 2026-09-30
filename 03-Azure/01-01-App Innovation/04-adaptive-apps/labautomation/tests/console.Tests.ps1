BeforeAll {
    $automation = Split-Path $PSScriptRoot -Parent
    . (Join-Path $automation 'console-helpers.ps1')
    function Update-MhhToken { }
    function Get-AzContext { [CmdletBinding()] param() }
    function Get-AzResourceGroup { [CmdletBinding()] param($Name) }
    function Get-AzTag { [CmdletBinding()] param($ResourceId) }
    function Update-AzTag { [CmdletBinding()] param($ResourceId, $Operation, $Tag) }
    function New-MhhStablePassword { param($Purpose, $Length) }
    function New-AzResourceGroupDeployment {
        [CmdletBinding()] param($Name, $ResourceGroupName, $TemplateFile, $TemplateParameterObject, $Mode)
    }
    function New-AzSubscriptionDeployment { [CmdletBinding()] param($Name, $Location, $TemplateFile) }
    function New-AzResourceGroup { [CmdletBinding()] param($Name, $Location, $Tag, [switch]$Force) }
    function New-AzNetworkSecurityGroup { [CmdletBinding()] param($Name, $ResourceGroupName, $Location, $Tag, [switch]$Force) }
    function Get-AzNetworkSecurityGroup { [CmdletBinding()] param($Name, $ResourceGroupName) }
    function Remove-AzResourceGroup { [CmdletBinding()] param($Name, [switch]$Force) }
    function az { $global:LASTEXITCODE = 0 }
    function bash { $global:LASTEXITCODE = 0 }
    $subscription = '11111111-1111-1111-1111-111111111111'
    $postgresCurrent = '[{"supportedFeatures":[{"name":"OfferRestricted","status":"Disabled"}],"supportedServerVersions":[{"name":"16"}],"supportedServerEditions":[{"name":"Burstable","supportedServerSkus":[{"name":"Standard_B1ms"}]}]}]'
    $postgresLegacy = '[{"status":"Available","supportedFlexibleServerEditions":[{"name":"Burstable","supportedServerVersions":[{"name":"16","supportedVcores":[{"name":"Standard_B1ms"}]}]}]}]'
}

Describe 'Regional preflight' {
    BeforeEach {
        $script:familyLimit = 32
        $script:regionalLimit = 32
        $script:used = 0
        $script:restriction = 'Zone'
        $script:postgres = $postgresCurrent
        Mock az {
            $global:LASTEXITCODE = 0
            switch ("$args") {
                { $_ -like 'vm list-skus *' } {
                    "[{`"name`":`"Standard_D4s_v5`",`"restrictions`":[{`"type`":`"$script:restriction`"}]}]"
                    break
                }
                { $_ -like 'vm list-usage *' } {
                    "[{`"name`":{`"value`":`"cores`"},`"limit`":$script:regionalLimit,`"currentValue`":$script:used},{`"name`":{`"value`":`"standardDSv5Family`"},`"limit`":$script:familyLimit,`"currentValue`":$script:used}]"
                    break
                }
                { $_ -like 'postgres flexible-server list-skus *' } { $script:postgres; break }
                default { throw "Unexpected az call: $args" }
            }
        }
    }
    It 'requires aggregate baseline plus one D4s surge per lab, allowing regional nonzonal SKUs' {
        Test-AdaptiveRegion -Location westeurope -LabCount 2 | Should -Be 'westeurope'
    }
    It 'rejects quota sufficient only for baseline' {
        $script:familyLimit = 24
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*32 FREE standardDSv5Family*'
    }
    It 'subtracts existing usage and checks regional quota independently' {
        $script:familyLimit = 64
        $script:used = 1
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*32 FREE cores*'
    }
    It 'rejects location-restricted VM SKUs' {
        $script:restriction = 'Location'
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*unrestricted Standard_D4s_v5*'
    }
    It 'supports legacy PostgreSQL capabilities' {
        $script:postgres = $postgresLegacy
        Test-AdaptiveRegion -Location westeurope -LabCount 2 | Should -Be 'westeurope'
    }
    It 'rejects a region without PostgreSQL 16 B1ms' {
        $script:postgres = $postgresCurrent.Replace('Standard_B1ms', 'Standard_D2s_v3')
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*PostgreSQL 16*'
    }
    It 'rejects offer-restricted PostgreSQL' {
        $script:postgres = $postgresCurrent.Replace('"Disabled"', '"Enabled"')
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*PostgreSQL 16*'
    }
    It 'fails closed on external CLI errors' {
        Mock az { $global:LASTEXITCODE = 9 }
        { Test-AdaptiveRegion -Location westeurope -LabCount 2 } | Should -Throw '*exit 9*'
    }
}

Describe 'Shared hook and hosted policy verification' {
    BeforeEach {
        $script:blockedRegion = ''
        $script:policyTagsValid = $true
        $script:sharedTags = $null
        $script:registeredProviders = [Collections.Generic.List[string]]::new()
        Mock Update-MhhToken { }
        Mock Start-Sleep { }
        Mock Get-AzContext { @{ Subscription = @{ Id = $subscription } } }
        Mock Update-AzTag { $script:sharedTags = $Tag }
        Mock New-AzSubscriptionDeployment { @{ ProvisioningState = 'Succeeded' } }
        Mock New-AzResourceGroup {
            $Tag.ContainsKey('SecurityControl') | Should -BeFalse
            $Tag.ContainsKey('CostControl') | Should -BeFalse
        }
        Mock New-AzNetworkSecurityGroup {
            $Tag.ContainsKey('SecurityControl') | Should -BeFalse
            $Tag.ContainsKey('CostControl') | Should -BeFalse
        }
        Mock Get-AzResourceGroup {
            @{ Tags = @{ SecurityControl = 'Ignore'; CostControl = 'Ignore'; MicroHackPurpose = 'HostedTagPolicyCheck' } }
        }
        Mock Get-AzNetworkSecurityGroup {
            $security = if ($script:policyTagsValid) { 'Ignore' } else { 'Enforce' }
            @{ Tag = @{ SecurityControl = $security; CostControl = 'Ignore'; MicroHackPurpose = 'HostedTagPolicyCheck' } }
        }
        Mock Remove-AzResourceGroup { }
        Mock az {
            $global:LASTEXITCODE = 0
            switch ("$args") {
                { $_ -like 'account show *' } { "{`"id`":`"$subscription`"}"; break }
                { $_ -like 'provider register *' } { $script:registeredProviders.Add("$args"); '{}'; break }
                { $_ -like 'provider show *' } { '{"registrationState":"Registered"}'; break }
                { $_ -like 'vm list-skus *' } {
                    if ($script:blockedRegion -and "$args" -like "*--location $script:blockedRegion *") { '[]' }
                    else { '[{"name":"Standard_D4s_v5","restrictions":[]}]' }
                    break
                }
                { $_ -like 'vm list-usage *' } {
                    '[{"name":{"value":"cores"},"limit":32,"currentValue":0},{"name":{"value":"standardDSv5Family"},"limit":32,"currentValue":0}]'
                    break
                }
                { $_ -like 'postgres flexible-server list-skus *' } { $postgresCurrent; break }
                default { throw "Unexpected shared Azure call: $args" }
            }
        }
    }
    It 'registers providers, verifies inherited tags and persists eligible subscription regions' {
        . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope,northeurope') -AllowedEntraUserIds @('one', 'two', 'one')
        $script:sharedTags['microhack-adaptive-location'] | Should -Be 'westeurope'
        $script:sharedTags['microhack-adaptive-regions'] | Should -Be 'westeurope,northeurope'
        $script:sharedTags['microhack-adaptive-lab-count'] | Should -Be '2'
        foreach ($provider in @('Microsoft.Sql', 'Microsoft.KeyVault', 'Microsoft.Storage')) {
            @($script:registeredProviders | Where-Object { $_ -like "provider register --namespace $provider *" }) | Should -HaveCount 1
        }
        Should -Invoke New-AzSubscriptionDeployment -Times 1
        Should -Invoke Remove-AzResourceGroup -Times 1
    }
    It 'refuses success when only an alternative region passes' {
        $script:blockedRegion = 'westeurope'
        { . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope,northeurope') -AllowedEntraUserIds @('one', 'two') } | Should -Throw '*Reconfigure the event location*'
        Should -Invoke New-AzSubscriptionDeployment -Times 0
        Should -Invoke Update-AzTag -Times 0
    }
    It 'stops fanout when resource tags do not propagate and cleans the probe' {
        $script:policyTagsValid = $false
        { . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one', 'two') } | Should -Throw '*verification failed after 30 attempts*'
        Should -Invoke Remove-AzResourceGroup -Times 1
        Should -Invoke Update-AzTag -Times 0
    }
}

Describe 'Participant hook orchestration' {
    BeforeEach {
        $script:calls = [Collections.Generic.List[string]]::new()
        $script:observedHome = ''
        $script:observedWorkingRoot = ''
        $script:sourceRoot = Split-Path $automation -Parent
        $script:failedPhase = ''
        $script:location = 'westeurope'
        $script:guestMarker = 'ADAPTIVE_K3S_READY'
        $script:deploymentState = 'Succeeded'
        $script:tagWrites = [Collections.Generic.List[object]]::new()
        $script:oldAzureConfig = $env:AZURE_CONFIG_DIR
        $script:originalHome = $env:HOME
        $script:originalPath = $env:PATH
        $env:AZURE_CONFIG_DIR = Join-Path $TestDrive 'platform-azure'
        Mock Update-MhhToken { $script:calls.Add('refresh') }
        Mock Get-AzContext { @{ Subscription = @{ Id = $subscription } } }
        Mock Get-AzResourceGroup {
            @{ Location = $script:location; ResourceId = "/subscriptions/$subscription/resourceGroups/lab-one" }
        }
        Mock Get-AzTag { @{ Properties = @{ TagsProperty = @{ 'microhack-adaptive-regions' = 'westeurope,northeurope' } } } }
        Mock Update-AzTag { $script:tagWrites.Add($Tag.Clone()) }
        Mock New-MhhStablePassword { 'TestOnlyStablePassword123' }
        Mock New-AzResourceGroupDeployment {
            $Mode | Should -Be 'Incremental'
            $TemplateParameterObject.location | Should -Be $script:location
            $TemplateParameterObject.adminPassword | Should -BeOfType [securestring]
            @{
                ProvisioningState = $script:deploymentState
                Outputs = @{
                    acrName = @{ Value = 'acadtestregistry' }
                    nodeResourceGroup = @{ Value = 'MC_lab-one_aks-adaptive-apps_westeurope' }
                }
            }
        }
        # Packaging is tested separately; no dependency on work-in-progress parent Bash files.
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -match '/(resources|iac)(/|$)' }
        Mock az {
            $global:LASTEXITCODE = 0
            $script:calls.Add("az $args")
            switch ("$args") {
                { $_ -like 'account show *' } { "{`"id`":`"$subscription`"}"; break }
                { $_ -like 'role assignment list *' } {
                    "$args" | Should -Match '--fill-principal-name false'
                    '[]'; break
                }
                { $_ -like 'role assignment create *' } {
                    "$args" | Should -Match '--assignee-object-id'
                    "$args" | Should -Match '--assignee-principal-type User'
                    '{}'; break
                }
                { $_ -like 'vm run-command invoke *' } {
                    "{`"value`":[{`"message`":`"[stdout]\n$script:guestMarker\n`"}]}"
                    break
                }
                default { throw "Unexpected Azure call: $args" }
            }
        }
        Mock bash {
            $script:calls[-1] | Should -Be 'refresh'
            $script:calls.Add("bash $args")
            $script:observedHome = $env:HOME
            $env:HOME.StartsWith("$script:sourceRoot/") | Should -BeFalse
            $workingPath = (Get-Location).Path
            $workingPath | Should -Be (Join-Path $env:HOME 'work')
            $workingPath | Should -Not -Be $script:sourceRoot
            if ($script:observedWorkingRoot) { $workingPath | Should -Be $script:observedWorkingRoot }
            $script:observedWorkingRoot = $workingPath
            [IO.File]::Exists((Join-Path $workingPath 'resources/bootstrap-console.sh')) | Should -BeTrue
            [IO.File]::Exists((Join-Path $workingPath 'iac/bicepconfig.json')) | Should -BeTrue
            ([IO.File]::GetUnixFileMode((Join-Path $workingPath 'iac/bicepconfig.json')) -band [IO.UnixFileMode]::UserWrite) | Should -Not -Be 0
            (Get-FileHash (Join-Path $workingPath 'iac/bicepconfig.json')).Hash |
                Should -Be (Get-FileHash (Join-Path $script:sourceRoot 'iac/bicepconfig.json')).Hash
            New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
            Set-Content -LiteralPath 'artifacts/console-mock-marker' -Value 'Generated only in private working copy'
            $env:HOME | Should -Not -Be $script:originalHome
            $env:PATH | Should -BeLike "$env:HOME/.local/bin:*"
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $TestDrive 'platform-azure')
            $env:REGION | Should -Be 'westeurope'
            $env:BASTION_NAME | Should -Be 'bas-adaptive-apps'
            [int]$env:K3S_LOCAL_PORT | Should -BeGreaterThan 0
            $env:K3S_KUBECONFIG | Should -BeLike "$env:HOME/*"
            $env:K3S_TUNNEL_STATE_DIR | Should -BeLike "$env:HOME/*"
            $global:LASTEXITCODE = if ($script:failedPhase -and "$args" -like "*$script:failedPhase") { 13 } else { 0 }
        }
    }
    AfterEach {
        $env:HOME | Should -Be $script:originalHome
        $env:PATH | Should -Be $script:originalPath
        if ($script:observedHome) { Test-Path -LiteralPath $script:observedHome | Should -BeFalse }
        [IO.File]::Exists((Join-Path $script:sourceRoot 'artifacts/console-mock-marker')) | Should -BeFalse
        $env:AZURE_CONFIG_DIR = $script:oldAzureConfig
    }
    It 'installs tools then refreshes before all six phases and marks ready only after verify' {
        $result = . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('22222222-2222-2222-2222-222222222222')
        $phases = @($script:calls | Where-Object { $_ -like 'bash *' })
        $phases | Should -HaveCount 7
        $phases[0] | Should -Be 'bash resources/install-console-tools.sh'
        ($phases[1..6] -join ',') | Should -Be 'bash resources/bootstrap-console.sh aks-radius,bash resources/bootstrap-console.sh k3s-radius,bash resources/bootstrap-console.sh aks-types,bash resources/bootstrap-console.sh k3s-types,bash resources/bootstrap-console.sh recipes,bash resources/bootstrap-console.sh verify'
        $script:tagWrites[0].adaptiveAppsReady | Should -Be 'false'
        $script:tagWrites[-1].adaptiveAppsReady | Should -Be 'true'
        $result.HackboxCredential.name | Should -Contain 'Adaptive Apps Connect'
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match 'TestOnlyStablePassword|client-key-data|token:'
    }
    It 'does not mark ready or emit credentials when Bash fails and still removes its HOME' {
        $script:failedPhase = 'recipes'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*exit code 13*'
        @($script:tagWrites | Where-Object { $_.adaptiveAppsReady -eq 'true' }) | Should -HaveCount 0
    }
    It 'supports a read-only source package without creating or modifying source files' {
        $readOnlyRoot = Join-Path $TestDrive 'read-only-source'
        New-Item -ItemType Directory -Path $readOnlyRoot | Out-Null
        foreach ($directory in @('resources', 'iac', 'labautomation')) {
            Copy-Item -LiteralPath (Join-Path $script:sourceRoot $directory) -Destination $readOnlyRoot -Recurse -Force
        }
        $script:sourceRoot = $readOnlyRoot
        $before = @(Get-ChildItem $readOnlyRoot -Recurse -Force -File | Sort-Object FullName | Get-FileHash)
        $writeBits = [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::GroupWrite -bor [IO.UnixFileMode]::OtherWrite
        try {
            & chmod -R a-w $readOnlyRoot
            $LASTEXITCODE | Should -Be 0
            ([IO.File]::GetUnixFileMode($readOnlyRoot) -band $writeBits) | Should -Be 0
            $result = . (Join-Path $readOnlyRoot 'labautomation/deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
            $result.HackboxCredential.name | Should -Contain 'Adaptive Apps Connect'
            ([IO.File]::GetUnixFileMode($readOnlyRoot) -band $writeBits) | Should -Be 0
            $after = @(Get-ChildItem $readOnlyRoot -Recurse -Force -File | Sort-Object FullName | Get-FileHash)
            ($after.Path -join "`n") | Should -Be ($before.Path -join "`n")
            ($after.Hash -join "`n") | Should -Be ($before.Hash -join "`n")
        } finally {
            & chmod -R u+rwX $readOnlyRoot
            if ($LASTEXITCODE -ne 0) { throw 'Unable to restore test fixture permissions for cleanup.' }
        }
    }
    It 'rejects unvalidated RG region before deployment without deleting the scope' {
        $script:location = 'eastus'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*was not validated*'
        Should -Invoke New-AzResourceGroupDeployment -Times 0
    }
    It 'stops on ARM failure without fallback or bootstrap' {
        $script:deploymentState = 'Failed'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*no destructive fallback*'
        Should -Invoke bash -Times 0
    }
    It 'requires guest readiness, not just Run Command HTTP success' {
        $script:guestMarker = 'failed'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*readiness marker*'
        Should -Invoke bash -Times 0
    }
    It 'requires an absolute platform Azure configuration directory' {
        $env:AZURE_CONFIG_DIR = 'relative-profile'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*absolute, isolated AZURE_CONFIG_DIR*'
        Should -Invoke New-AzResourceGroupDeployment -Times 0
    }
    It 'cleans the private working directory if packaging the copy fails' {
        Mock Copy-Item {
            $script:observedHome = Split-Path $Destination -Parent
            throw 'Copy failed'
        }
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*Copy failed*'
        Should -Invoke bash -Times 0
        @($script:tagWrites | Where-Object { $_.adaptiveAppsReady -eq 'true' }) | Should -HaveCount 0
    }
}

Describe 'Portable packaging and source contracts' {
    It 'fails with an actionable packaging error' {
        { Assert-AdaptivePackage -LabRoot $TestDrive } | Should -Throw '*Package the entire MicroHack*'
    }
    It 'rejects missing recipe input <Path> before provisioning' -ForEach @(
        @{ Path = 'iac/sql-databases.yaml' }
        @{ Path = 'iac/recipes/sql-server.bicep' }
        @{ Path = 'iac/recipes/postgres-kubernetes.bicep' }
        @{ Path = 'iac/recipes/trading-schema.sql' }
    ) {
        $script:missingPackagePath = Join-Path $TestDrive $Path
        Mock Test-Path { $LiteralPath -ne $script:missingPackagePath }
        { Assert-AdaptivePackage -LabRoot $TestDrive } | Should -Throw "*missing '$Path'*"
    }
    It 'parses all PowerShell entry points' {
        Get-ChildItem $automation -Filter '*.ps1' | ForEach-Object {
            $tokens = $null
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            $errors | Should -BeNullOrEmpty
        }
    }
    It 'uses conservative platform defaults and shared first-region gating' {
        $defaults = Get-Content (Join-Path $automation 'lab-defaults.json') -Raw | ConvertFrom-Json
        $defaults.deploymentType | Should -Be 'resourcegroup'
        $defaults.labsPerSubscription | Should -Be 2
        $defaults.preferredLocation | Should -Be 'swedencentral'
        $shared = Get-Content (Join-Path $automation 'shared-deploy-lab.ps1') -Raw
        $shared | Should -Match '\$locations\[0\] -notin \$ready'
        $shared | Should -Match 'microhack-adaptive-regions'
        $shared | Should -Not -Match 'az ad |AzureStackHCI|LocalBox|Confidential'
    }
}

Describe 'Bicep offline validation' {
    BeforeAll {
        $bicep = if ($env:BICEP_COMMAND) { $env:BICEP_COMMAND } else { (Get-Command bicep -ErrorAction Stop).Source }
        $templateText = & $bicep build (Join-Path $automation 'main.bicep') --stdout
        if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
        $template = ($templateText -join "`n") | ConvertFrom-Json
        $policyText = & $bicep build (Join-Path $automation 'infra/hosted-tag-policy.bicep') --stdout
        if ($LASTEXITCODE -ne 0) { throw 'Hosted policy Bicep compilation failed.' }
        $policy = ($policyText -join "`n") | ConvertFrom-Json
    }
    It 'keeps two dedicated D4s nodes, one D4s VM, managed Istio and workload identity' {
        $aks = $template.resources | Where-Object type -eq 'Microsoft.ContainerService/managedClusters'
        $aks.properties.agentPoolProfiles[0].count | Should -Be 2
        $aks.properties.agentPoolProfiles[0].vmSize | Should -Be 'Standard_D4s_v5'
        $aks.properties.agentPoolProfiles[0].upgradeSettings.maxSurge | Should -Be '1'
        $aks.properties.oidcIssuerProfile.enabled | Should -BeTrue
        $aks.properties.securityProfile.workloadIdentity.enabled | Should -BeTrue
        $aks.properties.serviceMeshProfile.mode | Should -Be 'Istio'
        $vm = $template.resources | Where-Object type -eq 'Microsoft.Compute/virtualMachines'
        $vm.properties.hardwareProfile.vmSize | Should -Be 'Standard_D4s_v5'
        $template.parameters.adminPassword.type | Should -Be 'securestring'
    }
    It 'provides private NIC, explicit NAT, and Standard tunneling Bastion' {
        $nic = $template.resources | Where-Object type -eq 'Microsoft.Network/networkInterfaces'
        $nic.properties.ipConfigurations[0].properties.publicIPAddress | Should -BeNullOrEmpty
        $vnet = $template.resources | Where-Object type -eq 'Microsoft.Network/virtualNetworks'
        $vnet.properties.subnets[0].properties.defaultOutboundAccess | Should -BeFalse
        $vnet.properties.subnets[0].properties.natGateway.id | Should -Not -BeNullOrEmpty
        $bastion = $template.resources | Where-Object type -eq 'Microsoft.Network/bastionHosts'
        $bastion.name | Should -Be 'bas-adaptive-apps'
        $bastion.sku.name | Should -Be 'Standard'
        $bastion.properties.enableTunneling | Should -BeTrue
    }
    It 'creates a unique Standard anonymous-pull registry without admin credentials' {
        $registry = $template.resources | Where-Object type -eq 'Microsoft.ContainerRegistry/registries'
        $registry.sku.name | Should -Be 'Standard'
        $registry.properties.anonymousPullEnabled | Should -BeTrue
        $registry.properties.adminUserEnabled | Should -BeFalse
        $template.variables.acrName | Should -Match 'uniqueString'
    }
    It 'retains the proven hosted initiative and all four control policies' {
        $policy.variables.policies | Should -HaveCount 4
        @($policy.variables.policies.tagName | Select-Object -Unique) | Should -HaveCount 2
        ($policy.resources | Where-Object type -eq 'Microsoft.Authorization/policyAssignments').name | Should -Be 'sov-hosted-control-tags'
    }
}
