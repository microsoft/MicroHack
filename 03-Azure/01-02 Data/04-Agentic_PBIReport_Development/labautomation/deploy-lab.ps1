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
$config = Read-LabEventConfiguration
Assert-LabContext $config $SubscriptionId $PreferredLocation
if ($AllowedEntraUserIds.Count -ne 1) { throw 'Exactly one participant identity is required.' }
$participant = @($config.participants | Where-Object {
    $_.objectId -eq $AllowedEntraUserIds[0] -and $_.subscriptionId -eq $SubscriptionId -and $_.resourceGroupName -eq $ResourceGroupName
})
if ($participant.Count -ne 1) { throw 'Participant identity, subscription and resource group must match the approved roster.' }
foreach ($helper in 'Get-MhhStableHash', 'New-MhhStablePassword') {
    if (-not (Get-Command $helper -ErrorAction SilentlyContinue)) { throw "Required platform helper unavailable: $helper" }
}
$suffix = Get-MhhStableHash -Value @($config.eventId, $SubscriptionId, $ResourceGroupName, $AllowedEntraUserIds[0]) -Length 12
$sharedSuffix = Get-MhhStableHash -Value @($SubscriptionId) -Length 12
$sharedGroup = "rg-apbi-shared-$sharedSuffix"
$shared = @(Invoke-LabAzureOperation { Get-AzResource -ResourceGroupName $sharedGroup -ErrorAction Stop } 'Read shared capacity')
$capacity = @($shared | Where-Object { $_.ResourceType -eq 'Microsoft.Fabric/capacities' })
if ($capacity.Count -ne 1 -or $capacity[0].Tags['LabEvent'] -ne $config.eventId -or $capacity[0].Tags['LabOwner'] -ne 'shared') {
    throw 'The owned shared capacity must be provisioned first.'
}
$sharedDetail = Invoke-LabArmRequest -Method GET -Path "$($capacity[0].ResourceId)?api-version=2023-11-01"
if ($sharedDetail.sku.name -ne 'F16' -or $sharedDetail.properties.provisioningState -ne 'Succeeded' -or $sharedDetail.properties.state -ne 'Active') {
    throw 'Shared F16 is not successfully provisioned and active.'
}
$fingerprint = Get-LabFingerprint @{
    vm = $config.vm; bootstrap = $config.bootstrap; source = $config.source; tools = $config.tools
    hosts = $config.hosts; sourceAddressPrefix = $participant[0].sourceAddressPrefix
}
$tags = @{ LabEvent = $config.eventId; LabOwner = $suffix; LabComponent = 'participant'; LabConfig = $fingerprint }
Assert-LabResourceGroup -Name $ResourceGroupName -Location $config.region -Tags $tags -ClaimEmpty `
    -ImplicitVmId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$suffix"
$securePassword = New-MhhStablePassword -Purpose 'apbi-vm-admin' -Length 24 -AsSecureString
if ($securePassword -isnot [securestring]) { throw 'Platform password helper did not return a SecureString.' }
$bootstrapConfig = [ordered]@{
    source = $config.source; tools = $config.tools; hosts = $config.hosts
}
$encodedBootstrap = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($bootstrapConfig | ConvertTo-Json -Depth 30 -Compress)))
if ($encodedBootstrap.Length -gt 7000) { throw 'Bootstrap configuration exceeds the bounded Windows command-line payload; shorten approved immutable asset URLs/paths.' }
$parameters = @{
    location = $config.region
    suffix = $suffix
    tags = $tags
    adminUsername = "lab$suffix"
    adminPassword = $securePassword
    vmSize = $config.vm.size
    image = $config.vm.image
    licenseType = $config.vm.licenseType
    osDiskSizeGB = $config.vm.osDiskSizeGB
    accessMode = $config.vm.accessMode
    sourceAddressPrefix = $participant[0].sourceAddressPrefix
    bootstrapUri = $config.bootstrap.uri
    bootstrapSha256 = $config.bootstrap.sha256
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
Assert-LabResourceGroup -Name $ResourceGroupName -Location $config.region -Tags $tags `
    -ImplicitVmId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$suffix"
# No template or Azure response is streamed to the dashboard.
@{ HackboxCredential = @{ name = 'VM username'; value = "lab$suffix"; note = "VM vm-$suffix in $ResourceGroupName" } }
$plainPassword = New-MhhStablePassword -Purpose 'apbi-vm-admin' -Length 24
@{ HackboxCredential = @{ name = 'VM password'; value = $plainPassword; note = 'Participant only; do not share or put in transcripts.' } }
$plainPassword = $null
$securePassword.Dispose()
@{ HackboxCredential = @{ name = 'Shared capacity resource'; value = $capacity[0].ResourceId; note = 'Challenge 1: use Copilot to create and assign your own Fabric workspace; no workspace is pre-created.' } }
