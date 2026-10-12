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
# Invoke-Sqlcmd/Az cmdlets emit Write-Progress records that the runner's child-job receiver can't
# deserialize cleanly (surfaces as "NotSpecified: (:String) [], RemoteException"), which flips the
# runner's own success verdict even though the script itself completes without error.
$ProgressPreference = 'SilentlyContinue'
$script:SharedCurrentStep = 'initialization'
# Commented out to test whether trap's rethrow is what makes the runner see this as failed.
# trap {
#     Write-Warning "[shared] FAILED during step '$script:SharedCurrentStep'."
#     Write-Warning "[shared] Exception: $($_.Exception.Message)"
#     if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
#         Write-Warning "[shared] Location: $($_.InvocationInfo.PositionMessage)"
#     }
#     throw
# }

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────
$SharedResourceGroup = 'rg-shared'
$SqlAdminLogin = 'sqlmiadmin'
$DemoSqlLogin = 'demouser'
$DemoSqlPassword = 'Demo@pass1234567'
$FabricApi = 'https://api.fabric.microsoft.com/v1'
# Fabric requires a licensed user in the tenant before it recognises it; the deploying principal cannot
# grant that license (no Graph write permission), so it comes from the 'M365-E5-Users' group request in
# lab-defaults.json instead. We only poll for it here.
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

function Write-SharedTrace {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )
    Write-Host "[shared][trace] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Start-SharedStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )
    $script:SharedCurrentStep = $Name
    Write-SharedTrace "STEP: $Name"
}

function Get-LabUserNumber {
    param(
        [string]$ShortName,
        [string]$UserPrincipalName
    )
    if ($ShortName -match '(?i)(?:labuser|user)[-_]?0*(\d+)$') { return [int]$Matches[1] }
    if ($UserPrincipalName -match '(?i)(?:labuser|user)[-_]?0*(\d+)') { return [int]$Matches[1] }
    return $null
}

function Invoke-MiSql {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [string]$Query,
        [string]$InputFile,
        [int]$QueryTimeout = 0
    )
    # Use SQL authentication while provisioning; the Entra admin is configured later in this hook.
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
    $source = if ($InputFile) { "file '$InputFile'" } else { 'inline query' }
    Write-SharedTrace "SQL $Database on $Server using $source. Timeout=$QueryTimeout."
    Invoke-Sqlcmd @splat
}

function Ensure-DemoSqlLogin {
    param(
        [Parameter(Mandatory = $true)][string]$Server
    )
    $login = $DemoSqlLogin.Replace(']', ']]')
    $password = $DemoSqlPassword.Replace("'", "''")
    Invoke-MiSql -Server $Server -Database 'master' -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'$DemoSqlLogin')
    CREATE LOGIN [$login] WITH PASSWORD = N'$password', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [$login] WITH PASSWORD = N'$password', CHECK_POLICY = OFF;
"@ | Out-Null
}

function Grant-DemoSqlLoginDatabaseAccess {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database
    )
    $login = $DemoSqlLogin.Replace(']', ']]')
    Invoke-MiSql -Server $Server -Database $Database -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$DemoSqlLogin')
    CREATE USER [$login] FROM LOGIN [$login];
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals roles ON roles.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals members ON members.principal_id = drm.member_principal_id
    WHERE roles.name = N'db_owner' AND members.name = N'$DemoSqlLogin'
)
    ALTER ROLE [db_owner] ADD MEMBER [$login];
"@ | Out-Null
}

function Invoke-FabricApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $url = "$FabricApi/$($Path.TrimStart('/'))"
    Write-SharedTrace "Fabric API $Method $Path"
    $azArgs = @('rest', '--method', $Method, '--url', $url, '--resource', 'https://api.fabric.microsoft.com')
    if ($Body) {
        $json = ($Body | ConvertTo-Json -Depth 10 -Compress)
        Write-SharedTrace "Fabric API $Method $Path includes body properties: $(($Body.Keys | Sort-Object) -join ', ')"
        $azArgs += @('--headers', 'Content-Type=application/json', '--body', $json)
    }
    $raw = az @azArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[shared] Fabric API $Method $Path failed with exit code $LASTEXITCODE. Raw response: $raw"
        throw "Fabric API $Method $Path failed: $raw"
    }
    Write-SharedTrace "Fabric API $Method $Path succeeded."
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

