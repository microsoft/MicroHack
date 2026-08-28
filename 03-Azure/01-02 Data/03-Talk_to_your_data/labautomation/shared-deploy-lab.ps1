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
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$AllowedEntraUserIds = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────
$SharedResourceGroup = 'rg-shared'
$SqlAdminLogin = 'sqlmiadmin'
$FabricApi = 'https://api.fabric.microsoft.com/v1'
# Microsoft.PowerPlatform is required for the Fabric VNet data gateway's subnet delegation.
$RequiredProviders = @('Microsoft.Sql', 'Microsoft.Fabric', 'Microsoft.Storage', 'Microsoft.Web', 'Microsoft.Network', 'Microsoft.PowerPlatform')

# Demo databases restored once for the whole subscription: DB name -> backup file.
$TailspinToysBak = 'tailspintoys_before_launch.bak'
$TailspinToysFeedbackBak = 'tailspintoysfeedback_before_launch.bak'
$DemoDatabases = [ordered]@{
    'TailspinToys_Demo_Final'          = $TailspinToysBak
    'TailspinToys_Demo_Mirroring'      = $TailspinToysBak
    'TailspinToysFeedback_Demo_Final'  = $TailspinToysFeedbackBak
    'TailspinToysFeedback_Demo_Mirrored' = $TailspinToysFeedbackBak
}

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
}
Import-Module SqlServer -ErrorAction Stop

function Update-MhhTokenQuiet {
    # Refresh Azure credentials; Update-MhhToken's status object is shown only with -Verbose.
    Update-MhhToken | Out-String | Write-Verbose
}

function Invoke-MiSql {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [string]$Query,
        [string]$InputFile,
        [int]$QueryTimeout = 0
    )
    # SQL authentication with the MI admin login: the platform cannot set an Entra admin on the MI.
    $cred = [pscredential]::new($SqlAdminLogin, (ConvertTo-SecureString $sqlPassword -AsPlainText -Force))
    $splat = @{
        ServerInstance    = $Server
        Database          = $Database
        Credential        = $cred
        ConnectionTimeout = 30
        QueryTimeout      = $QueryTimeout
        ErrorAction       = 'Stop'
    }
    if ($InputFile) { $splat['InputFile'] = $InputFile } else { $splat['Query'] = $Query }
    Invoke-Sqlcmd @splat
}

function Invoke-FabricApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'DELETE')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $url = "$FabricApi/$($Path.TrimStart('/'))"
    $azArgs = @('rest', '--method', $Method, '--url', $url, '--resource', 'https://api.fabric.microsoft.com')
    if ($Body) {
        $json = ($Body | ConvertTo-Json -Depth 10 -Compress)
        $azArgs += @('--headers', 'Content-Type=application/json', '--body', $json)
    }
    $raw = az @azArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Fabric API $Method $Path failed: $raw"
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

