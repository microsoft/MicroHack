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

$ErrorActionPreference = 'Stop'

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "[$SubscriptionId] Running shared-deploy-lab.ps1 in $scriptPath"

# EXAMPLE: Register Resource Providers here if needed
$requiredProviders = @(
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.SqlVirtualMachine",
    "Microsoft.DevTestLab"
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

try {
    $registrationState = Get-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowBringYourOwnPublicIpAddress
    If ($registrationState.RegistrationState -ne "Registered") {
        Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowBringYourOwnPublicIpAddress
    }
}
catch {
    Write-Host "Could not register AllowBringYourOwnPublicIpAddress." -ForegroundColor Red
}

# EXAMPLE: shared resources, e.g. hub networks, bastion host, etc. can be deployed here...
# no resource group is pre-created for this hook, so pick your own name and never use a participant's resource group
$environmentName = "sqlhack"  # template produces rg-sqlhack-shared
$sharedResourceGroup = "rg-${environmentName}-shared"
$adminUsername = "DemoUser"
$adminPassword = New-MhhStablePassword -Purpose 'vm-admin' -SubscriptionId $SubscriptionId -ResourceGroupName "Default"
$sqlMiAdminUsername = "DemoUser"
$sqlMiAdminPassword = New-MhhStablePassword -Purpose 'sqlmi-admin' -SubscriptionId $SubscriptionId -ResourceGroupName "Default"
$legacySQLName = "legacySQL2016"
$arcSQLName = "arcSQL2022"


# deploy shared resources in the shared resource group (do not forget to assign the correct rbac roles to the allowed Entra users)
# Invoke-MhhDeploymentWithRegionFallback creates/recreates the resource group, re-grants Owner and falls back to the next region
$templatePath = Join-Path $scriptPath "infra"
$template = Join-Path $templatePath "main-shared.bicep"
Write-Host "[$SubscriptionId] Deploying shared resources from template $template to resource group $sharedResourceGroup"

Write-Host $AllowedEntraUserIds

#Check if shared-rg was successfully deployed already
$SkipSharedDeployment = $false
$rg = Get-AzResourceGroup -Name $sharedResourceGroup -ErrorAction SilentlyContinue
if ($rg) {
    if ($null -eq $rg.Tags) {
        $tags = @{}
    }
    else {
        $tags = $rg.Tags
    }
    if ($tags["microhack-shared-deployment"] -eq "Succeeded") {
        $SkipSharedDeployment = $true
    }
}

if ($SkipSharedDeployment) {
    $managedInstance = Get-AzSqlInstance -ResourceGroupName $sharedResourceGroup -ErrorAction SilentlyContinue | Select-Object -First 1
    $managedInstanceName = $managedInstance.ManagedInstanceName
    $managedInstanceFQDN = $managedInstance.FullyQualifiedDomainName

    @{"HackboxCredential" = @{name = 'Legacy SQL Server Name'; value = $legacySQLName; note = 'Name of legacy SQL Server'; group = 'Lab-General'}}
    @{"HackboxCredential" = @{name = 'SQLMI FQDN'; value = $managedInstanceFQDN; note = 'FQDN of SQLMI'; group = 'Lab-General'}}
    @{"HackboxCredential" = @{name = 'Arc SQL Server Name'; value = $arcSQLName; note = 'Name of new SQL Server'; group = 'Lab-General'}}

    @{"HackboxCredential" = @{name = 'VM User Name'; value = $adminUsername; note = 'Username to connect for every VM'; group = 'Lab-Credentials'}}
    @{"HackboxCredential" = @{name = 'VM User Password'; value = $adminPassword; note = 'Password to connect to every VM'; group = 'Lab-Credentials'}}
    @{"HackboxCredential" = @{name = 'SQLMI User Name'; value = $sqlMiAdminUsername; note = 'Username to connect to SQLMI'; group = 'Lab-Credentials'}}
    @{"HackboxCredential" = @{name = 'SQLMI User Password'; value = $sqlMiAdminPassword; note = 'Password to connect to SQLMI'; group = 'Lab-Credentials'}}

    return
}


New-AzResourceGroup -Name $sharedResourceGroup -Location $PreferredLocation[0] -Force -ErrorAction Stop

$tags = @{
    SecurityControl = "Ignore"
}

$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $PreferredLocation `
    -RgOwnerEntraObjectIds   @($AllowedEntraUserIds) `
    -ResourceGroupName       $sharedResourceGroup `
    -CleanupTimeoutSeconds   1800
    -TemplateFile            $template `
    -Tag                     $tags `
    -TemplateParameterObject @{
        environmentName                     = $environmentName  # z.B. "sqlhack"
        location                            = $PreferredLocation[0]
        adminUsername                       = $adminUsername
        adminPassword                       = $adminPassword
        sqlMiAdminUsername                  = $sqlMiAdminUsername
        sqlMiAdminPassword                  = $sqlMiAdminPassword
        legacySQLName                       = $legacySQLName
        arcSQLName                          = $arcSQLName
    }

Write-Host "[$SubscriptionId] Result: $($result)"

# You can send back information to the hackbox console (credentials) - Simply return a hashtable like this:
# Note: everything returned here is shown to EVERY participant in this subscription, so never emit per-participant secrets.
# @{"HackboxCredential" = @{ name = "AdminPassword" ; value = "TopSecret"; note = "Useful info here" }}

$managedInstance = Get-AzSqlInstance -ResourceGroupName $sharedResourceGroup -ErrorAction SilentlyContinue | Select-Object -First 1
$managedInstanceName = $managedInstance.ManagedInstanceName
$managedInstanceFQDN = $managedInstance.FullyQualifiedDomainName

@{"HackboxCredential" = @{name = 'Legacy SQL Server Name'; value = $legacySQLName; note = 'Name of legacy SQL Server'; group = 'Lab-General'}}
@{"HackboxCredential" = @{name = 'SQLMI FQDN'; value = $managedInstanceFQDN; note = 'FQDN of SQLMI'; group = 'Lab-General'}}
@{"HackboxCredential" = @{name = 'Arc SQL Server Name'; value = $arcSQLName; note = 'Name of new SQL Server'; group = 'Lab-General'}}

@{"HackboxCredential" = @{name = 'VM User Name'; value = $adminUsername; note = 'Username to connect for every VM'; group = 'Lab-Credentials'}}
@{"HackboxCredential" = @{name = 'VM User Password'; value = $adminPassword; note = 'Password to connect to every VM'; group = 'Lab-Credentials'}}
@{"HackboxCredential" = @{name = 'SQLMI User Name'; value = $sqlMiAdminUsername; note = 'Username to connect to SQLMI'; group = 'Lab-Credentials'}}
@{"HackboxCredential" = @{name = 'SQLMI User Password'; value = $sqlMiAdminPassword; note = 'Password to connect to SQLMI'; group = 'Lab-Credentials'}}

[string]$managedInstanceResourceId = $managedInstance.Id
#$managedInstancePrincipalId = $managedInstance.Identity.PrincipalId

try {
    Write-Host "Connecting to MGraph..."
    $token = (Get-AzAccessToken -ResourceTypeName MSGraph).Token
    Connect-MgGraph -AccessToken $token -NoWelcome -Erroraction Stop
    Write-Host "Calling Set-MhhManagedIdentityRoleMember for $managedInstanceResourceId ..."
    $return = Set-MhhManagedIdentityRoleMember -ResourceId $managedInstanceResourceId
    Write-Host "Calling Set-MhhManagedIdentityRoleMember returned $return ..."
}
catch {
    Write-Host "Failed to grant 'Directory Readers' to Managed Identity of $managedInstanceFQDN." -ForegroundColor Red
    Write-Host $return
    $ErrorString = $_ | format-list -force | Out-String
    Write-Error "ERR: $ErrorString"
}

Start-Sleep -Seconds 30

try {
    $FirstLabUser = Get-MhhLabUser -UserId @($AllowedEntraUserIds) | Where-Object { $_.ShortName.ToLower() -match "labuser-[0-9]{4}"} | Sort-Object -Property ShortName | Select-Object -First 1
    $SQLMiEntraAdmin = Get-AzADUser -ObjectId $FirstLabUser.Id -ErrorAction Stop
    # Entra Admin auf der MI setzen
    #$return = Set-AzSqlInstanceActiveDirectoryAdministrator `
    #    -ResourceGroupName $sharedResourceGroup `
    #    -InstanceName $managedInstance.ManagedInstanceName `
    #    -DisplayName $SQLMiEntraAdmin.DisplayName `
    #    -ObjectId $SQLMiEntraAdmin.Id -ErrorAction Stop
    
    Write-Host "Configuring $($SQLMiEntraAdmin.UserPrincipalName) as Entra ID Admin for SQLMI ..."
    # Concatenate the query string; "$var?api-version=..." interpolates as a scoped variable.
    $adminPath = $managedInstance.Id + '/administrators/ActiveDirectory?api-version=2023-08-01-preview'
    $payload = @{
        properties = @{
            administratorType = 'ActiveDirectory'
            login             = $SQLMiEntraAdmin.UserPrincipalName
            sid               = $SQLMiEntraAdmin.Id
            tenantId          = (Get-AzContext).Tenant.Id
        }
    } | ConvertTo-Json -Depth 5
    $resp = Invoke-AzRestMethod -Method PUT -Path $adminPath -Payload $payload
    Write-Host "Configuring $($SQLMiEntraAdmin.UserPrincipalName) as Entra ID Admin for SQLMI returned $($resp.StatusCode) ..."
    if ($resp.StatusCode -notin 200, 201, 202) {
        throw "Set MI Entra admin failed (HTTP $($resp.StatusCode)): $($resp.Content)"
    }
}
catch {
    Write-Host "Failed to set Entra ID Admin on $managedInstanceFQDN." -ForegroundColor Red
    $ErrorString = $_ | format-list -force | Out-String
    Write-Error "ERR: $ErrorString"
}