# ─────────────────────────────────────────────
# 0. Location + resource providers
# ─────────────────────────────────────────────
Start-SharedStep "Validate deployment inputs"
$locations = @($PreferredLocation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($locations.Count -eq 0) { throw "No PreferredLocation supplied." }
$location = $locations[0]
Write-SharedTrace "Starting shared deployment. SubscriptionId=$SubscriptionId; PreferredLocations=$($locations -join ', '); AllowedEntraUserIds=$($AllowedEntraUserIds.Count)."
Write-Host "[shared] Using location '$location' (SQL MI + Fabric F32 do not auto-fall-back across regions; re-run with a different preferredLocation order if capacity is unavailable)."

foreach ($rp in $RequiredProviders) {
    Write-SharedTrace "Registering resource provider '$rp'."
    Register-AzResourceProvider -ProviderNamespace $rp -ErrorAction SilentlyContinue | Out-Null
}

# ─────────────────────────────────────────────
# 1. Shared resource group (created once; attendees get no RBAC here)
# ─────────────────────────────────────────────
# Attendees never touch rg-shared directly: the SQL MI is reached via a SQL login (deploy-lab.ps1)
# and Fabric via a per-attendee workspace Member role, not Azure RBAC on this resource group. Granting
# RBAC here would let any attendee modify/delete resources shared by every lab in the subscription.
if (-not (Get-AzResourceGroup -Name $SharedResourceGroup -ErrorAction SilentlyContinue)) {
    Start-SharedStep "Create shared resource group"
    New-AzResourceGroup -Name $SharedResourceGroup -Location $location -Tag @{ SecurityControl = 'Ignore' } | Out-Null
    Write-Host "[shared] Created resource group '$SharedResourceGroup'."
}
$rgId = (Get-AzResourceGroup -Name $SharedResourceGroup).ResourceId
Write-SharedTrace "Shared resource group id: $rgId"

# ─────────────────────────────────────────────
# 2. Resolve principals and bootstrap the Fabric tenant
# ─────────────────────────────────────────────
Start-SharedStep "Resolve deploying principal"
$azContext = Get-AzContext
$account = $azContext.Account.Id
Write-SharedTrace "Azure context account='$account'; tenant='$($azContext.Tenant.Id)'; subscription='$($azContext.Subscription.Id)'."
$spObjectId = $null
if ($account -as [guid]) {
    Write-SharedTrace "Context account looks like an application id; resolving service principal object id."
    $spObjectId = (Get-AzADServicePrincipal -ApplicationId $account -ErrorAction SilentlyContinue).Id
    if (-not $spObjectId) {
        Write-SharedTrace "Az PowerShell did not resolve the service principal; trying Azure CLI."
        $spObjectId = az ad sp show --id $account --query id -o tsv 2>$null
    }
}
if (-not $spObjectId) {
    # Local testing runs as a user, not an SP; fall back to the signed-in user.
    Write-SharedTrace "Resolving signed-in user object id for local/user context."
    $spObjectId = (Get-AzADUser -SignedIn -ErrorAction SilentlyContinue).Id
}
if (-not $spObjectId) { throw "Could not resolve the deploying principal object id." }
Write-SharedTrace "Deploying principal object id resolved: $spObjectId"

Start-SharedStep "Resolve default lab group"
$labGroup = Get-MhhDefaultLabGroup
if (-not $labGroup -or -not $labGroup.ObjectId) { throw "Get-MhhDefaultLabGroup did not return a group with an ObjectId." }
Write-SharedTrace "Default lab group resolved: $($labGroup.DisplayName) ($($labGroup.ObjectId))."

# Resolve every attendee once; reused below for the SQL MI Entra admin, the Fabric capacity admin
# list (per-user UPNs) and the shared user-data containers. Fabric gateway admin access is still
# granted to the whole group (gateway role assignments accept a group principal).
Start-SharedStep "Resolve lab users"
$labUsers = [System.Collections.Generic.List[object]]::new()
foreach ($uid in ($AllowedEntraUserIds | Where-Object { $_ })) {
    Write-SharedTrace "Resolving lab user '$uid'."
    $mhhUser = Get-MhhLabUser -UserId $uid -ErrorAction SilentlyContinue
    $memberUpn = $mhhUser.UserPrincipalName
    if (-not $memberUpn) { $memberUpn = (Get-AzADUser -ObjectId $uid -ErrorAction SilentlyContinue).UserPrincipalName }
    if (-not $memberUpn) {
        Write-Warning "[shared] Could not resolve a UPN for '$uid'; skipping it."
        continue
    }
    $labUsers.Add([pscustomobject]@{
            Id                = $uid
            UserPrincipalName = $memberUpn
            ShortName         = $mhhUser.ShortName
            LabUserNumber     = Get-LabUserNumber -ShortName $mhhUser.ShortName -UserPrincipalName $memberUpn
            LabUserSuffix     = $null
        })
}
if ($labUsers.Count -eq 0) { throw "Could not resolve any lab user from AllowedEntraUserIds." }
Write-SharedTrace "Resolved $($labUsers.Count) lab users: $((@($labUsers | ForEach-Object { $_.UserPrincipalName }) -join ', '))"

foreach ($labUser in @($labUsers | Where-Object { $_.LabUserNumber })) {
    $labUser.LabUserSuffix = '{0:D4}' -f [int]$labUser.LabUserNumber
}
$nextFallbackUserIndex = 1
foreach ($labUser in @($labUsers | Where-Object { -not $_.LabUserNumber })) {
    $labUser.LabUserSuffix = 'x{0:D3}' -f $nextFallbackUserIndex
    Write-Warning "[shared] Could not derive a labuser number for '$($labUser.UserPrincipalName)' ($($labUser.ShortName)); using local-test fallback User$($labUser.LabUserSuffix)."
    $nextFallbackUserIndex++
}
$userDataContainerNames = @($labUsers |
        Sort-Object LabUserSuffix |
        ForEach-Object { "container$($_.LabUserSuffix)" } |
        Select-Object -Unique)
Write-SharedTrace "Preparing shared user-data storage containers: $($userDataContainerNames -join ', ')."

$firstLabUser = $labUsers | Where-Object { $_.ShortName -match '(?i)labuser-[0-9]{4}' } | Sort-Object ShortName | Select-Object -First 1
if (-not $firstLabUser) { $firstLabUser = $labUsers | Sort-Object ShortName | Select-Object -First 1 }
Write-SharedTrace "SQL MI Entra admin candidate: $($firstLabUser.UserPrincipalName) ($($firstLabUser.Id))."

# The 'M365-E5-Users' group request in lab-defaults.json licenses every attendee for Fabric; we cannot
# assign it ourselves here. Poll (read-only) until the tenant is recognised rather than letting the
# capacity deployment fail outright while that group-based provisioning is still catching up.
$fabricTenantReady = $false
Start-SharedStep "Wait for Fabric tenant provisioning"
for ($elapsed = 0; $elapsed -lt 600; $elapsed += 30) {
    try {
        Invoke-FabricApi -Method GET -Path 'capacities' | Out-Null
        $fabricTenantReady = $true
        Write-Host "[shared] Fabric recognises this tenant."
        break
    }
    catch {
        Write-Host "[shared] Waiting for Fabric tenant provisioning ($elapsed s)..."
        Start-Sleep -Seconds 30
    }
}
if (-not $fabricTenantReady) {
    Write-Warning "[shared] Fabric did not confirm the tenant within 10 minutes. Continuing; the capacity deployment will report the real cause."
}

# Fabric capacity administrators must be existing users or service principals; groups are rejected
# ("All provided principals must be existing, user or service principals"). So enumerate every attendee's
# UPN individually instead of adding the shared lab group's ObjectId.
$fabricMemberList = [System.Collections.Generic.List[string]]::new()
if ($account -as [guid]) {
    $fabricMemberList.Add($spObjectId)   # deploying service principal
}
else {
    $fabricMemberList.Add($account)       # deploying user's UPN
}
foreach ($labUser in $labUsers) { $fabricMemberList.Add($labUser.UserPrincipalName) }
$fabricAdminMembers = @($fabricMemberList | Select-Object -Unique)
$sqlPassword = New-MhhStablePassword -Purpose 'sql-admin' -Length 24 -ResourceGroupName $SharedResourceGroup
Write-SharedTrace "Prepared $($fabricAdminMembers.Count) Fabric capacity admin members. SQL admin password generated but not printed."

# ─────────────────────────────────────────────
# 3. Deploy the shared ARM stack (async; SQL MI can exceed the 90-min command limit)
# ─────────────────────────────────────────────
# Once the SQL MI exists it has injected network intent policies into its subnet's NSG/route table;
# redeploying those conflicts, so tell the template to reference them as existing on re-runs.
Start-SharedStep "Submit shared ARM deployment"
$sqlMiNetworkingExists = -not [string]::IsNullOrWhiteSpace((az sql mi list -g $SharedResourceGroup --query "[0].id" -o tsv 2>$null))
$depName = "shared-$(Get-Date -f yyyyMMddHHmmss)"
Write-Host "[shared] Submitting shared.bicep deployment '$depName' into '$SharedResourceGroup'."
Write-SharedTrace "sqlMiNetworkingExists=$sqlMiNetworkingExists; template='$(Join-Path $PSScriptRoot 'shared.bicep')'."
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
    userDataContainerNames = $userDataContainerNames
    sqlMiNetworkingExists = $sqlMiNetworkingExists
} `
    -AsJob | Out-Null

Start-SharedStep "Poll shared ARM deployment"
do {
    Start-Sleep -Seconds 30
    Update-MhhTokenQuiet
    # Guard the property access: under Set-StrictMode the deployment may not be registered yet (returns $null).
    $dep = Get-AzResourceGroupDeployment -ResourceGroupName $SharedResourceGroup -Name $depName -ErrorAction SilentlyContinue
    $state = if ($dep) { $dep.ProvisioningState } else { $null }
    Write-Host "[shared] deployment state: $state"
} while ($state -notin 'Succeeded', 'Failed', 'Canceled')

if ($state -ne 'Succeeded') {
    $failedOps = @(Get-AzResourceGroupDeploymentOperation -ResourceGroupName $SharedResourceGroup -DeploymentName $depName -ErrorAction SilentlyContinue |
            Where-Object { $_.Properties.ProvisioningState -eq 'Failed' })
    foreach ($op in $failedOps) {
        Write-Warning "[shared] Failed deployment operation '$($op.OperationId)' target='$($op.Properties.TargetResource.ResourceName)' type='$($op.Properties.TargetResource.ResourceType)': $($op.Properties.StatusMessage | ConvertTo-Json -Depth 8 -Compress)"
    }
    throw "Shared deployment '$depName' ended in state '$state'. See the deployment operations in '$SharedResourceGroup'."
}

Start-SharedStep "Read shared ARM outputs"
$out = (Get-AzResourceGroupDeployment -ResourceGroupName $SharedResourceGroup -Name $depName).Outputs
$miName = $out.sqlManagedInstanceName.Value
$miFqdn = $out.sqlManagedInstanceFqdn.Value
$capacityName = $out.fabricCapacityName.Value
$vnetName = $out.vnetName.Value
$fabricSubnet = $out.fabricSubnetName.Value
$storageAccount = $out.backupStorageAccountName.Value
$containerName = $out.backupContainerName.Value
$userDataStorage = $out.userDataStorageAccountName.Value
$userDataStorageDfsEndpoint = $out.userDataStorageDfsEndpoint.Value
$webshopHost = $out.webshopDefaultHostname.Value

# Public endpoint FQDN: insert 'public.' after the instance short name; port 3342.
$publicFqdn = $miFqdn -replace '^([^.]+)\.', '$1.public.'
$server = "$publicFqdn,3342"
Write-SharedTrace "Shared outputs: miName=$miName; capacityName=$capacityName; vnetName=$vnetName; fabricSubnet=$fabricSubnet; backupStorage=$storageAccount; backupContainer=$containerName; userDataStorage=$userDataStorage; webshopHost=$webshopHost."

Start-SharedStep "Ensure shared demo SQL login"
Ensure-DemoSqlLogin -Server $server
Write-Host "[shared] Ensured SQL login '$DemoSqlLogin' for Fabric mirroring."

# ─────────────────────────────────────────────
# 4. Entra: Directory Readers for the MI identity (needed for external-provider logins)
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
# Grant the SQL MI managed identity Directory Readers via the platform helper (handles the tenant-wide directory-role lock and is idempotent).
Start-SharedStep "Grant SQL MI Directory Readers"
$drResult = @(Get-AzSqlInstance -ResourceGroupName $SharedResourceGroup -Name $miName |
        Set-MhhManagedIdentityRoleMember -Role 'Directory Readers')
if ($drResult.status -contains 'Failed') {
    throw "Failed to grant Directory Readers to the SQL MI identity."
}
Write-Host "[shared] SQL MI identity Directory Readers: $($drResult.status -join ', ')."

# ─────────────────────────────────────────────
# 4b. Entra admin on the SQL MI = first lab user
# ─────────────────────────────────────────────
# Deliberately not done in Bicep: ARM cannot resolve the principal in the lab tenant.
# Set-AzSqlInstanceActiveDirectoryAdministrator is unreliable here too, so PUT the
# administrator sub-resource directly. Directory Readers must be granted first.
# Entra directory-role assignments are eventually consistent; a short wait risks
# ServicePrincipalLookupInAadFailedIdentityForbidden when the PUT below looks up the AAD admin.
Start-SharedStep "Wait for Directory Readers propagation"
Write-Host "[shared] Waiting 5 minutes for the SQL MI Directory Readers assignment to propagate before setting the Entra admin."
Start-Sleep -Seconds 300
Write-SharedTrace "Directory Readers propagation wait complete."
Update-MhhTokenQuiet

Start-SharedStep "Configure SQL MI Entra admin"
$sqlEntraAdmin = Get-AzADUser -ObjectId $firstLabUser.Id -ErrorAction Stop
$mi = Get-AzSqlInstance -ResourceGroupName $SharedResourceGroup -Name $miName
Write-Host "[shared] Configuring $($sqlEntraAdmin.UserPrincipalName) as SQL MI Entra admin."

# Concatenated, not interpolated: "$($mi.Id)/...?api-version=..." would swallow the '?' into the variable scope.
$adminPath = $mi.Id + '/administrators/ActiveDirectory?api-version=2023-08-01-preview'
$adminPayload = @{
    properties = @{
        administratorType = 'ActiveDirectory'
        login             = $sqlEntraAdmin.UserPrincipalName
        sid               = $sqlEntraAdmin.Id
        tenantId          = (Get-AzContext).Tenant.Id
    }
} | ConvertTo-Json -Depth 5
Write-SharedTrace "PUT SQL MI Entra admin path: $adminPath"
$adminResp = Invoke-AzRestMethod -Method PUT -Path $adminPath -Payload $adminPayload
if ($adminResp.StatusCode -notin 200, 201, 202) {
    throw "Setting the SQL MI Entra admin failed (HTTP $($adminResp.StatusCode)): $($adminResp.Content)"
}

# The PUT is accepted asynchronously; confirm the admin actually landed before continuing.
$adminConfirmed = $false
Start-SharedStep "Confirm SQL MI Entra admin"
for ($elapsed = 0; $elapsed -lt 120; $elapsed += 10) {
    Start-Sleep -Seconds 10
    $current = Get-AzSqlInstanceActiveDirectoryAdministrator -ResourceGroupName $SharedResourceGroup -InstanceName $miName -ErrorAction SilentlyContinue
    if ($current -and $current.ObjectId -eq $sqlEntraAdmin.Id) { $adminConfirmed = $true; break }
    Write-Host "[shared] Waiting for the Entra admin to appear ($elapsed s)..."
}
if (-not $adminConfirmed) { throw "The SQL MI Entra admin was not configured within 2 minutes." }
Write-Host "[shared] SQL MI Entra admin is $($sqlEntraAdmin.UserPrincipalName)."

# ─────────────────────────────────────────────
# 5. Upload the .bak files and restore the demo databases
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
# The backup storage account has shared-key auth disabled; grant the deploying principal Entra-based
# blob access instead (covers both blob upload and generating a user-delegation SAS below).
Start-SharedStep "Grant deploying principal blob data access on backup storage"
$backupStorageId = az storage account show --resource-group $SharedResourceGroup --name $storageAccount --query id -o tsv
$backupPrincipalType = if ($account -as [guid]) { 'ServicePrincipal' } else { 'User' }
az role assignment create --assignee-object-id $spObjectId --assignee-principal-type $backupPrincipalType `
    --role 'Storage Blob Data Contributor' --scope $backupStorageId 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[shared] Granted Storage Blob Data Contributor on '$storageAccount' to the deploying principal."
    Write-Host "[shared] Waiting 30 seconds for backup storage RBAC propagation."
    Start-Sleep -Seconds 30   # RBAC assignments are eventually consistent.
    Write-SharedTrace "Backup storage RBAC propagation wait complete."
}
else {
    Write-SharedTrace "Role assignment for '$storageAccount' skipped (already exists)."
}

