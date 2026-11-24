param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [string[]]$PreferredLocation = @(),
    [Parameter(Mandatory = $false)]
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$runtime = Get-LabPlatformContext $SubscriptionId $PreferredLocation $AllowedEntraUserIds
$settings = $runtime.Settings
if (-not (Get-Command Get-MhhStableHash -ErrorAction SilentlyContinue)) { throw 'Required platform helper unavailable: Get-MhhStableHash' }
$suffix = Get-MhhStableHash -Value @($SubscriptionId) -Length 12
$resourceGroup = "rg-apbi-shared-$suffix"
$capacityName = "apbi$suffix"
$administrator = Get-LabCapacityAdministrator $AllowedEntraUserIds
$users = @($AllowedEntraUserIds | Sort-Object)
if ($users.Count -gt 1000) { throw 'The subnet address plan supports at most 1000 identities; this is not a measured F16 cohort limit.' }
$fingerprint = Get-LabFingerprint @{ settings = $settings; administrator = $administrator; users = $users }
$existing = @(Invoke-LabAzureOperation { Get-AzResourceGroup -ErrorAction Stop } 'Read shared resource group' |
    Where-Object ResourceGroupName -EQ $resourceGroup)
if ($existing.Count) {
    if ($existing[0].Tags['LabConfig'] -ne $fingerprint) { throw 'Shared configuration or roster changed; inspect existing resources before migration.' }
    $region = $existing[0].Tags['LabRegion']
    if ($region -notin $runtime.Regions) { throw 'Existing shared region is not in the supplied preferred regions.' }
    $image = $settings.Image.Clone()
    $image.version = $existing[0].Tags['LabImageVersion']
} else {
    $selection = Get-LabRegionImage $SubscriptionId $runtime.Regions $settings
    $region = $selection.Region
    $image = $selection.Image
}
$tags = @{
    LabEvent = $settings.EventId; LabOwner = 'shared'; LabComponent = 'shared'
    LabConfig = $fingerprint; LabRegion = $region; LabImageVersion = $image.version
}
Assert-LabResourceGroup -Name $resourceGroup -Location $region -Tags $tags
# The deterministic name is subscription-wide, not participant- or event-derived.
$allCapacities = @(Invoke-LabAzureOperation { Get-AzResource -ResourceType 'Microsoft.Fabric/capacities' -ErrorAction Stop } 'Check subscription capacity collisions')
if (@($allCapacities | Where-Object { $_.Name -eq $capacityName -and $_.ResourceGroupName -ne $resourceGroup }).Count -gt 0) {
    throw 'The lab capacity name already exists outside its owned resource group; refusing adoption.'
}
$deployment = Invoke-LabAzureOperation {
    New-AzResourceGroupDeployment -Name 'apbi-shared' -ResourceGroupName $resourceGroup `
        -TemplateFile (Join-Path $PSScriptRoot 'shared.bicep') -TemplateParameterObject @{
            location = $region; capacityName = $capacityName; suffix = $suffix
            capacityAdministrators = @($administrator); tags = $tags
            participantSubnets = @(
                for ($i = 0; $i -lt $users.Count; $i++) {
                    $block = $i + 1
                    @{
                        name = 'participant-' + (Get-MhhStableHash -Value @($users[$i]) -Length 12)
                        prefix = "10.90.$([int][Math]::Floor($block / 4)).$(($block % 4) * 64)/26"
                    }
                }
            )
            bastionScaleUnits = $settings.BastionScaleUnits
        } -Mode Incremental -ErrorAction Stop -Verbose:$false -Debug:$false
} 'Shared F16 ARM deployment'
if ($deployment.ProvisioningState -ne 'Succeeded') { throw 'Shared F16 ARM deployment did not complete successfully.' }
$active = $false
$deadline = [DateTimeOffset]::UtcNow.AddMinutes(5)
for ($attempt = 0; $attempt -lt 60; $attempt++) {
    $remaining = [int][Math]::Floor(($deadline - [DateTimeOffset]::UtcNow).TotalSeconds)
    if ($remaining -lt 1) { break }
    $detail = Invoke-LabArmRequest -Path "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Fabric/capacities/$($capacityName)?api-version=2023-11-01" -TimeoutSeconds $remaining
    if ($detail.properties.state -eq 'Active') { $active = $true; break }
    if ($detail.properties.state -in 'Paused', 'Suspended', 'Deleted') { throw 'Shared capacity is not active; inspect its state before retrying.' }
    Start-Sleep -Seconds ([Math]::Min(5, $remaining))
}
if (-not $active) { throw 'Shared capacity did not become Active within five minutes; participant fan-out must not start.' }
Write-Warning 'Infrastructure provisioned only. Organizers must verify Fabric assignment permissions, ItemCreation policy coverage, licenses and both host journeys before participant admission.'
@{ HackboxCredential = @{ name = 'Shared capacity'; value = $capacityName; note = "F16 in $resourceGroup. No participant capacity-administrator grants. Create your workspace with Copilot in Challenge 1." } }
@{ HackboxCredential = @{ name = 'Shared Bastion'; value = "bastion-$suffix"; note = 'Browser RDP to private participant VMs. Shared NAT, Bastion and public endpoint charges are additional to F16.' } }