# ─────────────────────────────────────────────
# 0. Location + resource providers
# ─────────────────────────────────────────────
$locations = @($PreferredLocation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($locations.Count -eq 0) { throw "No PreferredLocation supplied." }
$location = $locations[0]
Write-Host "[shared] Using location '$location' (SQL MI + Fabric F32 do not auto-fall-back across regions; re-run with a different preferredLocation order if capacity is unavailable)."

foreach ($rp in $RequiredProviders) {
    Register-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue | Out-Null
}

# ─────────────────────────────────────────────
# 1. Shared resource group + Owner for every attendee in this subscription
# ─────────────────────────────────────────────
if (-not (Get-AzResourceGroup -Name $SharedResourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $SharedResourceGroup -Location $location -Tag @{ SecurityControl = 'Ignore' } | Out-Null
    Write-Host "[shared] Created resource group '$SharedResourceGroup'."
}
$rgId = (Get-AzResourceGroup -Name $SharedResourceGroup).ResourceId
foreach ($uid in ($AllowedEntraUserIds | Where-Object { $_ })) {
    if (-not (Get-AzRoleAssignment -ObjectId $uid -Scope $rgId -RoleDefinitionName 'Owner' -ErrorAction SilentlyContinue)) {
        New-AzRoleAssignment -ObjectId $uid -Scope $rgId -RoleDefinitionName 'Owner' -ErrorAction SilentlyContinue | Out-Null
    }
}

# ─────────────────────────────────────────────
# 2. Resolve the deploying service principal (becomes SQL MI Entra admin)
# ─────────────────────────────────────────────
$account = (Get-AzContext).Account.Id
$spObjectId = $null
if ($account -as [guid]) {
    $spObjectId = (Get-AzADServicePrincipal -ApplicationId $account -ErrorAction SilentlyContinue).Id
    if (-not $spObjectId) {
        $spObjectId = az ad sp show --id $account --query id -o tsv 2>$null
    }
}
if (-not $spObjectId) {
    # Local testing runs as a user, not an SP; fall back to the signed-in user.
    $spObjectId = (Get-AzADUser -SignedIn -ErrorAction SilentlyContinue).Id
}
if (-not $spObjectId) { throw "Could not resolve the deploying principal object id." }

# Entra admin for the SQL MI (enables Entra auth; set declaratively with an explicit sid so ARM does not resolve the principal).
$aadTenantId = (Get-AzContext).Tenant.Id
$aadAdminLogin = if ($account -as [guid]) { (Get-AzADServicePrincipal -Id $spObjectId -ErrorAction SilentlyContinue).DisplayName } else { $account }
if (-not $aadAdminLogin) { $aadAdminLogin = 'MicroHackDeployer' }

# Fabric capacity admin members: users must be UPNs (object IDs are rejected); a service principal uses its object ID.
$fabricMemberList = [System.Collections.Generic.List[string]]::new()
if ($account -as [guid]) {
    $fabricMemberList.Add($spObjectId)   # deploying service principal
}
else {
    $fabricMemberList.Add($account)       # deploying user's UPN
}
foreach ($uid in ($AllowedEntraUserIds | Where-Object { $_ })) {
    $memberUpn = (Get-MhhLabUser -UserId $uid -ErrorAction SilentlyContinue).UserPrincipalName
    if (-not $memberUpn) { $memberUpn = (Get-AzADUser -ObjectId $uid -ErrorAction SilentlyContinue).UserPrincipalName }
    if ($memberUpn) { $fabricMemberList.Add($memberUpn) }
    else { Write-Warning "[shared] Could not resolve a UPN for '$uid'; omitting it from Fabric admin members." }
}
$fabricAdminMembers = @($fabricMemberList | Select-Object -Unique)
$sqlPassword = New-MhhStablePassword -Purpose 'sql-admin' -Length 24

# ─────────────────────────────────────────────
# 3. Deploy the shared ARM stack (async; SQL MI can exceed the 90-min command limit)
# ─────────────────────────────────────────────
# Once the SQL MI exists it has injected network intent policies into its subnet's NSG/route table;
# redeploying those conflicts, so tell the template to reference them as existing on re-runs.
$sqlMiNetworkingExists = -not [string]::IsNullOrWhiteSpace((az sql mi list -g $SharedResourceGroup --query "[0].id" -o tsv 2>$null))
$depName = "shared-$(Get-Date -f yyyyMMddHHmmss)"
Write-Host "[shared] Submitting shared.bicep deployment '$depName' into '$SharedResourceGroup'."
New-AzResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $SharedResourceGroup `
    -TemplateFile (Join-Path $PSScriptRoot 'shared.bicep') `
    -TemplateParameterObject @{
    location              = $location
    sqlAdminLogin         = $SqlAdminLogin
    # Plain string, not SecureString: -AsJob cannot serialize a SecureString across the job boundary. Bicep param stays @secure().
    sqlPassword           = $sqlPassword
    fabricAdminMembers    = $fabricAdminMembers
    sqlMiNetworkingExists = $sqlMiNetworkingExists
    sqlAadAdminLogin      = $aadAdminLogin
    sqlAadAdminSid        = $spObjectId
    sqlAadAdminTenantId   = $aadTenantId
} `
    -AsJob | Out-Null

do {
    Start-Sleep -Seconds 30
    Update-MhhTokenQuiet
    # Guard the property access: under Set-StrictMode the deployment may not be registered yet (returns $null).
    $dep = Get-AzResourceGroupDeployment -ResourceGroupName $SharedResourceGroup -Name $depName -ErrorAction SilentlyContinue
    $state = if ($dep) { $dep.ProvisioningState } else { $null }
    Write-Host "[shared] deployment state: $state"
} while ($state -notin 'Succeeded', 'Failed', 'Canceled')

if ($state -ne 'Succeeded') {
    throw "Shared deployment '$depName' ended in state '$state'. See the deployment operations in '$SharedResourceGroup'."
}

$out = (Get-AzResourceGroupDeployment -ResourceGroupName $SharedResourceGroup -Name $depName).Outputs
$miName = $out.sqlManagedInstanceName.Value
$miFqdn = $out.sqlManagedInstanceFqdn.Value
$capacityName = $out.fabricCapacityName.Value
$vnetName = $out.vnetName.Value
$fabricSubnet = $out.fabricSubnetName.Value
$storageAccount = $out.backupStorageAccountName.Value
$containerName = $out.backupContainerName.Value
$webshopHost = $out.webshopDefaultHostname.Value

# Public endpoint FQDN: insert 'public.' after the instance short name; port 3342.
$publicFqdn = $miFqdn -replace '^([^.]+)\.', '$1.public.'
$server = "$publicFqdn,3342"

# ─────────────────────────────────────────────
# 4. Entra: Directory Readers for the MI identity (needed for external-provider logins)
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
# Grant the SQL MI managed identity Directory Readers via the platform helper (handles the tenant-wide directory-role lock and is idempotent).
$drResult = @(Get-AzSqlInstance -ResourceGroupName $SharedResourceGroup -Name $miName |
        Set-MhhManagedIdentityRoleMember -Role 'Directory Readers')
if ($drResult.status -contains 'Failed') {
    throw "Failed to grant Directory Readers to the SQL MI identity."
}
Write-Host "[shared] SQL MI identity Directory Readers: $($drResult.status -join ', ')."

# ─────────────────────────────────────────────
# 5. Upload the .bak files and restore the demo databases
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
$storageKey = az storage account keys list --resource-group $SharedResourceGroup --account-name $storageAccount --query "[0].value" -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to read storage key for '$storageAccount'." }

foreach ($bak in @($TailspinToysBak, $TailspinToysFeedbackBak)) {
    $localBak = Join-Path $PSScriptRoot "databasebackup/$bak"
    if (-not (Test-Path $localBak)) { throw "Backup file not found: $localBak" }
    Write-Host "[shared] Uploading $bak."
    az storage blob upload --account-name $storageAccount --account-key $storageKey `
        --container-name $containerName --name $bak --file $localBak --overwrite true --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload $bak." }
}

$expiry = (Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mmZ')
$sasToken = az storage container generate-sas --account-name $storageAccount --name $containerName `
    --account-key $storageKey --permissions rl --https-only --expiry $expiry -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to generate container SAS." }

$credentialName = "https://$storageAccount.blob.core.windows.net/$containerName"
Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 -Query @"
IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$credentialName')
    DROP CREDENTIAL [$credentialName];
CREATE CREDENTIAL [$credentialName]
WITH IDENTITY = 'Shared Access Signature', SECRET = '$sasToken';
"@ | Out-Null

foreach ($db in $DemoDatabases.Keys) {
    $exists = (Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 `
            -Query "SELECT COUNT(*) AS C FROM sys.databases WHERE name = N'$db'").C
    if ($exists -gt 0) {
        Write-Host "[shared] Demo database '$db' already exists. Skipping restore."
        continue
    }
    $url = "https://$storageAccount.blob.core.windows.net/$containerName/$($DemoDatabases[$db])"
    Write-Host "[shared] Restoring demo database '$db'."
    Invoke-MiSql -Server $server -Database 'master' -Query "RESTORE DATABASE [$db] FROM URL = N'$url';" | Out-Null
}

