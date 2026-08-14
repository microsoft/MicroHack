<#
.SYNOPSIS
Hook that runs once per subscription before any deploy-lab.ps1 run starts.
.DESCRIPTION
Hook that runs before the per-user deploy-lab.ps1 runs are started. It can be used to deploy shared resources on a subscription level
(e.g. a hub VNet) or to prepare the subscription once instead of once per lab (e.g. registering resource providers).
If it fails for any subscription, no deploy-lab.ps1 runs at all. Emitted HackboxCredential entries are stored for every lab in this subscription.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment.
.PARAMETER AllowedEntraUserIds
Entra user object IDs of every participant holding a lab in this subscription.
#>
param(  
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition


<#
# EXAMPLE: Register Resource Providers here if needed
$requiredProviders = @(
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.Storage"
)
foreach($provider in $requiredProviders) {
    $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue | Select-Object -First 1).RegistrationState
    if($state -ne "Registered") {
        Write-Host "[$SubscriptionId] Registering resource provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
    }
    else {
        Write-Host "[$SubscriptionId] Resource provider $provider is already registered."
    }
}
#>


<#
# EXAMPLE: shared resources, e.g. hub networks, bastion host, etc. can be deployed here...
# no resource group is pre-created for this hook, so pick your own name and never use a participant's resource group
$sharedResourceGroup = "shareddeployment"

# deploy shared resources in the shared resource group (do not forget to assign the correct rbac roles to the allowed Entra users)
# Invoke-MhhDeploymentWithRegionFallback creates/recreates the resource group, re-grants Owner and falls back to the next region

# $template = Join-Path $scriptPath "template-shared.bicep"
$template = Join-Path $scriptPath "template-shared.json"
$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $PreferredLocation `
    -ResourceGroupName       $sharedResourceGroup `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            $template `
    -TemplateParameterObject @{
        userIds = $AllowedEntraUserIds
    }
#>

# You can send back information to the hackbox console (credentials) - Simply return a hashtable like this:
# Note: everything returned here is shown to EVERY participant in this subscription, so never emit per-participant secrets.
# @{"HackboxCredential" = @{ name = "AdminPassword" ; value = "TopSecret"; note = "Useful info here" }}
