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
    function bash { }
    function kubectl { }
    function rad { }
    $subscription = '11111111-1111-1111-1111-111111111111'
    $postgresCurrent = '[{"supportedFeatures":[{"name":"OfferRestricted","status":"Disabled"}],"supportedServerVersions":[{"name":"16"}],"supportedServerEditions":[{"name":"GeneralPurpose","supportedServerSkus":[{"name":"Standard_D4ds_v5"}]}]}]'
    $postgresLegacy = '[{"status":"Available","supportedFlexibleServerEditions":[{"name":"GeneralPurpose","supportedServerVersions":[{"name":"16","supportedVcores":[{"name":"Standard_D4ds_v5"}]}]}]}]'
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
                    "[{`"name`":`"Standard_D4s_v5`",`"restrictions`":[{`"type`":`"$script:restriction`"}]}]"; break
                }
                { $_ -like 'vm list-usage *' } {
                    "[{`"name`":{`"value`":`"cores`"},`"limit`":$script:regionalLimit,`"currentValue`":$script:used},{`"name`":{`"value`":`"standardDSv5Family`"},`"limit`":$script:familyLimit,`"currentValue`":$script:used}]"; break
                }
                { $_ -like 'postgres flexible-server list-skus *' } { $script:postgres; break }
                default { throw "Unexpected az call: $args" }
            }
        }
    }
    It 'requires baseline plus surge per lab and allows regional nonzonal SKUs' {
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
    It 'rejects a region without PostgreSQL 16 D4ds_v5' {
        $script:postgres = $postgresCurrent.Replace('Standard_D4ds_v5', 'Standard_B1ms')
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
                    '[{"name":{"value":"cores"},"limit":32,"currentValue":0},{"name":{"value":"standardDSv5Family"},"limit":32,"currentValue":0}]'; break
                }
                { $_ -like 'postgres flexible-server list-skus *' } { $postgresCurrent; break }
                default { throw "Unexpected shared Azure call: $args" }
            }
        }
    }
    It 'registers providers, verifies inherited tags and persists eligible regions' {
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
    It 'allows a validated alternative when the primary fails' {
        $script:blockedRegion = 'westeurope'
        . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope,northeurope') -AllowedEntraUserIds @('one', 'two')
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
        Should -Invoke Update-AzTag -Times 0
    }
    It 'stops fanout when resource tags do not propagate and cleans the probe' {
        $script:policyTagsValid = $false
        { . (Join-Path $automation 'shared-deploy-lab.ps1') -SubscriptionId $subscription -PreferredLocation @('westeurope') -AllowedEntraUserIds @('one', 'two') } |
            Should -Throw '*verification failed after 30 attempts*'
        Should -Invoke Remove-AzResourceGroup -Times 1
        Should -Invoke Update-AzTag -Times 0
    }
}

Describe 'Retained developer-scenario jq bootstrap' {
    BeforeEach {
        $script:jqBin = Join-Path $TestDrive 'bin'
        $script:jqFault = ''
        $script:jqAsset = if ([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq 'Arm64') { 'jq-linux-arm64' } else { 'jq-linux-amd64' }
        $script:jqHash = if ($script:jqAsset -eq 'jq-linux-arm64') {
            '8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309'
        } else {
            'b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f'
        }
        Mock Invoke-WebRequest {
            $Uri | Should -Be "https://github.com/jqlang/jq/releases/download/jq-1.8.2/$script:jqAsset"
            $MaximumRetryCount | Should -Be 3
            $RetryIntervalSec | Should -Be 2
            $timeout = if ($null -ne $TimeoutSec) { $TimeoutSec } else { $ConnectionTimeoutSeconds }
            $timeout | Should -Be 60
            $version = if ($script:jqFault -eq 'version') { 'wrong-version' } else { 'jq-1.8.2' }
            Set-Content -LiteralPath $OutFile -Encoding utf8 -Value @('#!/bin/sh', "echo $version")
            if ($script:jqFault -eq 'download') { throw 'Simulated jq download failure' }
        }
        Mock Get-FileHash {
            $Algorithm | Should -Be 'SHA256'
            @{ Hash = if ($script:jqFault -eq 'hash') { '0' * 64 } else { $script:jqHash } }
        }
    }
    AfterEach {
        @(Get-ChildItem -LiteralPath $script:jqBin -Force | Where-Object Name -like '.jq-*') | Should -HaveCount 0
    }
    It 'installs the verified executable into the private directory' {
        Install-AdaptiveJq -BinDirectory $script:jqBin
        $target = Join-Path $script:jqBin 'jq'
        & $target --version | Should -Be 'jq-1.8.2'
        [IO.File]::GetUnixFileMode($target) |
            Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }
    It 'rejects <Fault> failure and keeps an existing executable untouched' -ForEach @(
        @{ Fault = 'download'; Error = '*Simulated jq download failure*' }
        @{ Fault = 'hash'; Error = '*SHA-256 verification failed*' }
        @{ Fault = 'version'; Error = '*failed its version check*' }
    ) {
        New-Item -ItemType Directory -Path $script:jqBin -Force | Out-Null
        $target = Join-Path $script:jqBin 'jq'
        Set-Content -LiteralPath $target -Value 'Existing executable'
        $script:jqFault = $Fault
        { Install-AdaptiveJq -BinDirectory $script:jqBin } | Should -Throw $Error
        (Get-Content -LiteralPath $target -Raw).Trim() | Should -Be 'Existing executable'
    }
}

Describe 'Retained developer-scenario source artifacts' {
    It 'retains the complete allowlisted package and valid historical manifest' {
        { Assert-AdaptivePackage -LabRoot (Split-Path $automation -Parent) } | Should -Not -Throw
        $manifest = Read-AdaptiveSourceManifest -Path (Join-Path $automation 'bootstrap-source.json')
        $manifest.files.Count | Should -Be 20
    }
    It 'fails with an actionable packaging error' {
        { Assert-AdaptivePackage -LabRoot $TestDrive } | Should -Throw '*Verify the pinned source revision*'
    }
    It 'reports historical pin drift rather than silently accepting changed participant sources' {
        { & (Join-Path $automation 'update-bootstrap-source.ps1') -Check } | Should -Throw '*Bootstrap source pin is stale*'
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
    It 'rejects missing recipe input <Path>' -ForEach @(
        @{ Path = 'iac/sql-databases.yaml' }
        @{ Path = 'iac/recipes/sql-server.bicep' }
        @{ Path = 'iac/recipes/postgres-kubernetes.bicep' }
        @{ Path = 'iac/recipes/trading-schema.sql' }
    ) {
        $script:missingPackagePath = Join-Path $TestDrive $Path
        Mock Test-Path { $LiteralPath -ne $script:missingPackagePath }
        { Assert-AdaptivePackage -LabRoot $TestDrive } | Should -Throw "*missing '$Path'*"
    }
}

Describe 'Infrastructure-only participant hook' {
    BeforeEach {
        $script:calls = [Collections.Generic.List[string]]::new()
        $script:location = 'westeurope'
        $script:groupTags = @{ adaptiveAppsInfrastructureReady = 'true' }
        $script:fallbackLocation = 'northeurope'
        $script:guestMarker = 'ADAPTIVE_K3S_READY'
        $script:aksResult = '{"provisioningState":"Succeeded","exitCode":0}'
        $script:bastionResult = '{"state":"Succeeded","sku":"Standard","tunneling":true}'
        $script:acrResult = '{"provisioningState":"Succeeded","anonymousPullEnabled":true}'
        $script:deploymentState = 'Succeeded'
        $script:deploymentThrows = $false
        $script:useDeploymentJob = $false
        $script:observedParameterFile = ''
        $script:tagWrites = [Collections.Generic.List[object]]::new()
        $script:oldAzureConfig = $env:AZURE_CONFIG_DIR
        $script:originalHome = $env:HOME
        $script:originalPath = $env:PATH
        $script:originalKubeconfig = $env:KUBECONFIG
        $env:AZURE_CONFIG_DIR = Join-Path $TestDrive 'platform-azure'
        $env:KUBECONFIG = '/worker-cluster/must-not-use'
        Mock Invoke-WebRequest { throw 'No source or tool downloads are permitted.' }
        Mock bash { throw 'No local Bash bootstrap is permitted.' }
        Mock kubectl { throw 'The worker Kubernetes context must not be used.' }
        Mock rad { throw 'Radius belongs to participants.' }
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
        Mock New-MhhStablePassword { 'TestOnlyStablePassword123' }
        Mock New-AzResourceGroupDeployment {
            $Mode | Should -Be 'Incremental'
            $TemplateParameterObject | Should -BeNullOrEmpty
            $script:observedParameterFile = $TemplateParameterFile
            [IO.File]::GetUnixFileMode($TemplateParameterFile) |
                Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
            [IO.File]::GetUnixFileMode((Split-Path $TemplateParameterFile -Parent)) |
                Should -Be ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
            $parameters = Get-Content -LiteralPath $TemplateParameterFile -Raw | ConvertFrom-Json
            $parameters.'$schema' | Should -Be 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            $parameters.parameters.PSObject.Properties.Name | Should -Not -Contain 'location'
            $parameters.parameters.adminPassword.value | Should -BeExactly 'TestOnlyStablePassword123'
            [Management.Automation.PSSerializer]::Serialize($PesterBoundParameters, 10) |
                Should -Not -Match 'TestOnlyStablePassword|<SS[ >]'
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
                    if (-not ($job | Wait-Job -Timeout 30)) { throw 'Deployment serialization test job timed out.' }
                    Receive-Job $job -ErrorAction Stop | Should -Be 'Parameter file read successfully in child job'
                } finally { Remove-Job $job -Force }
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
        Mock Invoke-MhhDeploymentWithRegionFallback {
            ($PreferredLocations -join ',') | Should -Be 'westeurope,northeurope'
            $RgOwnerEntraObjectIds | Should -Contain 'user'
            $Tag.adaptiveAppsInfrastructureReady | Should -Be 'false'
            $Tag.SecurityControl | Should -Be 'Ignore'
            $script:location = $script:fallbackLocation
            $script:groupTags = $Tag.Clone()
            $deployment = New-AzResourceGroupDeployment -Name $DeploymentNamePrefix -ResourceGroupName $ResourceGroupName `
                -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile -Mode Incremental
            @{ Success = $true; LocationUsed = $script:location; DeploymentResult = $deployment }
        }
        Mock az {
            $global:LASTEXITCODE = 0
            $script:calls.Add("az $args")
            switch ("$args") {
                { $_ -like 'account show *' } { "{`"id`":`"$subscription`"}"; break }
                { $_ -like 'role assignment list *' } {
                    "$args" | Should -Match '--fill-principal-name false'
                    "$args" | Should -Match "--scope /subscriptions/$subscription/resourceGroups/MC_lab-one_aks-adaptive-apps_$script:location"
                    "$args" | Should -Not -Match '--all\b'
                    '[]'; break
                }
                { $_ -like 'role assignment create *' } {
                    "$args" | Should -Match '--assignee-object-id'
                    "$args" | Should -Match '--assignee-principal-type User'
                    '{}'; break
                }
                { $_ -like 'vm run-command invoke *' } {
                    Test-Path -LiteralPath $script:observedParameterFile | Should -BeFalse
                    "$args" | Should -Match '--name vm-adaptive-apps-k3s'
                    "{`"value`":[{`"message`":`"[stdout]\n$script:guestMarker\n`"}]}"; break
                }
                { $_ -like 'aks command invoke *' } {
                    "$args" | Should -Match '--resource-group lab-one --name aks-adaptive-apps'
                    "$args" | Should -Match 'kubectl wait --for=condition=Ready nodes --all --timeout=5m'
                    $script:aksResult; break
                }
                { $_ -like 'network bastion show *' } { $script:bastionResult; break }
                { $_ -like 'acr show *' } { $script:acrResult; break }
                default { throw "Unexpected Azure call: $args" }
            }
        }
    }
    AfterEach {
        $env:HOME | Should -Be $script:originalHome
        $env:PATH | Should -Be $script:originalPath
        $env:KUBECONFIG | Should -Be '/worker-cluster/must-not-use'
        if ($script:observedParameterFile) {
            Test-Path -LiteralPath $script:observedParameterFile | Should -BeFalse
            Test-Path -LiteralPath (Split-Path $script:observedParameterFile -Parent) | Should -BeFalse
        }
        Should -Invoke Invoke-WebRequest -Times 0
        Should -Invoke bash -Times 0
        Should -Invoke kubectl -Times 0
        Should -Invoke rad -Times 0
        $env:AZURE_CONFIG_DIR = $script:oldAzureConfig
        $env:KUBECONFIG = $script:originalKubeconfig
    }
    It 'verifies infrastructure without Radius and hands participants off to Challenge 03' {
        $result = . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
        $script:tagWrites[0].adaptiveAppsInfrastructureReady | Should -Be 'false'
        $script:tagWrites[-1].adaptiveAppsInfrastructureReady | Should -Be 'true'
        $script:groupTags.adaptiveAppsReady | Should -Be 'false'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
        ($result.HackboxCredential | Where-Object name -eq 'Adaptive Apps Connect').note | Should -Match 'Challenge 03'
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match 'TestOnlyStablePassword|client-key-data|token:'
    }
    It 'uses the fallback RG region without hardcoding template location' {
        $script:groupTags = @{}
        $result = . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user')
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 1 -Exactly
        ($result.HackboxCredential | Where-Object name -eq 'Adaptive Apps Region').value | Should -Be 'northeurope'
    }
    It 'preserves old developer-ready labs and keeps protection after a failed retry' {
        $script:groupTags = @{ adaptiveAppsReady = 'true' }
        $script:deploymentThrows = $true
        1..2 | ForEach-Object {
            { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
                Should -Throw '*Simulated ARM deployment exception*'
        }
        $script:groupTags.adaptiveAppsReady | Should -Be 'false'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
    }
    It 'preserves newly deployed infrastructure after readiness failure on later retries' {
        $script:groupTags = @{}
        $script:guestMarker = 'not-ready'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*readiness marker*'
        $script:groupTags.adaptiveAppsPreserve | Should -Be 'true'
        $script:guestMarker = 'ADAPTIVE_K3S_READY'
        . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') | Out-Null
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 1 -Exactly
    }
    It 'fails closed on <Failure> without declaring infrastructure ready' -ForEach @(
        @{ Failure = 'K3s'; Error = '*readiness marker*' }
        @{ Failure = 'AKS exit'; Error = '*AKS node readiness failed*' }
        @{ Failure = 'AKS missing exit'; Error = '*AKS node readiness failed*' }
        @{ Failure = 'AKS state'; Error = '*AKS node readiness failed*' }
        @{ Failure = 'Bastion'; Error = '*Bastion must be provisioned*' }
        @{ Failure = 'ACR'; Error = '*recipe registry must be provisioned*' }
    ) {
        switch ($Failure) {
            'K3s' { $script:guestMarker = 'not-ready' }
            'AKS exit' { $script:aksResult = '{"provisioningState":"Succeeded","exitCode":1}' }
            'AKS missing exit' { $script:aksResult = '{"provisioningState":"Succeeded"}' }
            'AKS state' { $script:aksResult = '{"provisioningState":"Failed","exitCode":0}' }
            'Bastion' { $script:bastionResult = '{"state":"Succeeded","sku":"Standard","tunneling":false}' }
            'ACR' { $script:acrResult = '{"provisioningState":"Failed"}' }
        }
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw $Error
        $script:groupTags.adaptiveAppsInfrastructureReady | Should -Be 'false'
    }
    It 'preserves ARM exceptions and private file cleanup across a real child job' -ForEach @(
        @{ Fail = $false }
        @{ Fail = $true }
    ) {
        $script:useDeploymentJob = $true
        $script:deploymentThrows = $Fail
        if ($Fail) {
            { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
                Should -Throw '*Simulated ARM deployment exception*'
        } else {
            . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') | Out-Null
        }
    }
    It 'propagates exhausted fallback without readiness checks' {
        $script:groupTags = @{}
        Mock Invoke-MhhDeploymentWithRegionFallback { throw 'RegionFallbackExhausted' }
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*RegionFallbackExhausted*'
        @($script:calls | Where-Object { $_ -like 'az vm run-command *' }) | Should -HaveCount 0
    }
    It 'stops on failed ARM state' {
        $script:deploymentState = 'Failed'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*Infrastructure deployment failed*'
        $script:groupTags.adaptiveAppsInfrastructureReady | Should -Be 'false'
    }
    It 'rejects unvalidated regions for protected labs without deleting them' {
        $script:location = 'eastus'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*No validated region*'
        Should -Invoke Invoke-MhhDeploymentWithRegionFallback -Times 0
        Should -Invoke New-AzResourceGroupDeployment -Times 0
    }
    It 'requires an absolute isolated Azure CLI profile' {
        $env:AZURE_CONFIG_DIR = 'relative-profile'
        { . (Join-Path $automation 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') } |
            Should -Throw '*absolute, isolated AZURE_CONFIG_DIR*'
        Should -Invoke New-AzResourceGroupDeployment -Times 0
    }
    It 'runs from a read-only lab-only folder without a checkout or source downloads' {
        $consoleLab = Join-Path $TestDrive 'lab'
        Copy-Item -LiteralPath $automation -Destination $consoleLab -Recurse
        $before = @(Get-ChildItem $consoleLab -Recurse -File | Sort-Object FullName | Get-FileHash)
        try {
            & chmod -R a-w $consoleLab
            if ($LASTEXITCODE -ne 0) { throw 'Unable to protect test fixture.' }
            . (Join-Path $consoleLab 'deploy-lab.ps1') -DeploymentType resourcegroup -SubscriptionId $subscription -ResourceGroupName lab-one -AllowedEntraUserIds @('user') | Out-Null
            $after = @(Get-ChildItem $consoleLab -Recurse -File | Sort-Object FullName | Get-FileHash)
            ($after.Path -join "`n") | Should -Be ($before.Path -join "`n")
            ($after.Hash -join "`n") | Should -Be ($before.Hash -join "`n")
        } finally {
            & chmod -R u+rwX $consoleLab
            if ($LASTEXITCODE -ne 0) { throw 'Unable to restore test fixture.' }
        }
    }
}

Describe 'Source and infrastructure contracts' {
    BeforeAll {
        $bicep = if ($env:BICEP_COMMAND) { $env:BICEP_COMMAND } else { (Get-Command bicep -ErrorAction Stop).Source }
        $templateText = & $bicep build (Join-Path $automation 'main.bicep') --stdout
        if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
        $template = ($templateText -join "`n") | ConvertFrom-Json
        $policyText = & $bicep build (Join-Path $automation 'infra/hosted-tag-policy.bicep') --stdout
        if ($LASTEXITCODE -ne 0) { throw 'Hosted policy Bicep compilation failed.' }
        $policy = ($policyText -join "`n") | ConvertFrom-Json
    }
    It 'parses all PowerShell entry points' {
        Get-ChildItem $automation -Filter '*.ps1' | ForEach-Object {
            $tokens = $null
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            $errors | Should -BeNullOrEmpty
        }
    }
    It 'keeps defaults and no-region preflight guard' {
        $defaults = Get-Content (Join-Path $automation 'lab-defaults.json') -Raw | ConvertFrom-Json
        $defaults.deploymentType | Should -Be 'resourcegroup'
        $defaults.labsPerSubscription | Should -Be 5
        $defaults.preferredLocation | Should -Be 'spaincentral,swedencentral'
        Get-Content (Join-Path $automation 'shared-deploy-lab.ps1') -Raw | Should -Match '\$ready.Count -eq 0'
    }
    It 'keeps two dedicated D4s nodes, one D4s VM, managed Istio and workload identity' {
        $aks = $template.resources | Where-Object type -eq 'Microsoft.ContainerService/managedClusters'
        $aks.properties.agentPoolProfiles[0].count | Should -Be 2
        $aks.properties.agentPoolProfiles[0].vmSize | Should -Be 'Standard_D4s_v5'
        $aks.properties.agentPoolProfiles[0].upgradeSettings.maxSurge | Should -Be '1'
        $aks.properties.oidcIssuerProfile.enabled | Should -BeTrue
        $aks.properties.securityProfile.workloadIdentity.enabled | Should -BeTrue
        $aks.properties.serviceMeshProfile.mode | Should -Be 'Istio'
        $aks.properties.serviceMeshProfile.istio | Should -BeOfType [pscustomobject]
        ($template.resources | Where-Object type -eq 'Microsoft.Compute/virtualMachines').properties.hardwareProfile.vmSize | Should -Be 'Standard_D4s_v5'
        $template.parameters.adminPassword.type | Should -Be 'securestring'
        $template.parameters.location.defaultValue | Should -Be '[resourceGroup().location]'
    }
    It 'provides private NIC, explicit NAT, and Standard tunneling Bastion' {
        $nic = $template.resources | Where-Object type -eq 'Microsoft.Network/networkInterfaces'
        $nic.properties.ipConfigurations[0].properties.publicIPAddress | Should -BeNullOrEmpty
        $vnet = $template.resources | Where-Object type -eq 'Microsoft.Network/virtualNetworks'
        $vnet.properties.subnets[0].properties.defaultOutboundAccess | Should -BeFalse
        $vnet.properties.subnets[0].properties.natGateway.id | Should -Not -BeNullOrEmpty
        $bastion = $template.resources | Where-Object type -eq 'Microsoft.Network/bastionHosts'
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