# ─────────────────────────────────────────────
# 6. Seed Demo_Final: product, stored procedure, Agent job
# ─────────────────────────────────────────────
$productExists = (Invoke-MiSql -Server $server -Database 'TailspinToys_Demo_Final' -QueryTimeout 60 `
        -Query "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.Product WHERE ProductSKU = '9000-FABRIC-RANGER') THEN 1 ELSE 0 END AS C").C
if ($productExists -ne 1) {
    $productSql = (Get-Content -Raw (Join-Path $PSScriptRoot 'sql/InsertProduct.sql')) -replace '##db-name##', 'TailspinToys_Demo_Final'
    Invoke-MiSql -Server $server -Database 'master' -Query $productSql | Out-Null
    Write-Host "[shared] Inserted Fabric Space Ranger product into Demo_Final."
}

Invoke-MiSql -Server $server -Database 'master' -InputFile (Join-Path $PSScriptRoot 'sql/StoredProcedure.sql') | Out-Null
Write-Host "[shared] Ensured stored procedure usp_PurchaseSpaceRanger."

$jobExists = (Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 `
        -Query "SELECT CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'2 Fabric Space Ranger Workload') THEN 1 ELSE 0 END AS C").C
if ($jobExists -ne 1) {
    Invoke-MiSql -Server $server -Database 'master' -InputFile (Join-Path $PSScriptRoot 'sql/Jobs.sql') | Out-Null
    Write-Host "[shared] Created Agent job '2 Fabric Space Ranger Workload'."
}

