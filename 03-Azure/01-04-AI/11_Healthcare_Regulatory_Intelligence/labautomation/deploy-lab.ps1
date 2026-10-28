param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$context = Get-AzContext
if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
    throw 'The platform Azure context must match SubscriptionId.'
}
if ($AllowedEntraUserIds.Count -eq 0) {
    throw 'At least one participant Entra object ID is required.'
}
foreach ($userId in $AllowedEntraUserIds) {
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($userId, [ref]$parsedId)) {
        throw "Invalid participant Entra object ID: $userId"
    }
}
if ($PreferredLocation.Count -gt 1) {
    throw 'Choose one approved Azure region. This lab does not silently fall back across regions.'
}
$location = if ($PreferredLocation.Count -eq 1) { $PreferredLocation[0].Trim() } else { 'uksouth' }
if ([string]::IsNullOrWhiteSpace($location)) {
    throw 'PreferredLocation must not be blank.'
}
$identityParts = @($SubscriptionId) + @($AllowedEntraUserIds | Sort-Object -Unique)
if ($DeploymentType -eq 'subscription') {
    $groupSuffix = Get-MhhStableHash $identityParts -Length 24
    $ResourceGroupName = "regintel-$groupSuffix"
    $existingGroup = Get-AzResourceGroup | Where-Object ResourceGroupName -EQ $ResourceGroupName
    if (-not $existingGroup) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $location | Out-Null
    }
} elseif ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    throw 'ResourceGroupName is required for resource-group deployment modes.'
}
$group = Get-AzResourceGroup -Name $ResourceGroupName
if ($group.Location -ne $location) {
    throw "Existing resource group is in '$($group.Location)', not approved region '$location'. No resources were moved or deleted."
}
$suffix = Get-MhhStableHash (@($SubscriptionId, $ResourceGroupName) + $identityParts) -Length 12
$template = Join-Path $scriptPath '..\infra\main.bicep'
$result = New-AzResourceGroupDeployment `
    -Name "regintel-$suffix" `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $template `
    -TemplateParameterObject @{
        resourceSuffix = $suffix
        participantObjectIds = @($AllowedEntraUserIds | Sort-Object -Unique)
    }
if ($result.ProvisioningState -ne 'Succeeded') {
    throw "Regulatory intelligence foundation deployment did not succeed: $($result.ProvisioningState)"
}
@{ HackboxCredential = @{ name = 'ResourceGroupName'; value = $ResourceGroupName; note = 'Your lab resource group' } }
@{ HackboxCredential = @{ name = 'EffectiveLocation'; value = $location; note = 'Azure region of your lab resources' } }
# ARM returns output names in camelCase and Outputs is case-sensitive; a PowerShell hashtable is not.
$outputs = @{}
foreach ($key in $result.Outputs.Keys) {
    $outputs[$key] = [string]$result.Outputs[$key].Value
}
foreach ($name in @('FoundryProjectEndpoint', 'FoundryAccountName', 'ModelDeploymentName', 'EmbeddingDeploymentName', 'StorageAccountName', 'SearchServiceName', 'SearchEndpoint', 'ApplicationInsightsName')) {
    if ([string]::IsNullOrWhiteSpace($outputs[$name])) {
        throw "Required template output missing: $name"
    }
    @{ HackboxCredential = @{ name = $name; value = $outputs[$name]; note = 'Lab resource name or endpoint; not a secret' } }
}
