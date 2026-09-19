#Requires -Version 7.0
<#
.SYNOPSIS
Runs Pester health checks against explicitly selected Sovereign Cloud lab scopes.
.DESCRIPTION
Uses the caller's Azure CLI login. Never changes authentication or provisions resources.
Full checks require kubeconfigs and, for participant guest probes, explicit consent
to invoke read-only commands using Azure VM Run Command. See tests/readme.md.
.EXAMPLE
./test-sovereign-cloud.ps1 -Scope LocalBox -LocalBoxManifestPath ./sovereign-localbox.json -Mode ControlPlane
.EXAMPLE
./test-sovereign-cloud.ps1 -InventoryPath ./inventory.json -AllowGuestRunCommand
#>
[CmdletBinding()]
param(
    [ValidateSet('LocalBox', 'ParticipantLabs', 'All')][string]$Scope = 'All',
    [ValidateSet('ControlPlane', 'Full')][string]$Mode = 'Full',
    [string]$InventoryPath,
    [string]$LocalBoxManifestPath,
    [string]$LocalBoxKubeconfig,
    [pscredential]$NodeCredential,
    [switch]$AllowGuestRunCommand,
    [ValidateRange(1, 120)][int]$TimeoutMinutes = 15,
    [string]$OutputDirectory = './health-results',
    [string]$GitHubRef = 'main',
    [switch]$DownloadTests
)

function Invoke-SovereignKubectl {
    param([string]$Kubeconfig, [string[]]$Arguments)
    if (-not $Kubeconfig -or -not (Test-Path -LiteralPath $Kubeconfig)) { throw 'A valid, independently authenticated kubeconfig is required for Full checks.' }
    $output = & kubectl --kubeconfig $Kubeconfig --request-timeout=20s @Arguments -o json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "kubectl failed: $($output -join ' ')" }
    ($output -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop
}

