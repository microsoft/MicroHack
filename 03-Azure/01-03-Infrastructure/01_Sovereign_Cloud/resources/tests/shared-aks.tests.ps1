BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    $workloadScript = "$root/walkthrough/challenge-05/Deploy-VotingAppCC.ps1"
    function az {}
    function kubectl {}
    . "$root/labautomation/quota-helpers.ps1"
}

AfterAll {
    Remove-Variable -Name SharedAks_* -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Shared AKS workload lifecycle' {
    BeforeEach {
        $global:SharedAks_azCalls = [Collections.Generic.List[object]]::new()
        $global:SharedAks_kubeCalls = [Collections.Generic.List[object]]::new()
        $global:SharedAks_pool = @{ provisioningState = 'Succeeded'; count = 2; osSKU = 'Ubuntu'; vmSize = 'Standard_DC2as_v5'; mode = 'User'; nodeLabels = @{ workload = 'confidential' } }
        $global:SharedAks_namespace = @{ metadata = @{ labels = @{ 'microhack-challenge' = '05' } } }
        Mock az {
            $global:SharedAks_azCalls.Add(@($args))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'account') { return 'test-subscription' }
            if ($args[1] -eq 'show') { return '{"location":"spaincentral","provisioningState":"Succeeded"}' }
            if ($args[1] -eq 'nodepool') { return ($global:SharedAks_pool | ConvertTo-Json -Depth 5 -Compress) }
            if ($args[1] -eq 'get-credentials') {
                $path = $args[[array]::IndexOf($args, '--file') + 1]
                [IO.File]::WriteAllText($path, 'mock-kubeconfig')
            }
        }
        Mock kubectl {
            $global:SharedAks_kubeCalls.Add(@($args))
            $global:LASTEXITCODE = 0
            if ($args[6] -eq 'get' -and $args[7] -eq 'namespace') {
                if ($global:SharedAks_namespace) { return ($global:SharedAks_namespace | ConvertTo-Json -Depth 5 -Compress) }
            }
            if ($args[6] -eq 'get' -and $args[7] -eq 'service') { return '192.0.2.1' }
            if ($args[6] -eq 'create' -and $args[7] -eq 'configmap') { return 'apiVersion: v1' }
        }
        Mock Invoke-WebRequest { @{ StatusCode = 200; Content = 'Azure Voting App' } }
        Mock Start-Sleep {}
    }
    It 'deploys only workloads into an explicit namespace and context on the provided cluster' {
        & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console'
        @($global:SharedAks_azCalls | Where-Object { $_[1] -in @('create','delete') -or $_ -contains 'add' }).Count | Should -Be 0
        foreach ($call in $global:SharedAks_kubeCalls) {
            $call[0] | Should -Be '--kubeconfig'
            $call[2] | Should -Be '--context'
            $call[3] | Should -Be 'challenge-05-test-subscription-aks-from-console'
            $call[4] | Should -Be '--namespace'
            $call[5] | Should -Be 'challenge-05'
            Test-Path -LiteralPath $call[1] | Should -BeFalse
        }
        @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'apply' }).Count | Should -Be 3
    }
    It 'cleanup removes only named applications, not cluster, pools, namespace or Radius' {
        & $workloadScript -Cleanup -ResourceGroup 'lab-test' -ClusterName 'aks-from-console'
        $deletes = @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'delete' })
        $deletes.Count | Should -Be 1
        $deletes[0][5] | Should -Be 'challenge-05'
        $deletes[0] | Should -Contain 'deployment/azure-vote-front'
        $deletes[0] | Should -Contain 'deployment/cc-attest'
        $deletes[0] | Should -Not -Contain 'namespace'
        @($global:SharedAks_azCalls | Where-Object { $_ -contains 'delete' }).Count | Should -Be 0
    }
    It 'cleanup is a no-op if its namespace is absent' {
        $manifestFile = Join-Path $TestDrive 'caller-owned.txt'
        [IO.File]::WriteAllText($manifestFile, 'Keep caller files')
        $global:SharedAks_namespace = $null
        & $workloadScript -Cleanup -ResourceGroup 'lab-test' -ClusterName 'aks-from-console'
        @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'delete' }).Count | Should -Be 0
        Test-Path $manifestFile | Should -BeTrue
    }
    It 'creates a dedicated namespace when absent and accepts the selected v6 confidential SKU' {
        $global:SharedAks_namespace = $null
        $global:SharedAks_pool.vmSize = 'Standard_DC2as_v6'
        & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console'
        @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'apply' }).Count | Should -Be 4
    }
    It 'stops if the provided pool cannot be read instead of provisioning another one' {
        Mock az { $global:LASTEXITCODE = 1 } -ParameterFilter { $args[1] -eq 'nodepool' }
        { & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*pool is missing*'
        $global:SharedAks_kubeCalls.Count | Should -Be 0
    }
    It 'cleans the private kubeconfig when application cleanup fails' {
        Mock kubectl { $global:LASTEXITCODE = 1 } -ParameterFilter { $args[6] -eq 'delete' }
        { & $workloadScript -Cleanup -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*application cleanup failed*'
        Test-Path $global:SharedAks_kubeCalls[0][1] | Should -BeFalse
    }
    It 'refuses application deployment into an Istio-injected namespace' {
        $global:SharedAks_namespace.metadata.labels.'istio.io/rev' = 'asm-1-24'
        { & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*without Istio sidecar injection*'
        @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'apply' }).Count | Should -Be 0
    }
    It 'rejects a confidential pool without the workload selector label' {
        $global:SharedAks_pool.nodeLabels = @{}
        { & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*labelled workload=confidential*'
        $global:SharedAks_kubeCalls.Count | Should -Be 0
    }
    It 'refuses to delete resources in an unowned namespace' {
        $global:SharedAks_namespace.metadata.labels = @{}
        { & $workloadScript -Cleanup -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*ownership label*'
        @($global:SharedAks_kubeCalls | Where-Object { $_[6] -eq 'delete' }).Count | Should -Be 0
        Test-Path $global:SharedAks_kubeCalls[0][1] | Should -BeFalse
    }
    It 'rejects incompatible pools without mutating infrastructure' -TestCases @(
        @{ Property = 'osSKU'; Value = 'AzureLinux' }
        @{ Property = 'count'; Value = 1 }
        @{ Property = 'vmSize'; Value = 'Standard_D4s_v5' }
        @{ Property = 'provisioningState'; Value = 'Failed' }
    ) {
        param($Property, $Value)
        $global:SharedAks_pool[$Property] = $Value
        { & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName 'aks-from-console' } | Should -Throw '*Expected two ready Ubuntu*'
        $global:SharedAks_kubeCalls.Count | Should -Be 0
    }
    It 'requires an explicit cluster rather than deriving one from attendee names' {
        { & $workloadScript -Deploy -ResourceGroup 'lab-test' -ClusterName '' } | Should -Throw '*AKS_CLUSTER*'
        $global:SharedAks_azCalls.Count | Should -Be 0
    }
    It 'has no unscoped kubectl or infrastructure mutation commands' {
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($workloadScript, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $commands = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)
        foreach ($command in $commands) {
            if ($command.GetCommandName() -eq 'kubectl') { $command.Extent.Text | Should -Match 'kubectl @kubectlScope' }
            if ($command.GetCommandName() -eq 'az') { $command.Extent.Text | Should -Not -Match 'az (aks (create|delete|nodepool (add|delete))|group delete)' }
        }
    }
}

Describe 'Shared AKS infrastructure contract' {
    It 'documents workload-only deployment and cleanup on the provided cluster' {
        $guide = Get-Content "$root/walkthrough/challenge-05/solution-05.md" -Raw
        $guide | Should -Not -Match 'Cleanup deletes the cluster|two separate sign-ins|Set-AzContext|CcNodeCount'
        $guide | Should -Match 'AKS_CLUSTER'
        $guide | Should -Match 'challenge-05'
    }
    It 'reserves four confidential and twelve standard vCPUs without a standalone VM' {
        $requirements = @(Get-MhhSovereignComputeRequirements -ConfidentialQuotaName 'standardDCasv6Family')
        ($requirements | Where-Object Name -eq 'standardDCasv6Family').PerParticipant | Should -Be 4
        ($requirements | Where-Object Name -eq 'StandardDSv5Family').PerParticipant | Should -Be 12
        ($requirements | Where-Object Name -eq 'cores').PerParticipant | Should -Be 16
        foreach ($scriptName in @('deploy-lab.ps1', 'shared-deploy-lab.ps1')) {
            Get-Content "$root/labautomation/$scriptName" -Raw | Should -Match 'Get-MhhSovereignComputeRequirements'
        }
        $defaults = Get-Content "$root/labautomation/lab-defaults.json" -Raw | ConvertFrom-Json
        $defaults.estimatedDailyCostsUsd | Should -Be 45
        $defaults.estimatedSharedDeploymentDailyCostsUsd | Should -Be 110
    }
    It 'removes obsolete resources and credentials while retaining two labeled Ubuntu confidential nodes' {
        $template = Get-Content "$root/labautomation/sovereign-lab.bicep" -Raw
        $template | Should -Not -Match 'cvmAdminPassword|resource confidentialVm |resource attestationProvider|cvmNic|snet-cvm'
        $template | Should -Match "(?s)resource confidentialNodePool .*?count: 2.*?osSKU: 'Ubuntu'.*?workload: 'confidential'"
        $deployer = Get-Content "$root/labautomation/deploy-lab.ps1" -Raw
        $deployer | Should -Not -Match 'cvmAdminPassword|confidentialVmName|attestationProviderName|Confidential VM Admin'
        $health = Get-Content "$root/resources/tests/sovereign-lab.health.tests.ps1" -Raw
        $health | Should -Not -Match 'confidentialVmName|attestationProviderName'
        $health | Should -Match 'Test-SovereignKubernetes \$Lab.AksKubeconfig 4'
    }
    It 'registers ACI and ACR before participant deployment' {
        $providers = Get-Content "$root/labautomation/resource-providers.ps1" -Raw
        $providers | Should -Match 'Microsoft.ContainerInstance'
        $providers | Should -Match 'Microsoft.ContainerRegistry'
        $providers | Should -Not -Match 'AzureLinuxCVMPreview'
        $manualProviders = Get-Content "$root/resources/manual-setup/subscription-preparations/1-resource-providers.ps1" -Raw
        $manualProviders | Should -Match 'Microsoft.ContainerInstance'
        $manualProviders | Should -Match 'Microsoft.ContainerRegistry'
        $manualProviders | Should -Not -Match 'AzureLinuxCVMPreview'
    }
}