# ─────────────────────────────────────────────
# 7. Fabric VNet data gateway + ConnectionCreator for every attendee
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
$capacity = (Invoke-FabricApi -Method GET -Path 'capacities').value | Where-Object { $_.displayName -eq $capacityName } | Select-Object -First 1
if (-not $capacity) { throw "Fabric capacity '$capacityName' not visible via the Fabric API (check tenant setting 'Service principals can use Fabric APIs')." }

$gatewayName = "fabric-gateway-shared"
$gateway = (Invoke-FabricApi -Method GET -Path 'gateways').value | Where-Object { $_.displayName -eq $gatewayName } | Select-Object -First 1
if (-not $gateway) {
    Write-Host "[shared] Creating Fabric VNet data gateway."
    $gateway = Invoke-FabricApi -Method POST -Path 'gateways' -Body @{
        type                         = 'VirtualNetwork'
        displayName                  = $gatewayName
        capacityId                   = $capacity.id
        inactivityMinutesBeforeSleep = 30
        numberOfMemberGateways       = 1
        virtualNetworkAzureResource  = @{
            subscriptionId     = $SubscriptionId
            resourceGroupName  = $SharedResourceGroup
            virtualNetworkName = $vnetName
            subnetName         = $fabricSubnet
        }
    }
}
foreach ($uid in ($AllowedEntraUserIds | Where-Object { $_ })) {
    try {
        Invoke-FabricApi -Method POST -Path "gateways/$($gateway.id)/roleAssignments" -Body @{
            principal = @{ id = $uid; type = 'User' }
            role      = 'ConnectionCreator'
        } | Out-Null
    }
    catch {
        Write-Warning "[shared] Gateway role assignment for $uid skipped: $($_.Exception.Message)"
    }
}

# ─────────────────────────────────────────────
# 8. Shared credentials for every attendee's dashboard
# ─────────────────────────────────────────────
@{ HackboxCredential = @{ name = 'SQL MI Public Endpoint'; value = $server; note = 'SSMS: connect with the SQL admin login below' } }
@{ HackboxCredential = @{ name = 'SQL Admin Login'; value = $SqlAdminLogin; note = 'Shared SQL Managed Instance admin' } }
@{ HackboxCredential = @{ name = 'SQL Admin Password'; value = $sqlPassword; note = 'Shared SQL Managed Instance admin password' } }
@{ HackboxCredential = @{ name = 'Webshop URL'; value = "https://$webshopHost"; note = 'Shared Tailspin Toys webshop' } }
@{ HackboxCredential = @{ name = 'Fabric Capacity'; value = $capacityName; note = 'Shared Fabric F32 capacity' } }
@{ HackboxCredential = @{ name = 'Shared Resource Group'; value = $SharedResourceGroup; note = 'Shared by all labs in your subscription' } }

Write-Host "[shared] Shared deployment complete."
