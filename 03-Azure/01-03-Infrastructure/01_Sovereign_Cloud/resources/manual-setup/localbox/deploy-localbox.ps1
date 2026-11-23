#Requires -Version 7.0
<#
.SYNOPSIS
Interactively deploys Azure Arc Jumpstart LocalBox using the shared lab deployer.
.DESCRIPTION
Uses the same Developer Bastion network module and deployment validation as the
Console path, without enabling hosted subscription policies or Defender plans.
Required resource providers must already be registered.
.PARAMETER DeployBastion
Deploy Bastion Developer for one browser-based coach connection at a time.
Existing dedicated Bastions are not automatically downgraded or deleted.
.PARAMETER AzureLocalInstanceLocation
Azure Local registration and staging storage region, independent of the host region.
.EXAMPLE
.\deploy-localbox.ps1 -ResourceGroupName rg-localbox -Location swedencentral
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [string]$Location = 'swedencentral',
    [string]$WindowsAdminUsername = 'arcdemo',
    [bool]$DeployBastion = $true,
    [string]$GithubAccount = 'microsoft',
    [string]$GithubBranch = 'main',
    [ValidateSet('australiaeast', 'southcentralus', 'eastus', 'westeurope', 'southeastasia', 'canadacentral', 'japaneast', 'centralindia')]
    [string]$AzureLocalInstanceLocation = 'australiaeast'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Sign in with az login before running this script.'
}
$accountJson = & az account show --output json --only-show-errors
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Not logged in to Azure CLI. Please sign in.' -ForegroundColor Yellow
    & az login --only-show-errors --output none
    if ($LASTEXITCODE -ne 0) { throw 'Azure CLI sign-in failed.' }
    $accountJson = & az account show --output json --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Azure account after sign-in.' }
}
$account = $accountJson | ConvertFrom-Json -ErrorAction Stop

Write-Host "Deploying LocalBox in $Location using subscription $($account.name)." -ForegroundColor Cyan
Write-Warning 'LocalBox requires at least 32 available Esv6-family vCPUs and several hours of nested provisioning. Bastion Developer supports one browser connection at a time.'
if ((Read-Host 'Continue? (y/N)') -ine 'y') {
    Write-Host 'Deployment cancelled.'
    return
}

$password = Read-Host -Prompt 'Enter admin password for the host VM' -MaskInput
try {
    $deployer = Join-Path $PSScriptRoot '../../../labautomation/deploy-localbox.ps1'
    $deployment = & $deployer -SubscriptionId $account.id -ResourceGroupName $ResourceGroupName `
        -Location $Location -WindowsAdminUsername $WindowsAdminUsername -WindowsAdminPassword $password `
        -DeployBastion $DeployBastion -GithubAccount $GithubAccount -GithubRef $GithubBranch `
        -AzureLocalInstanceLocation $AzureLocalInstanceLocation -NoWait
    Write-Host "Submitted $($deployment.DeploymentName). Monitor the resource group's Deployments page; ARM completion is not nested readiness." -ForegroundColor Green
    $deployment
}
finally {
    $password = $null
}
