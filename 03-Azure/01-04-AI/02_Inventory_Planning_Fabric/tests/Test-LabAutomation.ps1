$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tokens = $null
$errors = $null
$deployAst = $null
foreach ($path in @(
    "$root\labautomation\deploy-lab.ps1",
    "$root\labautomation\shared-deploy-lab.ps1",
    "$root\dev\run-local.ps1"
)) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Parse errors in ${path}: $errors" }
    if ($path -like '*\deploy-lab.ps1') { $deployAst = $ast }
}
$function = $deployAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Ensure-LabModelDeployment'
}, $true)
if (-not $function) { throw 'Model deployment function not found.' }
. ([scriptblock]::Create($function.Extent.Text))

function Assert-True($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}
function Response($Status, $State = 'Succeeded', $Name = 'test-model', $Capacity = 200) {
    @{
        StatusCode = $Status
        Content = @{
            sku = @{ name = 'GlobalStandard'; capacity = $Capacity }
            properties = @{ provisioningState = $State; model = @{ name = $Name; version = 'v1' } }
        } | ConvertTo-Json -Depth 5
    }
}
function Invoke-AzRestMethod {
    param($Method, $Path, $Payload)
    $script:calls.Add(@{ Method = $Method; Payload = $Payload })
    if ($script:responses.Count -eq 0) { throw 'Unexpected REST call.' }
    $script:responses.Dequeue()
}
function Start-Sleep { param($Seconds) }
function Run-ModelCase($Responses, $ExpectedError = '') {
    $script:responses = [System.Collections.Queue]::new()
    foreach ($response in $Responses) { $script:responses.Enqueue($response) }
    $script:calls = [System.Collections.Generic.List[object]]::new()
    $actualError = ''
    try {
        Ensure-LabModelDeployment -Uri '/test' -Name 'test-model' -Version 'v1' -Capacity 200 -TimeoutSeconds 5
    } catch { $actualError = $_.Exception.Message }
    if ($ExpectedError) {
        Assert-True ($actualError -like "*$ExpectedError*") "Expected '$ExpectedError'; got '$actualError'."
    } else {
        Assert-True (-not $actualError) "Unexpected failure: $actualError"
    }
}

Run-ModelCase @((Response 404), (Response 202), (Response 200 'Creating'), (Response 200))
$body = ($script:calls | Where-Object Method -eq PUT).Payload | ConvertFrom-Json
Assert-True ($body.properties.model.name -eq 'test-model' -and $body.sku.capacity -eq 200) 'Requested configuration not used.'
Run-ModelCase @((Response 200), (Response 200))
Assert-True (-not ($script:calls | Where-Object Method -eq PUT)) 'Matching deployment should not be rewritten.'
Run-ModelCase @((Response 200 'Succeeded' 'test-model' 100), (Response 200), (Response 200))
Assert-True (@($script:calls | Where-Object Method -eq PUT).Count -eq 1) 'Capacity change was not applied.'
Run-ModelCase @((Response 403)) 'lookup failed'
Run-ModelCase @((Response 404), (Response 429)) 'create/update failed'
Run-ModelCase @((Response 200 'Failed'), (Response 200 'Failed')) 'reached Failed'
Run-ModelCase @((Response 200 'Canceled'), (Response 200 'Canceled')) 'reached Canceled'
Run-ModelCase @((Response 200 'Succeeded' 'other-model')) 'different model'
Run-ModelCase @((Response 404), (Response 202), (Response 200 'Creating'), (Response 200 'Creating')) 'within 5s'
Run-ModelCase @((Response 200), (Response 403)) 'verification failed'
Write-Host 'PASS: PowerShell parsing and 10 model deployment cases.'

function Get-AzContext { @{ Subscription = @{ Id = 'test-subscription' } } }
function Get-AzResourceProvider {
    param($ProviderNamespace)
    @{ RegistrationState = if ($global:InventoryLabProviderTest.NeverReady) { 'Registering' } elseif (
        $global:InventoryLabProviderTest.Registered.Contains($ProviderNamespace)) { 'Registered' } else { 'NotRegistered' } }
}
function Register-AzResourceProvider {
    param($ProviderNamespace)
    $global:InventoryLabProviderTest.Registrations++
    [void]$global:InventoryLabProviderTest.Registered.Add($ProviderNamespace)
}
$global:InventoryLabProviderTest = @{
    Registered = [System.Collections.Generic.HashSet[string]]::new()
    Registrations = 0
    NeverReady = $false
}
& "$root\labautomation\shared-deploy-lab.ps1" -SubscriptionId 'test-subscription' -PreferredLocation @('test')
Assert-True ($global:InventoryLabProviderTest.Registered.Contains('Microsoft.BotService')) 'BotService was not registered.'
Assert-True ($global:InventoryLabProviderTest.Registrations -eq 5) 'Expected five provider registrations.'
& "$root\labautomation\shared-deploy-lab.ps1" -SubscriptionId 'test-subscription' -PreferredLocation @('test')
Assert-True ($global:InventoryLabProviderTest.Registrations -eq 5) 'Second run registered providers again.'
$caught = ''
try { & "$root\labautomation\shared-deploy-lab.ps1" -SubscriptionId 'wrong' -PreferredLocation @('test') }
catch { $caught = $_.Exception.Message }
Assert-True ($caught -like '*does not match*') 'Wrong subscription was not rejected.'
$global:InventoryLabProviderTest.NeverReady = $true
$caught = ''
try { & "$root\labautomation\shared-deploy-lab.ps1" -SubscriptionId 'test-subscription' -PreferredLocation @('test') }
catch { $caught = $_.Exception.Message }
Assert-True ($caught -like '*within 300 seconds*') 'Provider registration did not time out.'
Write-Host 'PASS: Provider registration, idempotency, context and timeout cases.'
Remove-Variable -Name InventoryLabProviderTest -Scope Global
