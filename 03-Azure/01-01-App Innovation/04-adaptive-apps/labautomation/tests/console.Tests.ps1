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
        [CmdletBinding()] param($Name, $ResourceGroupName, $TemplateFile, $TemplateParameterObject, $TemplateParameterFile, $Mode)
    }
    function Invoke-MhhDeploymentWithRegionFallback {
        [CmdletBinding()]
        param($PreferredLocations, $ResourceGroupName, $RgOwnerEntraObjectIds, $TemplateFile,
            $TemplateParameterFile, $DeploymentNamePrefix, $Tag)
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
        $script:featureStates = [Collections.Generic.Queue[string]]::new()
        $script:featureStates.Enqueue('Registered')
        $script:featureState = 'Registered'
        $script:featureCalls = [Collections.Generic.List[string]]::new()
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
                { $_ -like 'feature show *' } {
                    $script:featureCalls.Add('show')
                    if ($script:featureStates.Count) { $script:featureState = $script:featureStates.Dequeue() }
                    "{`"properties`":{`"state`":`"$script:featureState`"}}"; break
                }
                { $_ -like 'feature register *' } { $script:featureCalls.Add('register'); '{}'; break }
                { $_ -like 'provider register *' } {
                    $script:featureState | Should -Be 'Registered'
                    $script:registeredProviders.Add("$args"); '{}'; break
                }
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
    It 'allows initial provisioning in the validated alternative when the primary fails' {
        $script:blockedRegion = 'westeurope'
        . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope,northeurope') -AllowedEntraUserIds @('one', 'two')
        $script:sharedTags['microhack-adaptive-location'] | Should -Be 'northeurope'
        $script:sharedTags['microhack-adaptive-regions'] | Should -Be 'northeurope'
    }
    It 'fails when no region passes preflight' {
        $script:blockedRegion = 'westeurope'
        { . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one') } |
            Should -Throw '*No preferred region passed*'
        Should -Invoke New-AzSubscriptionDeployment -Times 0
    }
    It 'registers the public IP feature before re-registering Network' {
        $script:featureStates.Clear()
        foreach ($state in @('NotRegistered', 'Registering', 'Registered')) { $script:featureStates.Enqueue($state) }
        . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one')
        ($script:featureCalls -join ',') | Should -Be 'show,register,show,show'
        @($script:registeredProviders | Where-Object { $_ -like 'provider register --namespace Microsoft.Network *' }) | Should -HaveCount 1
    }
    It 'waits for in-progress registration without resubmitting' {
        $script:featureStates.Clear()
        foreach ($state in @('Registering', 'Registered')) { $script:featureStates.Enqueue($state) }
        . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one')
        $script:featureCalls | Should -Not -Contain 'register'
    }
    It 'blocks fanout when feature registration times out or fails' -ForEach @(
        @{ State = 'Pending'; Error = '*within 15 minutes*' }
        @{ State = 'Failed'; Error = "*ended in state 'Failed'*" }
    ) {
        $script:featureStates.Clear()
        $script:featureStates.Enqueue('Registering')
        $script:featureStates.Enqueue($State)
        { . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one') } |
            Should -Throw $Error
        $script:registeredProviders | Should -HaveCount 0
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
        $script:downloadRoot = ''
        $script:failedDownload = $false
        $script:tamperedDownload = $false
        $script:failedPhase = ''
        $script:location = 'westeurope'
        $script:groupTags = @{ adaptiveAppsReady = 'true' }
        $script:fallbackLocation = 'northeurope'
        $script:guestMarker = 'ADAPTIVE_K3S_READY'
        $script:deploymentState = 'Succeeded'
        $script:deploymentThrows = $false
        $script:useDeploymentJob = $false
        $script:observedParameterFile = ''
        $script:tagWrites = [Collections.Generic.List[object]]::new()
        $script:oldAzureConfig = $env:AZURE_CONFIG_DIR
        $script:originalHome = $env:HOME
        $script:originalPath = $env:PATH
        $env:AZURE_CONFIG_DIR = Join-Path $TestDrive 'platform-azure'
        Mock Invoke-WebRequest {
            $MaximumRetryCount | Should -Be 3
            $timeout = if ($null -ne $TimeoutSec) { $TimeoutSec } else { $ConnectionTimeoutSeconds }
            $timeout | Should -Be 60
            $address = [Uri]$Uri
            $address.Host | Should -Be 'raw.githubusercontent.com'
            $address.AbsolutePath | Should -Match '^/microsoft/MicroHack/[0-9a-f]{40}/03-Azure/01-01-App%20Innovation/04-adaptive-apps/'
            if (-not $script:downloadRoot) {
                $script:downloadRoot = Split-Path (Split-Path $OutFile -Parent) -Parent
                $script:observedHome = Split-Path $script:downloadRoot -Parent
            }
            if ($script:failedDownload) { throw 'Simulated download failure' }
            $relative = [Uri]::UnescapeDataString(($address.AbsolutePath -replace '^.*/04-adaptive-apps/', ''))
            Copy-Item -LiteralPath (Join-Path $script:sourceRoot $relative) -Destination $OutFile
            if ($script:tamperedDownload) { Set-Content -LiteralPath $OutFile -Value 'Unexpected content' }
        }
        Mock Update-MhhToken { $script:calls.Add('refresh') }
        Mock Get-AzContext { @{ Subscription = @{ Id = $subscription } } }
        Mock Get-AzResourceGroup {
            @{ Location = $script:location; ResourceId = "/subscriptions/$subscription/resourceGroups/lab-one"; Tags = $script:groupTags }
        }
        Mock Get-AzTag { @{ Properties = @{ TagsProperty = @{ 'microhack-adaptive-regions' = 'westeurope,northeurope' } } } }
        Mock Update-AzTag {
            $script:tagWrites.Add($Tag.Clone())
            foreach ($key in $Tag.Keys) { $script:groupTags[$key] = $Tag[$key] }
        }
        Mock Invoke-MhhDeploymentWithRegionFallback {
            ($PreferredLocations -join ',') | Should -Be 'westeurope,northeurope'
            $RgOwnerEntraObjectIds | Should -Not -BeNullOrEmpty
            $Tag.adaptiveAppsReady | Should -Be 'false'
            $Tag.SecurityControl | Should -Be 'Ignore'
            $Tag.CostControl | Should -Be 'Ignore'
            $script:location = $script:fallbackLocation
            $script:groupTags = $Tag.Clone()
            $deployment = New-AzResourceGroupDeployment -Name $DeploymentNamePrefix -ResourceGroupName $ResourceGroupName `
                -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile -Mode Incremental
            @{ Success = $true; LocationUsed = $script:location; DeploymentResult = $deployment }
        }
        Mock New-MhhStablePassword { 'TestOnlyStablePassword123' }
        Mock New-AzResourceGroupDeployment {
            $Mode | Should -Be 'Incremental'
            $TemplateParameterObject | Should -BeNullOrEmpty
            $TemplateParameterFile | Should -Not -BeNullOrEmpty
            $script:observedParameterFile = $TemplateParameterFile
            $TemplateParameterFile | Should -Be (Join-Path $script:observedHome 'scratch/main.parameters.json')
            [IO.File]::GetUnixFileMode($TemplateParameterFile) |
                Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
            [IO.File]::GetUnixFileMode((Split-Path $TemplateParameterFile -Parent)) |
                Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
            $parameters = Get-Content -LiteralPath $TemplateParameterFile -Raw | ConvertFrom-Json
            $parameters.'$schema' | Should -Be 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            $parameters.contentVersion | Should -Be '1.0.0.0'
            $parameters.parameters.PSObject.Properties.Name | Should -Not -Contain 'location'
            $parameters.parameters.adminPassword.value | Should -BeExactly 'TestOnlyStablePassword123'
            $serialized = [Management.Automation.PSSerializer]::Serialize($PesterBoundParameters, 10)
            $serialized | Should -Not -Match 'TestOnlyStablePassword|<SS[ >]'
            if ($script:useDeploymentJob) {
                $job = Start-Job -ArgumentList $PesterBoundParameters, $script:deploymentThrows -ScriptBlock {
                    param($DeploymentArguments, $Fail)
                    function Invoke-TestDeployment {
                        [CmdletBinding()]
                        param($Name, $ResourceGroupName, $TemplateFile, $TemplateParameterFile, $Mode)
                        $parameters = Get-Content -LiteralPath $TemplateParameterFile -Raw | ConvertFrom-Json
                        if ($parameters.parameters.adminPassword.value -cne 'TestOnlyStablePassword123') {
                            throw 'Deployment job could not read the synthetic password.'
                        }
                        if ($Fail) { throw 'Simulated ARM deployment exception' }
                        'Parameter file read successfully in child job'
                    }
                    Invoke-TestDeployment @DeploymentArguments
                }
                try {
                    $completed = $job | Wait-Job -Timeout 30
                    if (-not $completed) { throw 'Deployment serialization test job timed out.' }
                    Receive-Job $job -ErrorAction Stop | Should -Be 'Parameter file read successfully in child job'
                } finally {
                    Remove-Job $job -Force
                }
            } elseif ($script:deploymentThrows) {
                throw 'Simulated ARM deployment exception'
            }
            @{
                ProvisioningState = $script:deploymentState
                Outputs = @{
                    acrName = @{ Value = 'acadtestregistry' }
                    nodeResourceGroup = @{ Value = "MC_lab-one_aks-adaptive-apps_$script:location" }
                }
            }
        }
        Mock az {
            $global:LASTEXITCODE = 0
            $script:calls.Add("az $args")
            switch ("$args") {
                { $_ -like 'account show *' } { "{`"id`":`"$subscription`"}"; break }
                { $_ -like 'role assignment list *' } {
                    "$args" | Should -Match '--fill-principal-name false'
                    "$args" | Should -Match '--scope '
                    "$args" | Should -Not -Match '--all\b'
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
            Test-Path -LiteralPath $script:observedParameterFile | Should -BeFalse
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
            $env:REGION | Should -Be $script:location
            $env:AZURE_LOCATION | Should -Be $script:location
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
        if ($script:observedParameterFile) { Test-Path -LiteralPath $script:observedParameterFile | Should -BeFalse }
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
        Should -Invoke Invoke-WebRequest -Times 20 -Exactly
    }
    It 'does not mark ready or emit credentials when Bash fails and still removes its HOME' {
        $script:failedPhase = 'recipes'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*exit code 13*'
        @($script:tagWrites | Where-Object { $_.adaptiveAppsReady -eq 'true' }) | Should -HaveCount 0
    }
    It 'uses validated fallback regions only for initial infrastructure and bootstraps in the resulting RG region' {
        $script:groupTags = @{}
        $result = . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 1 -Exactly -ParameterFilter {
            $RgOwnerEntraObjectIds -contains 'user' -and $DeploymentNamePrefix -eq 'adaptive-apps-console'
        }
        ($result.HackboxCredential | Where-Object name -eq 'Adaptive Apps Region').value | Should -Be 'northeurope'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
    }
    It 'never invokes destructive fallback for a previously ready lab even after a failed retry' {
        $script:deploymentThrows = $true
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*Simulated ARM deployment exception*'
        $script:groupTags.adaptiveAppsReady | Should -Be 'false'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
        $script:downloadRoot = ''
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*Simulated ARM deployment exception*'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
    }
    It 'preserves initial infrastructure after a bootstrap failure on subsequent retries' {
        $script:groupTags = @{}
        $script:fallbackLocation = 'westeurope'
        $script:failedPhase = 'recipes'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*exit code 13*'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
        $script:downloadRoot = ''
        $script:observedWorkingRoot = ''
        $script:failedPhase = ''
        . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') | Out-Null
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 1 -Exactly
    }
    It 'propagates exhausted fallback without bootstrap or readiness' {
        $script:groupTags = @{}
        Mock Invoke-MhhDeploymentWithRegionFallback { throw 'RegionFallbackExhausted' }
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*RegionFallbackExhausted*'
        Should -Invoke bash -Times 0
        $script:groupTags.adaptiveAppsReady | Should -Be 'false'
    }
    It 'passes deployment arguments through a real child job without serializing a SecureString' {
        $script:useDeploymentJob = $true
        $result = . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
        $result.HackboxCredential.name | Should -Contain 'Adaptive Apps Connect'
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match 'TestOnlyStablePassword'
        Should -Invoke New-AzResourceGroupDeployment -Times 1 -Exactly
    }
    It 'preserves deployment exceptions and removes private parameters on failure' -ForEach @(
        @{ ChildJob = $false }
        @{ ChildJob = $true }
    ) {
        $script:useDeploymentJob = $ChildJob
        $script:deploymentThrows = $true
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*Simulated ARM deployment exception*'
        $script:observedParameterFile | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $script:observedParameterFile | Should -BeFalse
        @($script:tagWrites | Where-Object { $_.adaptiveAppsReady -eq 'true' }) | Should -HaveCount 0
        Should -Invoke bash -Times 0
    }
    It 'deploys from only a read-only Console lab folder without sibling workshop sources' {
        $readOnlyRoot = Join-Path $TestDrive 'read-only-source'
        New-Item -ItemType Directory -Path $readOnlyRoot | Out-Null
        $consoleLab = Join-Path $readOnlyRoot 'lab'
        Copy-Item -LiteralPath $automation -Destination $consoleLab -Recurse -Force
        Test-Path (Join-Path $readOnlyRoot 'resources') | Should -BeFalse
        Test-Path (Join-Path $readOnlyRoot 'iac') | Should -BeFalse
        Test-Path (Join-Path $consoleLab 'bootstrap') | Should -BeFalse
        $before = @(Get-ChildItem $readOnlyRoot -Recurse -Force -File | Sort-Object FullName | Get-FileHash)
        $writeBits = [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::GroupWrite -bor [IO.UnixFileMode]::OtherWrite
        try {
            & chmod -R a-w $readOnlyRoot
            $LASTEXITCODE | Should -Be 0
            ([IO.File]::GetUnixFileMode($readOnlyRoot) -band $writeBits) | Should -Be 0
            $result = . (Join-Path $consoleLab 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
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
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*No validated region*'
        Should -Invoke New-AzResourceGroupDeployment -Times 0
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
    }
    It 'fails before Azure calls and cleans scratch when downloading fails' {
        $script:failedDownload = $true
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*Unable to download*Simulated download failure*'
        Should -Invoke Update-MhhToken -Times 0
        Should -Invoke New-AzResourceGroupDeployment -Times 0
        Should -Invoke bash -Times 0
    }
    It 'rejects a hash mismatch before Azure provisioning or Bash execution' {
        $script:tamperedDownload = $true
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*SHA-256 verification failed*'
        Should -Invoke New-AzResourceGroupDeployment -Times 0
        Should -Invoke Update-AzTag -Times 0
        Should -Invoke bash -Times 0
    }
    It 'stops on ARM failure without fallback or bootstrap' {
        $script:deploymentState = 'Failed'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } | Should -Throw '*Bootstrap will not run*'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
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
}

Describe 'Portable packaging and source contracts' {
    It 'fails with an actionable packaging error' {
        { Assert-AdaptivePackage -LabRoot $TestDrive } | Should -Throw '*Verify the pinned source revision*'
    }
    It 'keeps the pinned hashes identical to the canonical workshop sources' {
        { & (Join-Path $automation 'update-bootstrap-source.ps1') -Check } | Should -Not -Throw
    }
    It 'rejects a source pin that has drifted from the workshop sources' {
        $changedSource = Join-Path $TestDrive 'changed-source'
        New-Item -ItemType Directory -Path $changedSource | Out-Null
        foreach ($directory in @('resources', 'iac')) {
            Copy-Item -LiteralPath (Join-Path (Split-Path $automation -Parent) $directory) -Destination (Join-Path $changedSource $directory) -Recurse -Force
        }
        Add-Content -LiteralPath (Join-Path $changedSource 'resources/bootstrap-console.sh') -Value '# Changed workshop source'
        { & (Join-Path $automation 'update-bootstrap-source.ps1') -SourceRoot $changedSource -Check } | Should -Throw '*Bootstrap source pin is stale*'
    }
    It 'rejects moving branches and incomplete or unsafe source manifests' {
        $path = Join-Path $TestDrive 'bad-source.json'
        $manifest = Get-Content (Join-Path $automation 'bootstrap-source.json') -Raw | ConvertFrom-Json -AsHashtable
        $manifest.commit = 'main'
        $manifest | ConvertTo-Json -Depth 3 | Set-Content $path
        { Read-AdaptiveSourceManifest -Path $path } | Should -Throw '*full, lowercase Git commit SHA*'
        $manifest.commit = 'a' * 40
        $manifest.files['../outside.sh'] = 'a' * 64
        $manifest | ConvertTo-Json -Depth 3 | Set-Content $path
        { Read-AdaptiveSourceManifest -Path $path } | Should -Throw '*exactly the required file allowlist*'
        $manifest.files.Remove('../outside.sh')
        $manifest.files['resources/bootstrap-console.sh'] = 'not-a-hash'
        $manifest | ConvertTo-Json -Depth 3 | Set-Content $path
        { Read-AdaptiveSourceManifest -Path $path } | Should -Throw '*valid SHA-256 hash*'
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
    It 'uses configured platform defaults and fails when no region is ready' {
        $defaults = Get-Content (Join-Path $automation 'lab-defaults.json') -Raw | ConvertFrom-Json
        $defaults.deploymentType | Should -Be 'resourcegroup'
        $defaults.labsPerSubscription | Should -Be 5
        $defaults.preferredLocation | Should -Be 'swedencentral,spaincentral'
        $shared = Get-Content (Join-Path $automation 'shared-deploy-lab.ps1') -Raw
        $shared | Should -Match '\$ready.Count -eq 0'
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
        $aks.properties.serviceMeshProfile.PSObject.Properties.Name | Should -Contain 'istio'
        $aks.properties.serviceMeshProfile.istio | Should -BeOfType [pscustomobject]
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
