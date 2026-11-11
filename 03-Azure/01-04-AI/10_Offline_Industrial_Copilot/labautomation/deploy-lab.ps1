<#
.SYNOPSIS
Deploys the per-participant resources for the Offline Industrial Copilot MicroHack.
.DESCRIPTION
Deploys an Azure Machine Learning workspace (challenge 5: train in the cloud) and an optional Windows 11 VM
that participants can use instead of their own laptop. Foundry Local itself is installed by the participant in challenge 1.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription or resourcegroup.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
In case of resourcegroup deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment. An empty array indicates no preference.
.PARAMETER AllowedEntraUserIds
Entra user object IDs of the participant who owns this lab.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Set to $false if every participant brings a laptop that can run Foundry Local.
$deployVm = $true

if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral"
}

if($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStablehash $AllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"
    Write-Host "Deploying lab resources at the subscription level in subscription $SubscriptionId..."
    if(-not (Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue)) {
        Write-Host "Creating resource group '$effectiveResourceGroup' in location '$effectiveLocation'..."
        New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Verbose
    } else {
        Write-Host "Resource group '$effectiveResourceGroup' already exists."
    }
} else {
    $effectiveResourceGroup = $ResourceGroupName
}

if($AllowedEntraUserIds.Count -eq 0) {
    throw "At least one AllowedEntraUserIds value is required."
}

$resourceSuffix = (Get-MhhStablehash $AllowedEntraUserIds -Length 12).ToLower()

# Same password on every run for this lab, so the one on the dashboard keeps working after a re-run or a region fallback.
$vmPassword = New-MhhStablePassword -Purpose 'vm-admin'

@{"HackboxCredential" = @{ name = "ResourceGroupName"; value = $effectiveResourceGroup; note = "The resource group of your lab" }}
@{"HackboxCredential" = @{ name = "MachineLearningWorkspace"; value = "mlw-oic-$resourceSuffix"; note = "Azure Machine Learning workspace for challenge 5" }}

$template = Join-Path $scriptPath "main.bicep"
$templateParameters = @{
    resourceSuffix  = $resourceSuffix
    deployVm        = $deployVm
    vmAdminPassword = $vmPassword
}

$deployment = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations $PreferredLocation `
    -ResourceGroupName $effectiveResourceGroup `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -Tag @{ CostControl = "Ignore"; SecurityControl = "Ignore" } `
    -TemplateFile $template `
    -TemplateParameterObject $templateParameters

@{"HackboxCredential" = @{ name = "Region"; value = $deployment.LocationUsed; note = "The Azure region the lab deployment succeeded in" }}

if($deployVm) {
    $outputs = $deployment.Outputs
    @{"HackboxCredential" = @{ name = "VmAddress"; value = $outputs["vmPublicIp"]; note = "Public IP of your Windows 11 VM (connect with Remote Desktop)" }}
    @{"HackboxCredential" = @{ name = "VmUser"; value = $outputs["vmAdminUser"]; note = "VM user name" }}
    @{"HackboxCredential" = @{ name = "VmPassword"; value = $vmPassword; note = "VM password" }}
}
