param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [string]$ResourceGroupName = '',
    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'automation-common.ps1')
if ($DeploymentType -ne 'resourcegroup') { throw 'Only the resourcegroup platform contract is supported; subscription-owner delivery is not approved.' }
$runtime = Get-LabPlatformContext $SubscriptionId $PreferredLocation $AllowedEntraUserIds
$settings = $runtime.Settings
if ($AllowedEntraUserIds.Count -ne 1) { throw 'Exactly one participant identity is required.' }
if ([string]::IsNullOrWhiteSpace($ResourceGroupName) -or $ResourceGroupName -like 'rg-apbi-shared-*') { throw 'A nonshared platform resource group is required.' }
foreach ($helper in 'Get-MhhStableHash', 'New-MhhStablePassword') {
    if (-not (Get-Command $helper -ErrorAction SilentlyContinue)) { throw "Required platform helper unavailable: $helper" }
}
$suffix = Get-MhhStableHash -Value @($settings.EventId, $SubscriptionId, $ResourceGroupName, $AllowedEntraUserIds[0]) -Length 12
$sharedSuffix = Get-MhhStableHash -Value @($SubscriptionId) -Length 12
$sharedGroup = "rg-apbi-shared-$sharedSuffix"
$shared = @(Invoke-LabAzureOperation { Get-AzResource -ResourceGroupName $sharedGroup -ErrorAction Stop } 'Read shared capacity')
$capacity = @($shared | Where-Object { $_.ResourceType -eq 'Microsoft.Fabric/capacities' })
if ($capacity.Count -ne 1 -or $capacity[0].Tags['LabEvent'] -ne $settings.EventId -or $capacity[0].Tags['LabOwner'] -ne 'shared') {
    throw 'The owned shared capacity must be provisioned first.'
}
$sharedDetail = Invoke-LabArmRequest -Method GET -Path "$($capacity[0].ResourceId)?api-version=2023-11-01"
if ($sharedDetail.sku.name -ne 'F16' -or $sharedDetail.properties.provisioningState -ne 'Succeeded' -or $sharedDetail.properties.state -ne 'Active') {
    throw 'Shared F16 is not successfully provisioned and active.'
}
$region = $capacity[0].Tags['LabRegion']
if ($region -notin $runtime.Regions) { throw 'Shared deployment region is not among the supplied preferences.' }
$image = $settings.Image.Clone()
$image.version = $capacity[0].Tags['LabImageVersion']
if ($image.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Shared deployment did not retain an exact image version.' }
$network = @($shared | Where-Object { $_.ResourceType -eq 'Microsoft.Network/virtualNetworks' -and $_.Name -eq "vnet-$sharedSuffix" })
if ($network.Count -ne 1 -or $network[0].Tags['LabOwner'] -ne 'shared') { throw 'Owned shared Bastion network is missing.' }
$subnetName = 'participant-' + (Get-MhhStableHash -Value @($AllowedEntraUserIds[0]) -Length 12)
$subnetId = "$($network[0].ResourceId)/subnets/$subnetName"
$null = Invoke-LabArmRequest -Path "$($subnetId)?api-version=2024-05-01"
$bootstrapConfig = Get-LabGuestConfiguration $settings
$fingerprint = Get-LabFingerprint @{
    settings = $settings; guest = $bootstrapConfig; image = $image; subnet = $subnetId
}
$tags = @{ LabEvent = $settings.EventId; LabOwner = $suffix; LabComponent = 'participant'; LabConfig = $fingerprint }
Assert-LabResourceGroup -Name $ResourceGroupName -Location $region -Tags $tags -ClaimEmpty `
    -ImplicitVmId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$suffix"
$securePassword = New-MhhStablePassword -Purpose 'apbi-vm-admin' -Length 24 -AsSecureString
if ($securePassword -isnot [securestring]) { throw 'Platform password helper did not return a SecureString.' }
$encodedBootstrap = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-LabCanonicalJson $bootstrapConfig)))
$parameters = @{
    location = $region
    suffix = $suffix
    tags = $tags
    adminUsername = "lab$suffix"
    adminPassword = $securePassword
    vmSize = $settings.VmSize
    image = $image
    osDiskSizeGB = $settings.OsDiskSizeGB
    subnetId = $subnetId
    bootstrapConfigurationBase64 = $encodedBootstrap
    bootstrapRunId = [DateTimeOffset]::UtcNow.ToString('o')
}
$deployment = Invoke-LabAzureOperation {
    New-AzResourceGroupDeployment -Name "apbi-$suffix" -ResourceGroupName $ResourceGroupName `
        -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') -TemplateParameterObject $parameters `
        -Mode Incremental -ErrorAction Stop -Verbose:$false -Debug:$false
} 'Participant ARM deployment (inspect sanitized operation status privately on failure)'
if ($deployment.ProvisioningState -ne 'Succeeded') { throw 'Participant ARM deployment did not complete successfully.' }
# Azure creates the OS disk implicitly; stamp it only after verifying its owning VM.
Assert-LabResourceGroup -Name $ResourceGroupName -Location $region -Tags $tags `
    -ImplicitVmId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$suffix"
# No template or Azure response is streamed to the dashboard.
@{ HackboxCredential = @{ name = 'VM username'; value = "lab$suffix"; note = "VM vm-$suffix in $ResourceGroupName" } }
$plainPassword = New-MhhStablePassword -Purpose 'apbi-vm-admin' -Length 24
@{ HackboxCredential = @{ name = 'VM password'; value = $plainPassword; note = 'Participant only; do not share or put in transcripts.' } }
$plainPassword = $null
$securePassword.Dispose()
@{ HackboxCredential = @{ name = 'Shared capacity resource'; value = $capacity[0].ResourceId; note = 'Challenge 1: use Copilot to create and assign your own Fabric workspace; no workspace is pre-created.' } }
@{ HackboxCredential = @{ name = 'Connect to private VM'; value = "https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$suffix/connect"; note = "Select Bastion and use your VM credentials. No VM public IP. Shared Bastion: bastion-$sharedSuffix in $sharedGroup." } }
