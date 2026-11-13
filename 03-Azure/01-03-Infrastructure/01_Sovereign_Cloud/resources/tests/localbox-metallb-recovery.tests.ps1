BeforeAll {
    . "$PSScriptRoot/../prepare-localbox.ps1"
    . "$PSScriptRoot/../test-sovereign-cloud.ps1"
    . "$PSScriptRoot/../invoke-localbox-automation.ps1"
}

Describe 'Bounded hosted MetalLB runtime recovery' {
    BeforeEach {
        $oldSubscription = $env:subscriptionId
        $oldGroup = $env:resourceGroup
        $env:subscriptionId = '10000000-0000-0000-0000-000000000001'
        $env:resourceGroup = 'rg-localbox-test'
        $aksId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/localbox-aks"
        $configuration = @{
            AKSIPPrefix = '10.10.0.0/24'; AKSVIPStartIP = '10.10.0.10'; AKSVIPEndIP = '10.10.0.100'
            AKSGWIP = '10.10.0.1'; AKSControlPlaneIP = '10.10.0.5'
            AKSNodeStartIP = '10.10.0.101'; AKSNodeEndIP = '10.10.0.199'
        }
        $plan = Get-LocalBoxMetalLbPlan $configuration $aksId
        $manifest = @{
            SubscriptionId = $env:subscriptionId; ResourceGroupName = $env:resourceGroup
            AksId = $aksId; MetalLb = $plan
        }
        $pool = @{ id = $plan.PoolId; properties = @{
            addresses = @('10.10.0.10-10.10.0.100'); advertiseMode = 'ARP'; provisioningState = 'Succeeded'
            bgpPeers = $null; communities = $null; serviceSelector = $null
        } }
        $runtimePool = @{ metadata = @{ name = 'aks-pool'; namespace = 'kube-system' }; spec = @{
            addresses = @('10.10.0.10-10.10.0.100'); autoAssign = $true
        } }
        $advertisement = @{ metadata = @{ name = 'aks-pool'; namespace = 'kube-system' }; spec = @{ ipAddressPools = @('aks-pool') } }
        $probe = @{ Ready = $false; PoolVisible = $false; AdvertisementVisible = $false }
        $statePath = Join-Path $TestDrive "$([guid]::NewGuid()).json"
        $arguments = @{
            Manifest = $manifest; Configuration = $configuration; Kubeconfig = 'private.kubeconfig'
            StatePath = $statePath; GraceSeconds = 0; RecoverySeconds = 0
        }
        Mock Invoke-SovereignKubectl {
            if ($Arguments[1] -eq 'ipaddresspools.metallb.io') {
                return @{ items = @(if ($probe.Ready -or $probe.PoolVisible) { $runtimePool }) }
            }
            return @{ items = @(if ($probe.Ready -or $probe.AdvertisementVisible) { $advertisement }) }
        }
        Mock Get-LocalBoxResource {
            if ($Id -eq $plan.ExtensionId) { return @{ properties = @{ provisioningState = 'Succeeded'; extensionType = 'microsoft.arcnetworking' } } }
            return $pool
        }
        Mock Get-LocalBoxArmCollection { $pool }
        Mock Invoke-LocalBoxAz { $probe.Ready = $true }
        Mock Start-Sleep {}
    }
    AfterEach {
        $env:subscriptionId = $oldSubscription
        $env:resourceGroup = $oldGroup
    }
    It 'does nothing to Azure when both runtime objects already exist' {
        $probe.Ready = $true
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Invoke-LocalBoxAz -Times 0
        Should -Invoke Get-LocalBoxArmCollection -Times 0
        Test-Path $statePath | Should -BeFalse
    }
    It 'gives initial reconciliation a grace period without submitting a PUT' {
        $arguments.GraceSeconds = 60
        Mock Start-Sleep { $probe.Ready = $true }
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -gt 0 -and $Seconds -le 15 }
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'reapplies exactly the unchanged ARP configuration once and verifies convergence' {
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $body = $Arguments[$Arguments.IndexOf('--body') + 1] | ConvertFrom-Json -AsHashtable
            $Arguments[0..2] -join ' ' -eq 'rest --method put' -and
            $Arguments[$Arguments.IndexOf('--url') + 1] -eq "https://management.azure.com$($plan.PoolId)?api-version=2024-08-01" -and
            $body.properties.Count -eq 5 -and $body.properties.addresses[0] -eq '10.10.0.10-10.10.0.100' -and
            $body.properties.advertiseMode -eq 'ARP' -and $null -eq $body.properties.serviceSelector -and
            $null -eq $body.properties.bgpPeers -and $null -eq $body.properties.communities -and $TimeoutSeconds -eq 120 -and $NoOutput
        }
        (Get-Content $statePath -Raw | ConvertFrom-Json).State | Should -Be 'Succeeded'
        Should -Invoke Get-LocalBoxResource -Times 2 -Exactly -ParameterFilter { $TimeoutSeconds -eq 30 }
    }
    It 'also recovers when only the advertisement is absent' {
        $probe.PoolVisible = $true
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
    It 'also recovers when only the pool is absent' {
        $probe.AdvertisementVisible = $true
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
    It 'waits for Azure success as well as runtime readiness after the PUT' {
        $arguments.RecoverySeconds = 60
        Mock Invoke-LocalBoxAz { $probe.Ready = $true; $pool.properties.provisioningState = 'Updating' }
        Mock Start-Sleep { $pool.properties.provisioningState = 'Succeeded' }
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Start-Sleep -Times 1 -Exactly
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
    It 'stops at the recovery deadline even when Azure still claims success' {
        Mock Invoke-LocalBoxAz {}
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*exhausted after one PUT*ready=False*'
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0
        (Get-Content $statePath -Raw | ConvertFrom-Json).State | Should -Be 'Attempted'
    }
    It 'never resubmits after an ambiguous PUT failure or guest restart' {
        Mock Invoke-LocalBoxAz { throw 'Azure CLI timed out; submission may still be running.' }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*timed out*'
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*already recorded*'
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
    It 'permits a healthy resumed run without repeating the recorded recovery' {
        Set-Content $statePath '{"State":"Attempted"}'
        $probe.Ready = $true
        Sync-LocalBoxAutomationMetalLbRuntime @arguments
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'does not submit if the attempt marker cannot be written' {
        $arguments.StatePath = Join-Path $TestDrive 'absent-parent/attempt.json'
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects wrong <Field> scope before accessing Azure or Kubernetes' -TestCases @(
        @{ Field = 'SubscriptionId' }, @{ Field = 'ResourceGroupName' }, @{ Field = 'AksId' }
    ) {
        param($Field)
        $manifest[$Field] = 'other'
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*scope*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
        Should -Invoke Invoke-SovereignKubectl -Times 0
    }
    It 'rejects a manifest pool that differs from the installed network reservation' {
        $manifest.MetalLb.PoolExpected.properties.addresses = @('10.10.0.200-10.10.0.210')
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*Conflicting*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'does not interpret Kubernetes transport, permission or missing-CRD errors as missing objects' -TestCases @(
        @{ ErrorText = 'connection refused' }, @{ ErrorText = 'Forbidden' }, @{ ErrorText = 'server does not have resource type ipaddresspools' }
    ) {
        param($ErrorText)
        Mock Invoke-SovereignKubectl { throw $ErrorText }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw "*$ErrorText*"
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects malformed Kubernetes list responses' {
        Mock Invoke-SovereignKubectl { @{ items = $null } }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*Invalid MetalLB*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'refuses runtime conflicts: <Conflict>' -TestCases @(
        @{ Conflict = 'range' }, @{ Conflict = 'autoAssign' }, @{ Conflict = 'namespace' }, @{ Conflict = 'deleting' }
    ) {
        param($Conflict)
        $probe.PoolVisible = $true
        switch ($Conflict) {
            'range' { $runtimePool.spec.addresses = @('10.10.0.200-10.10.0.210') }
            'autoAssign' { $runtimePool.spec.autoAssign = $false }
            'namespace' { $runtimePool.metadata.namespace = 'other' }
            'deleting' { $runtimePool.metadata.deletionTimestamp = '2026-11-05T00:00:00Z' }
        }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects extra Azure pools rather than risking overlapping ranges' {
        Mock Get-LocalBoxArmCollection { $pool; @{ id = 'another-pool' } }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*additional pools*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects a missing Azure pool instead of creating a replacement' {
        Mock Get-LocalBoxArmCollection { @() }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*existing Azure-managed MetalLB pool is missing*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects an unsuccessful extension before reapplying the pool' {
        Mock Get-LocalBoxResource { @{ properties = @{ provisioningState = 'Failed'; extensionType = 'microsoft.arcnetworking' } } }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*Conflicting*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'does not overwrite a customized L2 advertisement: <Field>' -TestCases @(
        @{ Field = 'interfaces'; Value = @('eth0') },
        @{ Field = 'nodeSelectors'; Value = @(@{ matchLabels = @{ role = 'custom' } }) },
        @{ Field = 'ipAddressPoolSelectors'; Value = @(@{ matchLabels = @{ app = 'custom' } }) },
        @{ Field = 'ipAddressPools'; Value = @('other-pool') }
    ) {
        param($Field, $Value)
        $probe.AdvertisementVisible = $true
        $advertisement.spec[$Field] = $Value
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'refuses to race a deleting advertisement' {
        $probe.AdvertisementVisible = $true
        $advertisement.metadata.deletionTimestamp = '2026-11-05T00:00:00Z'
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*being deleted*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'rejects changed Azure <Field> configuration' -TestCases @(
        @{ Field = 'addresses'; Value = @('10.10.0.200-10.10.0.210') },
        @{ Field = 'advertiseMode'; Value = 'BGP' },
        @{ Field = 'provisioningState'; Value = 'Updating' },
        @{ Field = 'serviceSelector'; Value = @{ app = 'other' } },
        @{ Field = 'bgpPeers'; Value = @('peer') },
        @{ Field = 'communities'; Value = @('community') }
    ) {
        param($Field, $Value)
        $pool.properties[$Field] = $Value
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'propagates Azure authorization errors without writing an attempt marker' {
        Mock Get-LocalBoxArmCollection { throw 'AuthorizationFailed' }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*AuthorizationFailed*'
        Test-Path $statePath | Should -BeFalse
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'stops when the recovery PUT reaches a failed Azure state' {
        Mock Invoke-LocalBoxAz { $pool.properties.provisioningState = 'Failed' }
        { Sync-LocalBoxAutomationMetalLbRuntime @arguments } | Should -Throw '*recovery failed*Failed*'
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
}
