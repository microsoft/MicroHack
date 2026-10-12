#!/usr/bin/env pwsh
<#
.SYNOPSIS
Checks the pure helper functions in baseInfra/scripts/facilitator-test-deploy.ps1 and the
source-archive challenge checks in both facilitator and VM provisioning scripts.

.DESCRIPTION
Loads only the function definitions out of the deployment script's AST, so the interactive
body never runs, then asserts HCL rendering, password rules, and compatibility with flat
and legacy source-archive challenge layouts. Exits non-zero when any expectation fails.

.EXAMPLE
pwsh tests/baseInfra/facilitator-test-deploy.helpers.tests.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../baseInfra/scripts/facilitator-test-deploy.ps1'))

$parseErrors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors) {
    $parseErrors | ForEach-Object {
        Write-Host "PARSE ERROR line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    exit 1
}

$functions = $ast.FindAll(
    { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
    $true)
foreach ($function in $functions) {
    . ([scriptblock]::Create($function.Extent.Text))
}

$failures = 0

function Assert-Equal {
    param(
        [Parameter(Mandatory)][string]$Label,
        $Actual,
        $Expected
    )

    if ("$Actual" -ceq "$Expected") {
        Write-Host "ok   $Label"
    }
    else {
        Write-Host "FAIL $Label" -ForegroundColor Red
        Write-Host "     actual   : $Actual"
        Write-Host "     expected : $Expected"
        $script:failures++
    }
}

Assert-Equal 'ConvertTo-HclList renders a quoted list' `
    (ConvertTo-HclList @('swedencentral', 'westeurope')) `
    '["swedencentral", "westeurope"]'

Assert-Equal 'ConvertTo-HclList renders an empty list' (ConvertTo-HclList @()) '[]'

Assert-Equal 'ConvertTo-HclString quotes a plain value' (ConvertTo-HclString 'azureuser') '"azureuser"'

# Windows state paths reach HCL through this helper, so backslashes must be escaped.
Assert-Equal 'ConvertTo-HclString escapes backslashes' `
    (ConvertTo-HclString 'C:\Users\fac\state.tfstate') `
    '"C:\\Users\\fac\\state.tfstate"'

Assert-Equal 'ConvertTo-HclString escapes quotes' (ConvertTo-HclString 'a"b') '"a\"b"'

Assert-Equal 'suggested test password is accepted' `
    (Test-WindowsPasswordComplexity 'MicroHack!Test2026') 'True'

Assert-Equal 'short password is rejected' (Test-WindowsPasswordComplexity 'Ab1!x') 'False'
Assert-Equal 'two character classes are rejected' `
    (Test-WindowsPasswordComplexity 'abcdefghijklmnop') 'False'
Assert-Equal 'three character classes are accepted' `
    (Test-WindowsPasswordComplexity 'abcdefghijkl1A') 'True'

# Terraform encodes a replacement as delete+create in either order, so -DryRun must not
# report those as two separate resources.
Assert-Equal 'create action' (Get-PlanAction -Actions @('create')) 'Create'
Assert-Equal 'update action' (Get-PlanAction -Actions @('update')) 'Update'
Assert-Equal 'delete action' (Get-PlanAction -Actions @('delete')) 'Delete'
Assert-Equal 'no-op action' (Get-PlanAction -Actions @('no-op')) 'No change'
Assert-Equal 'delete+create is a replacement' (Get-PlanAction -Actions @('delete', 'create')) 'Replace'
Assert-Equal 'create+delete is a replacement' (Get-PlanAction -Actions @('create', 'delete')) 'Replace'

# The module provisions through azapi_resource, so the Terraform type is identical for a
# resource group and a VM. The summary has to read the real ARM type out of the planned body.
$azapiVm = '{"type":"azapi_resource","address":"module.user_environment[\"1\"].azapi_resource.vm[\"dotnet\"]","change":{"actions":["create"],"after":{"type":"Microsoft.Compute/virtualMachines@2024-11-01","name":"vm-dotnet-user001"}}}' | ConvertFrom-Json
Assert-Equal 'azapi type drops the API version' (Get-PlanResourceType -Change $azapiVm) 'Microsoft.Compute/virtualMachines'
Assert-Equal 'azapi name comes from the body' (Get-PlanResourceName -Change $azapiVm) 'vm-dotnet-user001'

$plainResource = '{"type":"random_password","address":"module.x.random_password.db","change":{"actions":["create"],"after":{}}}' | ConvertFrom-Json
Assert-Equal 'non-azapi type is passed through' (Get-PlanResourceType -Change $plainResource) 'random_password'
Assert-Equal 'unnamed resource falls back to its address' (Get-PlanResourceName -Change $plainResource) 'module.x.random_password.db'

# A destroy has no "after" body at all, which must not throw under StrictMode.
$destroyed = '{"type":"azapi_resource","address":"module.x.azapi_resource.rg","change":{"actions":["delete"],"after":null}}' | ConvertFrom-Json
Assert-Equal 'destroyed azapi resource falls back to the Terraform type' (Get-PlanResourceType -Change $destroyed) 'azapi_resource'
Assert-Equal 'destroyed resource falls back to its address' (Get-PlanResourceName -Change $destroyed) 'module.x.azapi_resource.rg'

# An unchanged subscription yields a plan document with no resource_changes member at all,
# which reads as an error under StrictMode unless the property bag is indexed.
foreach ($document in @('{}', '{"resource_changes":[]}')) {
    $script:stubPlanJson = $document
    function Invoke-NativeJson { param($FilePath, $Arguments) $script:stubPlanJson | ConvertFrom-Json }
    $rendered = Show-PlanSummary -PlanFile 'tfplan' -SubscriptionName 'S' -SubscriptionId 'i' 6>&1 | Out-String
    Assert-Equal "empty plan is reported, not thrown: $document" ($rendered -match 'Plan is empty') 'True'
}

Assert-Equal 'flat challenge file in source archive' `
    (Test-ArchiveContainsChallenge -Entries @('challenges/ch01.md')) 'True'
Assert-Equal 'legacy challenge directory in source archive' `
    (Test-ArchiveContainsChallenge -Entries @('challenges/ch01/README.md')) 'True'
Assert-Equal 'unrelated challenge directory is insufficient' `
    (Test-ArchiveContainsChallenge -Entries @('challenges/ch01-A/README.md')) 'False'
Assert-Equal 'empty source archive is rejected' `
    (Test-ArchiveContainsChallenge -Entries @()) 'False'

$vmScriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../baseInfra/scripts/provision-vm.ps1'))
$vmParseErrors = $null
$vmTokens = $null
$vmAst = [System.Management.Automation.Language.Parser]::ParseFile($vmScriptPath, [ref]$vmTokens, [ref]$vmParseErrors)
if ($vmParseErrors) {
    throw "provision-vm.ps1 could not be parsed: $($vmParseErrors -join '; ')"
}
$sourceChallengeFunction = $vmAst.Find(
    { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-SourceArchiveChallenge' },
    $true)
if ($null -eq $sourceChallengeFunction) {
    throw 'Test-SourceArchiveChallenge was not found in provision-vm.ps1.'
}
. ([scriptblock]::Create($sourceChallengeFunction.Extent.Text))

$archiveRoot = Join-Path ([System.IO.Path]::GetTempPath()) "microhack-layout-$([guid]::NewGuid().ToString('N'))"
try {
    $challengeRoot = Join-Path $archiveRoot 'challenges'
    New-Item -ItemType Directory -Path $challengeRoot | Out-Null
    Assert-Equal 'missing challenge rejects VM source archive' `
        (Test-SourceArchiveChallenge -ArchiveRoot $archiveRoot) 'False'
    New-Item -ItemType File -Path (Join-Path $challengeRoot 'ch01.md') | Out-Null
    Assert-Equal 'flat challenge accepted for VM source archive' `
        (Test-SourceArchiveChallenge -ArchiveRoot $archiveRoot) 'True'
    Remove-Item -LiteralPath (Join-Path $challengeRoot 'ch01.md')
    New-Item -ItemType Directory -Path (Join-Path $challengeRoot 'ch01') | Out-Null
    Assert-Equal 'legacy challenge accepted for VM source archive' `
        (Test-SourceArchiveChallenge -ArchiveRoot $archiveRoot) 'True'
}
finally {
    if (Test-Path $archiveRoot) { Remove-Item -LiteralPath $archiveRoot -Recurse -Force }
}

Write-Host ''
if ($failures -gt 0) {
    Write-Host "$failures check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host 'All helper checks passed.' -ForegroundColor Green
