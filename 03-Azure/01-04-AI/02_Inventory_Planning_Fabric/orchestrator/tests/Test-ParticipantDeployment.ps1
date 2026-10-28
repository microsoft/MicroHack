#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("inventory-bootstrap-test-" + [guid]::NewGuid().ToString('N'))
$global:InventoryBootstrapCalls = [Collections.Generic.List[string]]::new()
$global:InventoryBootstrapPipInstalls = 0
$global:InventoryBootstrapSubscription = 'test-subscription'
$global:InventoryBootstrapConnections = @('test-connection')
$global:InventoryBootstrapPins = @{
    DEMAND_AGENT_NAME = 'demand-sensing-agent'; DEMAND_AGENT_VERSION = '8'
    OPTIMISATION_AGENT_NAME = 'inventory-optimisation-agent'; OPTIMISATION_AGENT_VERSION = '6'
    REPLENISHMENT_AGENT_NAME = 'replenishment-action-agent'; REPLENISHMENT_AGENT_VERSION = '4'
    TOOLBOX_ENDPOINT = 'https://test-account.services.ai.azure.com/api/projects/test-project/toolboxes/inventory-fabric-iq/versions/1/mcp?api-version=v1'
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function global:az {
    $global:LASTEXITCODE = 0
    $global:InventoryBootstrapCalls.Add("az $($args -join ' ')")
    switch ("$($args[0]) $($args[1])") {
        'account show' { $global:InventoryBootstrapSubscription }
        'resource list' {
            if ($args -contains 'Microsoft.CognitiveServices/accounts/projects') { 'test-account/test-project' }
            else { "/subscriptions/test-subscription/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-account" }
        }
        'resource show' { "/subscriptions/test-subscription/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/test-account/projects/test-project" }
        'rest --method' { $global:InventoryBootstrapConnections }
        default { throw "Unexpected az invocation: $args" }
    }
}
function global:azd {
    $global:LASTEXITCODE = 0
    $global:InventoryBootstrapCalls.Add("azd $($args -join ' ')")
    switch ("$($args[0]) $($args[1])") {
        'version ' { 'azd version 1.34.2' }
        'extension list' { '[{"id":"azure.ai.agents","installedVersion":"1.0.0-beta.19"},{"id":"azure.ai.projects","installedVersion":"1.0.0-beta.13"}]' }
        'config set' { }
        'auth login' { }
        'env list' { '[{"Name":"inventory-hosted"}]' }
        'env set' { }
        'env get-value' { '7' }
        'deploy inventory-planning-assistant' { }
        default { throw "Unexpected azd invocation: $args" }
    }
}
function global:python3 { $global:LASTEXITCODE = 0 }
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    foreach ($name in @('Start-ParticipantDeployment.ps1', 'Deploy-Orchestrator.ps1', 'requirements-tools.txt')) {
        Copy-Item -LiteralPath (Join-Path $source $name) -Destination $fixture
    }
    $bin = Join-Path $fixture '.venv-tools/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $python = Join-Path $bin 'python'
    [IO.File]::WriteAllText($python, '')
    Set-Item -LiteralPath "Function:\$python" -Value {
        $global:LASTEXITCODE = 0
        $global:InventoryBootstrapCalls.Add("python $($args -join ' ')")
        if ($args[0] -eq '-m') { $global:InventoryBootstrapPipInstalls++; return }
        if ($args[0] -like '*configure_specialists.py') { $global:InventoryBootstrapPins | ConvertTo-Json -Compress }
    }
    Set-Variable IsLinux -Value $true -Force
    $parameters = @{
        SubscriptionId = 'test-subscription'; ResourceGroupName = 'test-rg'
        ProjectEndpoint = 'https://test-account.services.ai.azure.com/api/projects/test-project'
        FabricIQConnectionName = 'test-connection'
    }
    & (Join-Path $fixture 'Start-ParticipantDeployment.ps1') @parameters -VerifyHosted
    Assert-True ($global:InventoryBootstrapPipInstalls -eq 1) 'Tooling dependencies must be restored on first run.'
    Assert-True ($global:InventoryBootstrapCalls.Contains('azd config set auth.useAzCliAuth true')) 'Must reuse Cloud Shell Azure CLI authentication.'
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like '*verify_hosted.py*--version 7*' })) 'Must verify the actual deployed hosted version.'
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like 'azd env set DEMAND_AGENT_VERSION 8 *' })) 'Must pin a concrete saved specialist version.'
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like 'python *configure_specialists.py --export-specialists' })) 'Must snapshot the pinned specialists before packaging, so the hosted runtime needs no agent-read permission.'
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like 'azd env set TOOLBOX_ENDPOINT *toolboxes/inventory-fabric-iq/versions/1/mcp*' })) 'Must pin the Fabric IQ toolbox endpoint for the hosted assistant.'
    Assert-True (-not [bool]($global:InventoryBootstrapCalls | Where-Object { $_ -match 'azd provision|role assignment|provider register|use-device-code|--password|--client-secret' })) 'Bootstrap must not provision, escalate roles or collect credentials.'
    $before = @($global:InventoryBootstrapCalls | Where-Object { $_ -like 'azd deploy *' }).Count
    & (Join-Path $fixture 'Start-ParticipantDeployment.ps1') @parameters -ConfigureOnly
    Assert-True ($global:InventoryBootstrapPipInstalls -eq 1) 'Unchanged tooling requirements must not be restored repeatedly.'
    Assert-True (@($global:InventoryBootstrapCalls | Where-Object { $_ -like 'azd deploy *' }).Count -eq $before) 'ConfigureOnly must not deploy.'
    $global:InventoryBootstrapSubscription = 'wrong-subscription'
    $blocked = $false
    try { & (Join-Path $fixture 'Start-ParticipantDeployment.ps1') @parameters }
    catch {
        if ($_.Exception.Message -notlike '*assigned lab subscription*') { throw }
        $blocked = $true
    }
    Assert-True $blocked 'Wrong subscription must stop the bootstrap.'
    $global:InventoryBootstrapSubscription = 'test-subscription'

    # Only the resource group is required: subscription, project and connection are detected.
    $global:InventoryBootstrapCalls.Clear()
    & (Join-Path $fixture 'Start-ParticipantDeployment.ps1') -ResourceGroupName 'test-rg' -ConfigureOnly
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like 'python *configure_specialists.py*--connection-name test-connection*' })) 'Must detect the single Fabric IQ connection.'
    Assert-True ([bool]($global:InventoryBootstrapCalls | Where-Object { $_ -like 'azd env set FOUNDRY_PROJECT_ENDPOINT https://test-account.services.ai.azure.com/api/projects/test-project *' })) 'Must derive the project endpoint from the resource group.'
    foreach ($case in @(
        @{ Connections = @(); Expected = '*No Fabric IQ connection found*' },
        @{ Connections = @('one', 'two'); Expected = '*More than one Fabric IQ connection*' }
    )) {
        $global:InventoryBootstrapConnections = $case.Connections
        $stopped = $false
        try { & (Join-Path $fixture 'Start-ParticipantDeployment.ps1') -ResourceGroupName 'test-rg' -ConfigureOnly }
        catch {
            if ($_.Exception.Message -notlike $case.Expected) { throw }
            $stopped = $true
        }
        Assert-True $stopped "Connection lookup '$($case.Connections -join ',')' must stop with a clear message."
    }
    $global:InventoryBootstrapConnections = @('test-connection')
    Write-Host 'PASS: participant bootstrap command flow, pinned versions, authentication, repeat run, auto-detection and scope guards (mocked CLIs).'
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
