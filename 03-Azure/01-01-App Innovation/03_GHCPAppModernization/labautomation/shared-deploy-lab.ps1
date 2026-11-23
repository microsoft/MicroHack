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

$requiredProviders = @(
    "Microsoft.App",                  # Azure Container Apps
    "Microsoft.ContainerRegistry",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.OperationalInsights",  # Log Analytics - required by Container Apps environments
    "Microsoft.ManagedIdentity"       # identities used by ACA/ACR deployments
)
foreach($provider in $requiredProviders) {
    $unregistered = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue |
        Where-Object { $_.RegistrationState -ne "Registered" }
    if($unregistered) {
        Write-Host "[$SubscriptionId] Registering resource provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    }
    else {
        Write-Host "[$SubscriptionId] Resource provider $provider is already registered."
    }
}

# Register-AzResourceProvider is asynchronous - wait (bounded) until every provider reports Registered,
# so the first lab deployment does not race the registration (MissingSubscriptionRegistration).
$deadline = (Get-Date).AddMinutes(10)
foreach($provider in $requiredProviders) {
    while((Get-Date) -lt $deadline -and (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue |
            Where-Object { $_.RegistrationState -ne "Registered" })) {
        Write-Host "[$SubscriptionId] Waiting for $provider registration to complete..."
        Start-Sleep -Seconds 15
    }
}


<#
# EXAMPLE: shared resources, e.g. hub networks, bastion host, etc. can be deployed here...
# no resource group is pre-created for this hook, so pick your own name and never use a participant's resource group
$sharedResourceGroup = "shareddeployment"
if(-not (Get-AzResourceGroup -Name $sharedResourceGroup -ErrorAction SilentlyContinue)) {
    Write-Host "[$SubscriptionId] Creating shared resource group: $sharedResourceGroup"
    New-AzResourceGroup -Name $sharedResourceGroup -Location $PreferredLocation[0] -ErrorAction Stop
}
else {
    Write-Host "[$SubscriptionId] Shared resource group $sharedResourceGroup already exists."
}

# deploy shared resources in the shared resource group (do not forget to assign the correct rbac roles to the allowed Entra users)
# Invoke-MhhDeploymentWithRegionFallback creates/recreates the resource group, re-grants Owner and falls back to the next region

# $template = Join-Path $scriptPath "template-shared.bicep"
# $template = Join-Path $scriptPath "template-shared.json"
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
