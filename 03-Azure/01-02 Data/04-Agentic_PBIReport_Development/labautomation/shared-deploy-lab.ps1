param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string[]]$PreferredLocation = @(),
    [Parameter(Mandatory = $false)]
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$config = Read-LabEventConfiguration
Assert-LabContext $config $SubscriptionId $PreferredLocation
$expected = @($config.participants | Where-Object subscriptionId -EQ $SubscriptionId | ForEach-Object objectId)
if ($expected.Count -eq 0 -or @(Compare-Object ($expected | Sort-Object) ($AllowedEntraUserIds | Sort-Object)).Count -ne 0) {
    throw 'Shared hook participants must exactly match the approved subscription roster.'
}
if (-not (Get-Command Get-MhhStableHash -ErrorAction SilentlyContinue)) { throw 'Required platform helper unavailable: Get-MhhStableHash' }
$suffix = Get-MhhStableHash -Value @($SubscriptionId) -Length 12
$resourceGroup = "rg-apbi-shared-$suffix"
$capacityName = "apbi$suffix"
$tags = @{
    LabEvent = $config.eventId; LabOwner = 'shared'; LabComponent = 'capacity'
    LabConfig = Get-LabFingerprint @{ region = $config.region; capacityAdministrators = $config.capacityAdministrators }
}
Assert-LabResourceGroup -Name $resourceGroup -Location $config.region -Tags $tags
# The deterministic name is subscription-wide, not participant- or event-derived.
$allCapacities = @(Invoke-LabAzureOperation { Get-AzResource -ResourceType 'Microsoft.Fabric/capacities' -ErrorAction Stop } 'Check subscription capacity collisions')
if (@($allCapacities | Where-Object { $_.Name -ne $capacityName -or $_.ResourceGroupName -ne $resourceGroup }).Count -gt 0) {
    throw 'Another Fabric capacity exists in this subscription. This bounded lab requires a dedicated subscription capacity inventory.'
}
$deployment = Invoke-LabAzureOperation {
    New-AzResourceGroupDeployment -Name 'apbi-shared' -ResourceGroupName $resourceGroup `
        -TemplateFile (Join-Path $PSScriptRoot 'shared.bicep') -TemplateParameterObject @{
            location = $config.region; capacityName = $capacityName
            capacityAdministrators = $config.capacityAdministrators; tags = $tags
        } -Mode Incremental -ErrorAction Stop -Verbose:$false -Debug:$false
} 'Shared F16 ARM deployment'
if ($deployment.ProvisioningState -ne 'Succeeded') { throw 'Shared F16 ARM deployment did not complete successfully.' }
@{ HackboxCredential = @{ name = 'Shared capacity'; value = $capacityName; note = "F16 in $resourceGroup. No participant capacity-administrator grants. Create your workspace with Copilot in Challenge 1." } }