$timeoutSeconds = 120
$pollIntervalSeconds = 10
$found = $false
for ($elapsed = 0; $elapsed -lt $timeoutSeconds; $elapsed += $pollIntervalSeconds)
{
    Write-Host "Checking Entra ID Admin ($elapsed seconds)..."
    try
    {
        $admin = Get-AzSqlInstanceActiveDirectoryAdministrator `
            -ResourceGroupName $sharedResourceGroup `
            -InstanceName $managedInstanceName `
            -ErrorAction Stop
        Write-Host "Expected Admin (ID): $($SQLMiEntraAdmin.Id) - Current Admin (ID): $($admin.ObjectId)"
        if ($admin.ObjectId -eq $SQLMiEntraAdmin.Id)
        {
            Write-Host "Expected Entra ID Admin is configured."

            $found = $true
            break
        }
    }
    catch
    {
        Write-Host "No Entra ID Admin configured yet."
    }
    Start-Sleep -Seconds $pollIntervalSeconds
}
if (-not $found)
{
    throw "Expected Entra ID Admin was not configured within 2 minutes."
}

$rg = Get-AzResourceGroup -Name $sharedResourceGroup -ErrorAction SilentlyContinue
$tags = $rg.Tags
$tags["microhack-shared-deployment"] = "Succeeded"
Set-AzResourceGroup -Name $sharedResourceGroup -Tags $tags | Out-Null