function Assert-SovereignNodes {
    param($Nodes, [int]$MinimumCount)
    if (@($Nodes.items).Count -lt $MinimumCount) { throw "Expected at least $MinimumCount Kubernetes nodes." }
    foreach ($node in $Nodes.items) {
        $ready = @($node.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' })
        if ($ready.Count -ne 1) { throw "Node $($node.metadata.name) is not Ready." }
    }
}

function Assert-SovereignSystemPods {
    param($Pods)
    $systemPods = @($Pods.items | Where-Object { $_.metadata.namespace -in @('kube-system', 'azure-arc', 'aks-istio-system') })
    if (-not $systemPods.Count) { throw 'No system pods returned; health cannot be established.' }
    foreach ($pod in $systemPods) {
        if ($pod.status.phase -eq 'Succeeded') { continue }
        $ready = @($pod.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' })
        if ($pod.status.phase -ne 'Running' -or $ready.Count -ne 1) { throw "System pod $($pod.metadata.namespace)/$($pod.metadata.name) is not healthy." }
        foreach ($container in @($pod.status.containerStatuses)) {
            if (-not $container.ready -or $container.state.waiting) { throw "Container $($container.name) is not ready." }
        }
    }
}

function Test-SovereignKubernetes {
    param([string]$Kubeconfig, [int]$MinimumNodes)
    Assert-SovereignNodes (Invoke-SovereignKubectl $Kubeconfig @('get', 'nodes')) $MinimumNodes
    Assert-SovereignSystemPods (Invoke-SovereignKubectl $Kubeconfig @('get', 'pods', '-A'))
    $controllers = Invoke-SovereignKubectl $Kubeconfig @('get', 'deployments,daemonsets', '-n', 'kube-system')
    if (-not @($controllers.items).Count) { throw 'No kube-system controllers found.' }
    foreach ($controller in $controllers.items) {
        if ($controller.kind -eq 'DaemonSet') {
            if ($controller.status.desiredNumberScheduled -lt 1 -or $controller.status.numberReady -lt $controller.status.desiredNumberScheduled) { throw "DaemonSet $($controller.metadata.name) is unavailable." }
        }
        elseif ($controller.spec.replicas -gt 0 -and $controller.status.availableReplicas -lt $controller.spec.replicas) {
            throw "Deployment $($controller.metadata.name) is unavailable."
        }
    }
}

function Wait-SovereignCheck {
    param([scriptblock]$Check, [int]$TimeoutSeconds = 900)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try { & $Check; return }
        catch {
            if ($_.Exception.Message -match 'AuthorizationFailed|Forbidden|Unauthorized|InvalidAuthentication|not logged in|independently authenticated|provisioning failed') { throw }
            if ([datetime]::UtcNow -ge $deadline) { throw }
            Start-Sleep -Seconds 15
        }
    } while ($true)
}

function Get-SovereignLabOutputs {
    param([hashtable]$Lab)
    if ($Lab.Outputs) { return $Lab.Outputs }
    if (-not $Lab.DeploymentName) { throw 'Each lab requires DeploymentName or explicit Outputs; resource enumeration is not an expected inventory.' }
    $deployment = Invoke-LocalBoxAz @('deployment', 'group', 'show', '--subscription', $Lab.SubscriptionId,
        '--resource-group', $Lab.ResourceGroupName, '--name', $Lab.DeploymentName)
    if ($deployment.properties.provisioningState -ne 'Succeeded') { throw 'The selected lab deployment did not succeed.' }
    $outputs = @{}
    foreach ($key in $deployment.properties.outputs.Keys) { $outputs[$key] = $deployment.properties.outputs[$key].value }
    return $outputs
}

function Get-SovereignReadiness {
    param($Result, [string]$Mode)
    return $Mode -eq 'Full' -and $Result.TotalCount -gt 0 -and $Result.FailedCount -eq 0 -and
        $Result.SkippedCount -eq 0 -and $Result.NotRunCount -eq 0 -and $Result.PassedCount -eq $Result.TotalCount
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    $root = $PSScriptRoot
    if ($DownloadTests) {
        $root = Join-Path ([IO.Path]::GetTempPath()) "microhack-health-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path "$root/tests" -Force | Out-Null
        $base = "https://raw.githubusercontent.com/microsoft/MicroHack/$GitHubRef/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources"
        foreach ($file in @('prepare-localbox.ps1', 'test-sovereign-cloud.ps1', 'tests/localbox.health.tests.ps1', 'tests/sovereign-lab.health.tests.ps1')) {
            Invoke-WebRequest -Uri "$base/$file" -OutFile (Join-Path $root $file)
        }
    }
    Import-Module Pester -MinimumVersion 5.7.1 -MaximumVersion 5.999.999 -ErrorAction Stop
    $inventory = if ($InventoryPath) { Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    if ($LocalBoxManifestPath) { $inventory.LocalBox = Get-Content -LiteralPath $LocalBoxManifestPath -Raw | ConvertFrom-Json -AsHashtable }
    if ($LocalBoxKubeconfig) { $inventory.LocalBox.Kubeconfig = $LocalBoxKubeconfig }
    $containers = @()
    $data = @{ Mode = $Mode; TimeoutSeconds = $TimeoutMinutes * 60; ResourceRoot = $root }
    if ($Scope -in @('LocalBox', 'All')) {
        if (-not $inventory.LocalBox) { throw 'LocalBox scope requires a preparation manifest, or LocalBox in the inventory.' }
        $containers += New-PesterContainer -Path "$root/tests/localbox.health.tests.ps1" -Data ($data + @{ LocalBox = $inventory.LocalBox; NodeCredential = $NodeCredential })
    }
    if ($Scope -in @('ParticipantLabs', 'All')) {
        if (-not $inventory.Labs -or -not @($inventory.Labs).Count) { throw 'ParticipantLabs scope requires a nonempty Labs inventory.' }
        foreach ($lab in $inventory.Labs) {
            if (-not $lab.SubscriptionId -or -not $lab.ResourceGroupName) { throw 'Every lab must specify SubscriptionId and ResourceGroupName.' }
            $containers += New-PesterContainer -Path "$root/tests/sovereign-lab.health.tests.ps1" -Data ($data + @{ Lab = $lab; AllowGuestRunCommand = [bool]$AllowGuestRunCommand })
        }
    }
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $configuration = New-PesterConfiguration
    $configuration.Run.Container = $containers
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = Join-Path $OutputDirectory 'health.xml'
    $result = Invoke-Pester -Configuration $configuration
    $ready = Get-SovereignReadiness $result $Mode
    @{
        Timestamp = [datetime]::UtcNow.ToString('o'); Scope = $Scope; Mode = $Mode; FullReadiness = $ready
        Passed = $result.PassedCount; Failed = $result.FailedCount; Skipped = $result.SkippedCount; NotRun = $result.NotRunCount
        Tests = @($result.Tests | ForEach-Object { @{ Name = $_.ExpandedPath; Result = $_.Result } })
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'health.json') -Encoding utf8
    if ($result.FailedCount -or ($Mode -eq 'Full' -and -not $ready)) { exit 1 }
    if ($Mode -eq 'ControlPlane') { Write-Warning 'Control-plane checks passed. Runtime health has NOT been verified.' }
}