<#
.SYNOPSIS
Prepares a subscription for Sovereign Cloud MicroHack labs.
.DESCRIPTION
Runs once per subscription before participant lab deployments and registers the
required Azure resource providers. LocalBox deployment is temporarily disabled.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

Write-Host "Preparing subscription $SubscriptionId for Sovereign Cloud labs..."
& (Join-Path $PSScriptRoot 'resource-providers.ps1')

if (-not $?) {
    throw "Resource provider registration failed for subscription $SubscriptionId."
}
<#

The Sovereign Cloud shared deployment needs to resolve the tenant-specific object ID of the Microsoft.AzureStackHCI enterprise application (appId: 1412d89f-b8a8-4111-b4fd-e82905cbd85d).
Disabled Localbox until this is resolved, as the deployment will fail with an InsufficientPermissions error when the service principal cannot be resolved.

$localBoxResourceGroupName = 'rg-localbox-shared'
$localBoxLocation = if ($PreferredLocation.Count -gt 0) { $PreferredLocation[0] } else { 'swedencentral' }
$activeDeploymentStates = @('Accepted', 'Running', 'Ready', 'Creating', 'Created', 'Succeeded')
$resourceGroup = Get-AzResourceGroup -Name $localBoxResourceGroupName -ErrorAction SilentlyContinue
$localBoxDeployment = if ($resourceGroup) {
    Get-AzResourceGroupDeployment `
        -ResourceGroupName $localBoxResourceGroupName `
        -ErrorAction Stop |
        Where-Object {
            $_.DeploymentName -like 'localbox-*' -and
            $_.ProvisioningState -in $activeDeploymentStates
        } |
        Sort-Object Timestamp -Descending |
        Select-Object -First 1
}

if ($localBoxDeployment) {
    Write-Host "Reusing LocalBox deployment '$($localBoxDeployment.DeploymentName)' ($($localBoxDeployment.ProvisioningState))." -ForegroundColor Green
}
else {
    Write-Host "Submitting shared LocalBox deployment in $localBoxLocation..." -ForegroundColor Cyan
    $localBoxDeployment = & (Join-Path $PSScriptRoot 'deploy-localbox.ps1') `
        -SubscriptionId $SubscriptionId `
        -ResourceGroupName $localBoxResourceGroupName `
        -Location $localBoxLocation `
        -NoWait

    if (-not $? -or -not $localBoxDeployment -or $localBoxDeployment.ProvisioningState -ne 'Submitted') {
        throw "LocalBox deployment submission failed for subscription $SubscriptionId."
    }
}


$localBoxScope = "/subscriptions/$SubscriptionId/resourceGroups/$localBoxResourceGroupName"
foreach ($participantObjectId in $AllowedEntraUserIds) {
    foreach ($roleName in @('Reader', 'Azure Stack HCI VM Contributor')) {
        $roleAssignment = Get-AzRoleAssignment `
            -ObjectId $participantObjectId `
            -RoleDefinitionName $roleName `
            -Scope $localBoxScope `
            -ErrorAction SilentlyContinue

        if (-not $roleAssignment) {
            Write-Host "Assigning '$roleName' on shared LocalBox to $participantObjectId..."
            New-AzRoleAssignment `
                -ObjectId $participantObjectId `
                -RoleDefinitionName $roleName `
                -Scope $localBoxScope `
                -ErrorAction Stop | Out-Null
        }
    }
}

@{
    'HackboxCredential' = @{
        name = 'Shared LocalBox Resource Group'
        value = $localBoxResourceGroupName
        note = 'Shared Challenge 6 environment; readiness is verified by the facilitator'
    }
}
#>