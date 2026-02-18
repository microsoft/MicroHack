<#
.SYNOPSIS
Deploys the lab resources scoped to a subscription or resource group.
.DESCRIPTION
Provides a controlled deployment flow for lab environments, optionally limited to a resource group and specific Entra user IDs.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription or resourcegroup.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
In case of resourcegroup deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure region for resource deployment. "" indicates no preference.
.PARAMETER AllowedEntraUserIds
Optional list of Entra user object IDs permitted to access the lab resources.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string]$PreferredLocation = "",

    [string[]]$AllowedEntraUserIds = @()
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

Import-Module Az.RecoveryServices

# Validate parameters
if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

function Register-Providers {
    $errors = 0
    $initiatedRegistrations = 0

    # Required resource providers
    $requiredProviders = @(
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
        "Microsoft.RecoveryServices"
        "Microsoft.DataProtection"
        "Microsoft.Automation"
        "Microsoft.OperationalInsights"
        "Microsoft.KeyVault"
        "Microsoft.SqlVirtualMachine"
        "Microsoft.Resources"
    )

    foreach ($provider in $requiredProviders) {
        try {
            $providerInfo = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop

            if ($providerInfo.RegistrationState -eq "Registered") {
                Write-Host "$provider is registered"
            }
            else {
                Write-Host "$provider not registered (attempting registration...)"
                try {
                    Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
                    Write-Host "$provider registration initiated"
                    $initiatedRegistrations++
                }
                catch {
                    Write-Host "Failed to register $provider"
                    $errors++
                }
            }
        }
        catch {
            Write-Host "Could not check $provider"
        }
    }

    # wait for completion if any registrations were initiated
    if($initiatedRegistrations -gt 0) {
        Write-Host "Waiting 180 seconds for resource provider registrations to complete..."
        Start-Sleep -Seconds 180
    }

    # Summary
    Write-Host ""
    if ($errors -eq 0) {
        Write-Host "All prerequisites validated successfully"
        return $true
    }
    else {
        Write-Host "Prerequisites check failed with $errors error(s)"
        return $false
    }
}
# register required resource providers
Register-Providers



if($ResourceGroupName -match '-(\d+)') {
    $parPrefix = "h" + $Matches[1]
    if($parPrefix.Length -gt 4) {
        $parPrefix = $parPrefix.Substring(0,4)
    }
}
else {
    # generate random prefix
    $parPrefix = "h"
    $parPrefix += $parPrefix += -join ((48..57 + 97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
}

$password = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 12 | ForEach-Object {[char]$_})
$password = $password.Insert((Get-Random -Minimum 2 -Maximum 10), (Get-Random -InputObject @('?', '!','@','.',':')))
$password = $password.Insert((Get-Random -Minimum 2 -Maximum 10), (Get-Random -InputObject @('?', '!','@','.',':')))


$template = Join-Path $scriptPath "deploy.json"
$mainParameters = Join-Path $scriptPath "main.parameters.json"
$result = New-AzSubscriptionDeployment `
    -Location "norwayeast" `
    -sourceLocation "norwayeast" `
    -targetLocation "swedencentral" `
    -TemplateFile $template `
    -parDeploymentPrefix $parPrefix `
    -TemplateParameterFile $mainParameters `
    -vmAdminPassword (ConvertTo-SecureString -String $password -AsPlainText -Force) `
    -WarningAction Ignore

try {
    @{"HackboxCredential" = @{ name = "Subscription ID" ; value = $SubscriptionId; note = "Subscription ID used for deployment" }}
    @{"HackboxCredential" = @{ name = "Deployment Prefix" ; value = $parPrefix; note = "Prefix used for deployment" }}
    @{"HackboxCredential" = @{ name = "AdminPassword" ; value = $password; note = "Admin Password (VMs, ...)" }}
    @{"HackboxCredential" = @{ name = "Source Resource Group" ; value = $result.Outputs.sourceResourceGroupName.Value; note = "Primary Source Resource Group Name" }}
    @{"HackboxCredential" = @{ name = "Target Resource Group" ; value = $result.Outputs.targetResourceGroupName.Value; note = "Failover Target Resource Group Name" }}
}
catch {
}


if($DeploymentType -eq 'resourcegroup') {
    foreach($rg in (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "$parPrefix*" })) {
        if($AllowedEntraUserIds.Count -gt 0) {
            foreach($userId in $AllowedEntraUserIds) {
                # give owner permissions to the user ID on the resource group
                if(-not (Get-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Owner" -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($rg.ResourceGroupName)" -ErrorAction SilentlyContinue)) {
                    Write-Host "Assigning Owner role to user ID $userId on resource group $($rg.ResourceGroupName)"
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Owner" -Scope "/subscriptions/$($SubscriptionId)/resourceGroups/$($rg.ResourceGroupName)" -ErrorAction Stop | Out-Null
                }
            }
        }
        # Disable soft delete on Recovery Services Vaults - this is required to allow deletion of the vault when the resource group is deleted
        Write-Host "Disabling soft delete on Recovery Services Vaults in resource group $($rg.ResourceGroupName)"
        foreach($vault in (Get-AzRecoveryServicesVault -ResourceGroupName $rg.ResourceGroupName)) {
            Set-AzRecoveryServicesVaultProperty -VaultId $vault.Id -SoftDeleteFeatureState "Disable" | Out-Null
        }
    }
}
else {
    foreach($rg in (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "$parPrefix*" })) {
        # Disable soft delete on Recovery Services Vaults - this is required to allow deletion of the vault when the resource group is deleted
        Write-Host "Disabling soft delete on Recovery Services Vaults in resource group $($rg.ResourceGroupName)"
        foreach($vault in (Get-AzRecoveryServicesVault -ResourceGroupName $rg.ResourceGroupName)) {
            Set-AzRecoveryServicesVaultProperty -VaultId $vault.Id -SoftDeleteFeatureState "Disable" | Out-Null
        }
    }
}