foreach ($bak in @($TailspinToysBak, $TailspinToysFeedbackBak)) {
    Start-SharedStep "Upload backup $bak"
    $localBak = Join-Path $PSScriptRoot "databasebackup/$bak"
    if (-not (Test-Path $localBak)) { throw "Backup file not found: $localBak" }
    Write-Host "[shared] Uploading $bak."
    # --no-progress: the CLI's own upload progress bar goes to stderr regardless of $ProgressPreference,
    # which the runner's child-job receiver mis-relays as a "RemoteException" (false-positive failure).
    az storage blob upload --account-name $storageAccount --auth-mode login `
        --container-name $containerName --name $bak --file $localBak --overwrite true --only-show-errors --no-progress 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload $bak." }
}

$expiry = (Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mmZ')
Start-SharedStep "Generate backup container SAS"
# SQL MI RESTORE FROM URL requires an account-key-backed service SAS.
$storageAccountKey = az storage account keys list --resource-group $SharedResourceGroup --account-name $storageAccount --query '[0].value' -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageAccountKey)) { throw "Failed to read a storage account key for '$storageAccount'." }
$sasToken = az storage container generate-sas --account-name $storageAccount --name $containerName `
    --account-key $storageAccountKey --permissions rl --https-only --expiry $expiry -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to generate container SAS." }

$credentialName = "https://$storageAccount.blob.core.windows.net/$containerName"
Start-SharedStep "Create SQL restore credential"
# ALTER, not DROP+CREATE: DROP fails while any restore on this instance is still using the credential.
Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 -Query @"
IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$credentialName')
    ALTER CREDENTIAL [$credentialName] WITH IDENTITY = 'Shared Access Signature', SECRET = '$sasToken';
ELSE
    CREATE CREDENTIAL [$credentialName] WITH IDENTITY = 'Shared Access Signature', SECRET = '$sasToken';
"@ | Out-Null

foreach ($db in $DemoDatabases.Keys) {
    Start-SharedStep "Restore or verify demo database $db"
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

foreach ($db in $DemoDatabases.Keys) {
    Start-SharedStep "Grant demo SQL login access to $db"
    Grant-DemoSqlLoginDatabaseAccess -Server $server -Database $db
}

# ─────────────────────────────────────────────
# 6. Seed Demo_Final: product, stored procedure, Agent job
# ─────────────────────────────────────────────
Start-SharedStep "Seed Demo_Final product"
$productExists = (Invoke-MiSql -Server $server -Database 'TailspinToys_Demo_Final' -QueryTimeout 60 `
        -Query "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.Product WHERE ProductSKU = '9000-FABRIC-RANGER') THEN 1 ELSE 0 END AS C").C
if ($productExists -ne 1) {
    $productSql = (Get-Content -Raw (Join-Path $PSScriptRoot 'sql/InsertProduct.sql')) -replace '##db-name##', 'TailspinToys_Demo_Final'
    Invoke-MiSql -Server $server -Database 'master' -Query $productSql | Out-Null
    Write-Host "[shared] Inserted Fabric Space Ranger product into Demo_Final."
}

Start-SharedStep "Ensure shared stored procedure"
Invoke-MiSql -Server $server -Database 'master' -InputFile (Join-Path $PSScriptRoot 'sql/StoredProcedure.sql') | Out-Null
Write-Host "[shared] Ensured stored procedure usp_PurchaseSpaceRanger."

Start-SharedStep "Ensure shared SQL Agent job"
$jobExists = (Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 `
        -Query "SELECT CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'2 Fabric Space Ranger Workload') THEN 1 ELSE 0 END AS C").C
if ($jobExists -ne 1) {
    Invoke-MiSql -Server $server -Database 'master' -InputFile (Join-Path $PSScriptRoot 'sql/Jobs.sql') | Out-Null
    Write-Host "[shared] Created Agent job '2 Fabric Space Ranger Workload'."
}

# ─────────────────────────────────────────────
# 7. Fabric VNet data gateway + Admin role for every attendee
# ─────────────────────────────────────────────
Update-MhhTokenQuiet
# ARM reporting the capacity deployment as Succeeded doesn't mean the Fabric control plane has finished
# attaching it yet; creating the gateway against a not-yet-Active capacity leaves it permanently unable
# to refresh, even though both later report healthy. Wait for the Fabric-side state explicitly.
Start-SharedStep "Wait for Fabric capacity to become Active"
$capacity = $null
for ($elapsed = 0; $elapsed -lt 300; $elapsed += 15) {
    $capacity = (Invoke-FabricApi -Method GET -Path 'capacities').value | Where-Object { $_.displayName -eq $capacityName } | Select-Object -First 1
    if ($capacity -and $capacity.state -eq 'Active') { break }
    Write-Host "[shared] Waiting for Fabric capacity '$capacityName' to become Active (state=$($capacity.state); ${elapsed}s elapsed)..."
    Start-Sleep -Seconds 15
}
if (-not $capacity) { throw "Fabric capacity '$capacityName' not visible via the Fabric API (check tenant setting 'Service principals can use Fabric APIs')." }
if ($capacity.state -ne 'Active') { throw "Fabric capacity '$capacityName' did not reach Active state within 5 minutes (last state: $($capacity.state))." }
Write-SharedTrace "Fabric capacity id: $($capacity.id); state confirmed Active."

$gatewayName = "fabric-gateway-shared"
Start-SharedStep "Resolve Fabric VNet gateway"
$gateway = (Invoke-FabricApi -Method GET -Path 'gateways').value | Where-Object { $_.displayName -eq $gatewayName } | Select-Object -First 1
if (-not $gateway) {
    Start-SharedStep "Create Fabric VNet gateway"
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
Write-SharedTrace "Fabric gateway id: $($gateway.id)"
# The lab group gets Admin (not just ConnectionCreator) so every attendee can restart the gateway
# themselves when it goes to sleep or fails during the hack.
$gatewayAssignments = @()
try { $gatewayAssignments = @((Invoke-FabricApi -Method GET -Path "gateways/$($gateway.id)/roleAssignments").value) }
catch { Write-Warning "[shared] Could not list existing gateway role assignments: $($_.Exception.Message)" }

try {
    $existing = $gatewayAssignments | Where-Object { $_.principal.id -eq $labGroup.ObjectId } | Select-Object -First 1
    if ($existing -and $existing.role -eq 'Admin') {
        Write-SharedTrace "Gateway Admin already assigned to lab group $($labGroup.DisplayName)."
    }
    else {
        Start-SharedStep "Grant Fabric gateway Admin to lab group $($labGroup.DisplayName)"
        if ($existing) {
            # Re-run over a lab that was provisioned with ConnectionCreator: upgrade in place, since a
            # second POST for the same principal is rejected.
            Invoke-FabricApi -Method PATCH -Path "gateways/$($gateway.id)/roleAssignments/$($existing.id)" -Body @{
                role = 'Admin'
            } | Out-Null
        }
        else {
            Invoke-FabricApi -Method POST -Path "gateways/$($gateway.id)/roleAssignments" -Body @{
                principal = @{ id = $labGroup.ObjectId; type = 'Group' }
                role      = 'Admin'
            } | Out-Null
        }
    }
}
catch {
    Write-Warning "[shared] Gateway role assignment for lab group $($labGroup.DisplayName) skipped: $($_.Exception.Message)"
}

# ─────────────────────────────────────────────
# 8. Shared credentials for every attendee's dashboard
# ─────────────────────────────────────────────
@{ HackboxCredential = @{ name = 'SQL MI Endpoint'; value = $miFqdn; note = 'Fabric mirroring Server field: Fabric reaches this over the VNet gateway, so use the internal FQDN, not the public one' } }
@{ HackboxCredential = @{ name = 'SQL Login'; value = $DemoSqlLogin; note = 'Shared SQL Managed Instance demo login' } }
@{ HackboxCredential = @{ name = 'SQL Password'; value = $DemoSqlPassword; note = 'Shared SQL Managed Instance demo login password' } }
@{ HackboxCredential = @{ name = 'User Data Storage DFS Endpoint'; value = $userDataStorageDfsEndpoint; note = 'ADLS Gen2 endpoint for the shared employee CSV storage account' } }
@{ HackboxCredential = @{ name = 'Webshop URL'; value = "https://$webshopHost"; note = 'Shared Tailspin Toys webshop' } }
@{ HackboxCredential = @{ name = 'Fabric Capacity'; value = $capacityName; note = 'Shared Fabric F32 capacity' } }
@{ HackboxCredential = @{ name = 'Shared Resource Group'; value = $SharedResourceGroup; note = 'Shared by all labs in your subscription' } }

Write-Host "[shared] Shared deployment complete."
# Guard against a stale non-zero $LASTEXITCODE from an earlier, already-handled native command call.
exit 0
