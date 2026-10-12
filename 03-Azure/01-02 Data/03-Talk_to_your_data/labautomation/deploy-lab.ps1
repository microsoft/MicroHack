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
Specifies the preferred Azure regions (ordered by preference) for resource deployment. An empty array indicates no preference.
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

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Invoke-Sqlcmd emits progress records that the runner's child-job receiver reports as errors.
$ProgressPreference = 'SilentlyContinue'
$script:LabCurrentStep = 'initialization'

$SharedResourceGroup = 'rg-shared'
$SqlAdminLogin = 'sqlmiadmin'
$DemoSqlLogin = 'demouser'
$DemoSqlPassword = 'Demo@pass1234567'
$FabricApi = 'https://api.fabric.microsoft.com/v1'
$TailspinToysBak = 'tailspintoys_before_launch.bak'
$TailspinToysFeedbackBak = 'tailspintoysfeedback_before_launch.bak'
# Shared MI admin password: derive with the shared resource group scope in both hooks.
$sqlPassword = New-MhhStablePassword -Purpose 'sql-admin' -Length 24 -ResourceGroupName $SharedResourceGroup

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

function Write-LabTrace {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )
    Write-Host "[lab][trace] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Start-LabStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )
    $script:LabCurrentStep = $Name
    Write-LabTrace "STEP: $Name"
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
        [int]$QueryTimeout = 0
    )
    # The per-user hook is not the configured Entra admin, so use the shared MI's SQL admin credential.
    $cred = [pscredential]::new($SqlAdminLogin, (ConvertTo-SecureString $sqlPassword -AsPlainText -Force))
    Write-LabTrace "SQL $Database on $Server using inline query. Timeout=$QueryTimeout."
    Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Credential $cred `
        -Query $Query -ConnectionTimeout 30 -QueryTimeout $QueryTimeout -ErrorAction Stop
}

function New-LabRoleAssignmentIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$ObjectId,
        [Parameter(Mandatory = $true)][string]$PrincipalType,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$Scope
    )
    $existing = az role assignment list --assignee $ObjectId --role $Role --scope $Scope --query '[0].id' -o tsv 2>$null
    if (-not [string]::IsNullOrWhiteSpace($existing)) { return $false }

    az role assignment create --assignee-object-id $ObjectId --assignee-principal-type $PrincipalType `
        --role $Role --scope $Scope 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to grant '$Role' on '$Scope' to '$ObjectId'." }
    return $true
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

function Set-LabRestoreCredential {
    # The credential is an instance-level object on the SHARED SQL MI, so every attendee's
    # deployment targets the same name. DROP fails with "cannot drop ... because it is used
    # by an active restore" while another attendee is restoring, so refresh via ALTER instead.
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$CredentialName,
        [Parameter(Mandatory = $true)][string]$SasToken
    )
    $name = $CredentialName.Replace(']', ']]')
    $secret = $SasToken.Replace("'", "''")
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            Invoke-MiSql -Server $Server -Database 'master' -QueryTimeout 60 -Query @"
IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$CredentialName')
    ALTER CREDENTIAL [$name] WITH IDENTITY = 'Shared Access Signature', SECRET = '$secret';
ELSE
    CREATE CREDENTIAL [$name] WITH IDENTITY = 'Shared Access Signature', SECRET = '$secret';
"@ | Out-Null
            return
        }
        catch {
            # Another attendee's run may have created the credential between the check and the CREATE.
            if ($attempt -eq 5) { throw }
            Write-LabTrace "Restore credential update attempt $attempt failed ($($_.Exception.Message)). Retrying."
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
}

function Invoke-FabricApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'DELETE')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $url = "$FabricApi/$($Path.TrimStart('/'))"
    Write-LabTrace "Fabric API $Method $Path"
    $azArgs = @('rest', '--method', $Method, '--url', $url, '--resource', 'https://api.fabric.microsoft.com')
    if ($Body) {
        $json = ($Body | ConvertTo-Json -Depth 10 -Compress)
        Write-LabTrace "Fabric API $Method $Path includes body properties: $(($Body.Keys | Sort-Object) -join ', ')"
        $azArgs += @('--headers', 'Content-Type=application/json', '--body', $json)
    }
    $raw = az @azArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fabric API $Method $Path failed: $raw" }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    Write-LabTrace "Fabric API $Method $Path succeeded."
    return ($raw | ConvertFrom-Json)
}

# ─────────────────────────────────────────────
# 0. Resolve the attendee + shared SQL MI
# ─────────────────────────────────────────────
Start-LabStep "Validate deployment inputs"
Write-LabTrace "Starting attendee deployment. SubscriptionId=$SubscriptionId; ResourceGroupName=$ResourceGroupName; PreferredLocations=$($PreferredLocation -join ', '); AllowedEntraUserIds=$($AllowedEntraUserIds.Count)."
if (-not $AllowedEntraUserIds -or $AllowedEntraUserIds.Count -eq 0) { throw "No AllowedEntraUserIds supplied." }
Start-LabStep "Resolve attendee"
$attendeeId = $AllowedEntraUserIds[0]
Write-LabTrace "Resolving lab user '$attendeeId'."
$user = Get-MhhLabUser -UserId $attendeeId
$rawShortName = [string]$user.ShortName
$short = ($rawShortName -replace '[^a-zA-Z0-9]', '').ToLower()
if ([string]::IsNullOrWhiteSpace($short)) { $short = 'u' + (Get-MhhStableHash -Value $attendeeId -Length 12) }
$upn = $user.UserPrincipalName

$labUserNumber = Get-LabUserNumber -ShortName $rawShortName -UserPrincipalName $upn
if (-not $labUserNumber) {
    $localTestUserIndex = if ($env:TTYD_LOCAL_TEST_USER_INDEX) { [int]$env:TTYD_LOCAL_TEST_USER_INDEX } else { 1 }
    if ($localTestUserIndex -lt 1) { throw "TTYD_LOCAL_TEST_USER_INDEX must be greater than or equal to 1." }
    $labUserSuffix = 'x{0:D3}' -f $localTestUserIndex
    Write-Warning "[lab] Could not derive a labuser number from ShortName '$rawShortName' or UPN '$upn'; using local-test fallback User$labUserSuffix."
}
else {
    $labUserSuffix = '{0:D4}' -f [int]$labUserNumber
}
$labUserPostfix = "User$labUserSuffix"
$userContainer = "container$labUserSuffix"

$sqlDb = "TailspinToys_$labUserPostfix"
$feedbackDb = "TailspinToysFeedback_$labUserPostfix"
Write-LabTrace "Resolved attendee '$upn'; salesDatabase=$sqlDb; feedbackDatabase=$feedbackDb; userDataContainer=$userContainer."

Start-LabStep "Resolve shared SQL Managed Instance"
$mi = @(az sql mi list -g $SharedResourceGroup -o json | ConvertFrom-Json)
if (-not $mi -or $mi.Count -eq 0) { throw "No shared SQL Managed Instance found in '$SharedResourceGroup'. Did the shared hook run?" }
$miFqdn = $mi[0].fullyQualifiedDomainName
$publicFqdn = $miFqdn -replace '^([^.]+)\.', '$1.public.'
$server = "$publicFqdn,3342"
Write-LabTrace "Shared SQL MI resolved: name=$($mi[0].name); server=$server."

Start-LabStep "Ensure shared demo SQL login"
Ensure-DemoSqlLogin -Server $server
Write-Host "[lab] Ensured SQL login '$DemoSqlLogin' for Fabric mirroring."

# ─────────────────────────────────────────────
# 1. Upload the attendee CSV into the shared user-data storage account
# ─────────────────────────────────────────────
Start-LabStep "Resolve deploying principal"
$azContext = Get-AzContext
$deployingAccount = $azContext.Account.Id
$deployingPrincipalId = $null
$deployingPrincipalType = 'User'
if ($deployingAccount -as [guid]) {
    $deployingPrincipalType = 'ServicePrincipal'
    $deployingPrincipalId = (Get-AzADServicePrincipal -ApplicationId $deployingAccount -ErrorAction SilentlyContinue).Id
    if (-not $deployingPrincipalId) { $deployingPrincipalId = az ad sp show --id $deployingAccount --query id -o tsv 2>$null }
}
else {
    $deployingPrincipalId = (Get-AzADUser -SignedIn -ErrorAction SilentlyContinue).Id
}
if (-not $deployingPrincipalId) { throw "Could not resolve the deploying principal object id." }

Start-LabStep "Resolve shared user-data storage"
$userStorage = az storage account list -g $SharedResourceGroup --query "[?starts_with(name, 'employeedata')].name | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($userStorage)) {
    Write-Warning "[lab] No 'employeedata' storage account found; falling back to legacy 'stuserdata' account for this existing test deployment."
    $userStorage = az storage account list -g $SharedResourceGroup --query "[?starts_with(name, 'stuserdata')].name | [0]" -o tsv
}
if ([string]::IsNullOrWhiteSpace($userStorage)) { throw "No shared user-data storage account found in '$SharedResourceGroup'. Did the shared hook run?" }
Write-LabTrace "Shared user-data storage resolved: storageAccount=$userStorage; container=$userContainer."

Start-LabStep "Grant blob data access on shared user-data storage"
$userStorageId = az storage account show --resource-group $SharedResourceGroup --name $userStorage --query id -o tsv
$createdUserStorageRole = New-LabRoleAssignmentIfMissing -ObjectId $deployingPrincipalId -PrincipalType $deployingPrincipalType `
    -Role 'Storage Blob Data Contributor' -Scope $userStorageId
if ($createdUserStorageRole) {
    Write-Host "[lab] Granted Storage Blob Data Contributor on '$userStorage' to the deploying principal."
    Write-Host "[lab] Waiting 30 seconds for shared user-data storage RBAC propagation."
    Start-Sleep -Seconds 30   # RBAC assignments are eventually consistent.
    Write-LabTrace "Shared user-data storage RBAC propagation wait complete."
}
else {
    Write-LabTrace "Role assignment for '$userStorage' skipped (already exists)."
}
# Fabric's ADLS Gen2 connection flow needs to enumerate the storage account before the attendee selects their container.
New-LabRoleAssignmentIfMissing -ObjectId $attendeeId -PrincipalType User `
    -Role 'Storage Blob Data Reader' -Scope $userStorageId | Out-Null

# Upload the employee CSV into the attendee container.
Start-LabStep "Upload attendee employee CSV"
$csvPath = Join-Path $PSScriptRoot 'csvdata/employees_user_data.csv'
if (-not (Test-Path $csvPath)) { throw "Employee CSV not found: $csvPath" }
az storage blob upload --account-name $userStorage --auth-mode login `
    --container-name $userContainer --name (Split-Path $csvPath -Leaf) --file $csvPath `
    --overwrite true --only-show-errors --no-progress | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to upload employee CSV." }

# ─────────────────────────────────────────────
# 2. Restore the two attendee databases in the shared SQL MI
# ─────────────────────────────────────────────
Start-LabStep "Prepare attendee database restores"
Update-MhhTokenQuiet
$storageAccount = az storage account list -g $SharedResourceGroup --query "[?starts_with(name, 'stsqlhack')].name | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($storageAccount)) { throw "No shared backup storage account found in '$SharedResourceGroup'. Did the shared hook run?" }
$containerName = 'build'

# The shared backup storage account has shared-key auth disabled; grant this run's principal
# Entra-based blob access too (it may not be the same principal that ran the shared hook).
$backupStorageId = az storage account show --resource-group $SharedResourceGroup --name $storageAccount --query id -o tsv
$createdBackupStorageRole = New-LabRoleAssignmentIfMissing -ObjectId $deployingPrincipalId -PrincipalType $deployingPrincipalType `
    -Role 'Storage Blob Data Contributor' -Scope $backupStorageId
if ($createdBackupStorageRole) {
    Write-Host "[lab] Granted Storage Blob Data Contributor on '$storageAccount' to the deploying principal."
    Write-Host "[lab] Waiting 30 seconds for backup storage RBAC propagation."
    Start-Sleep -Seconds 30   # RBAC assignments are eventually consistent.
    Write-LabTrace "Backup storage RBAC propagation wait complete."
}
else {
    Write-LabTrace "Role assignment for '$storageAccount' skipped (already exists)."
}

$expiry = (Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mmZ')
# SQL MI RESTORE FROM URL requires an account-key-backed service SAS.
$storageAccountKey = az storage account keys list --resource-group $SharedResourceGroup --account-name $storageAccount --query '[0].value' -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageAccountKey)) { throw "Failed to read a storage account key for '$storageAccount'." }
$sasToken = az storage container generate-sas --account-name $storageAccount --name $containerName `
    --account-key $storageAccountKey --permissions rl --https-only --expiry $expiry -o tsv
if ($LASTEXITCODE -ne 0) { throw "Failed to generate container SAS." }

$credentialName = "https://$storageAccount.blob.core.windows.net/$containerName"
Start-LabStep "Create SQL restore credential"
Set-LabRestoreCredential -Server $server -CredentialName $credentialName -SasToken $sasToken

$restores = @(
    @{ Db = $sqlDb; Bak = $TailspinToysBak },
    @{ Db = $feedbackDb; Bak = $TailspinToysFeedbackBak }
)
foreach ($r in $restores) {
    Start-LabStep "Restore or verify attendee database $($r.Db)"
    $exists = (Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 `
            -Query "SELECT COUNT(*) AS C FROM sys.databases WHERE name = N'$($r.Db)'").C
    if ($exists -gt 0) {
        Write-Host "[lab] Database '$($r.Db)' already exists. Skipping restore."
        continue
    }
    $url = "https://$storageAccount.blob.core.windows.net/$containerName/$($r.Bak)"
    Write-Host "[lab] Restoring '$($r.Db)'."
    Invoke-MiSql -Server $server -Database 'master' -Query "RESTORE DATABASE [$($r.Db)] FROM URL = N'$url';" | Out-Null
}

# ─────────────────────────────────────────────
# 3. Attendee login/user (db_owner) + product in each database
# ─────────────────────────────────────────────
Start-LabStep "Create attendee SQL login"
Update-MhhTokenQuiet
Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$upn')
    CREATE LOGIN [$upn] FROM EXTERNAL PROVIDER;
"@ | Out-Null

$productSqlTemplate = Get-Content -Raw (Join-Path $PSScriptRoot 'sql/InsertProduct.sql')
foreach ($db in @($sqlDb, $feedbackDb)) {
    Start-LabStep "Grant attendee access to $db"
    Invoke-MiSql -Server $server -Database $db -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$upn')
    CREATE USER [$upn] FROM LOGIN [$upn];
ALTER ROLE [db_owner] ADD MEMBER [$upn];
"@ | Out-Null

    Start-LabStep "Grant demo SQL login access to $db"
    Grant-DemoSqlLoginDatabaseAccess -Server $server -Database $db
}

# Ensure the Fabric Space Ranger product exists in the sales database (needed by the
# shared proc / Agent job, which read Product from each per-attendee database).
Start-LabStep "Seed attendee sales database product"
$productExists = (Invoke-MiSql -Server $server -Database $sqlDb -QueryTimeout 60 `
        -Query "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.Product WHERE ProductSKU = '9000-FABRIC-RANGER') THEN 1 ELSE 0 END AS C").C
if ($productExists -ne 1) {
    $productSql = $productSqlTemplate -replace '##db-name##', $sqlDb
    Invoke-MiSql -Server $server -Database 'master' -Query $productSql | Out-Null
    Write-Host "[lab] Inserted Fabric Space Ranger product into '$sqlDb'."
}

# ─────────────────────────────────────────────
# 4. Fabric workspace on the shared capacity + attendee as Member
# ─────────────────────────────────────────────
Start-LabStep "Resolve Fabric capacity"
Update-MhhTokenQuiet
$capacityName = az resource list -g $SharedResourceGroup --resource-type 'Microsoft.Fabric/capacities' --query "[0].name" -o tsv
$capacity = $null
for ($elapsed = 0; $elapsed -lt 120; $elapsed += 15) {
    $capacity = (Invoke-FabricApi -Method GET -Path 'capacities').value | Where-Object { $_.displayName -eq $capacityName } | Select-Object -First 1
    if ($capacity -and $capacity.state -eq 'Active') { break }
    Write-LabTrace "Waiting for Fabric capacity '$capacityName' to become Active (state=$($capacity.state))..."
    Start-Sleep -Seconds 15
}
if (-not $capacity) { throw "Fabric capacity '$capacityName' not visible via the Fabric API." }
if ($capacity.state -ne 'Active') { throw "Fabric capacity '$capacityName' did not reach Active state (last state: $($capacity.state))." }
Write-LabTrace "Fabric capacity resolved: name=$capacityName; id=$($capacity.id); state=$($capacity.state)."

Start-LabStep "Create or resolve attendee Fabric workspace"
$workspaceName = "Workspace_$short"
$workspace = (Invoke-FabricApi -Method GET -Path 'workspaces').value | Where-Object { $_.displayName -eq $workspaceName } | Select-Object -First 1
if (-not $workspace) {
    Write-Host "[lab] Creating Fabric workspace '$workspaceName'."
    try {
        $workspace = Invoke-FabricApi -Method POST -Path 'workspaces' -Body @{
            displayName = $workspaceName
            capacityId  = $capacity.id
        }
    }
    catch {
        if ($_.Exception.Message -match '(?i)Unauthorized|not authenticated') {
            $caller = (Get-AzContext).Account.Id
            throw "Fabric denied workspace creation for '$caller'. In the Fabric Admin portal, enable the Developer setting 'Service principals can create workspaces, connections, and deployment pipelines' for a security group containing this service principal."
        }
        throw
    }
}
Write-LabTrace "Fabric workspace resolved: name=$workspaceName; id=$($workspace.id)."
Start-LabStep "Grant attendee Fabric workspace Member role"
try {
    Invoke-FabricApi -Method POST -Path "workspaces/$($workspace.id)/roleAssignments" -Body @{
        principal = @{ id = $attendeeId; type = 'User' }
        role      = 'Member'
    } | Out-Null
}
catch {
    Write-Warning "[lab] Workspace role assignment skipped: $($_.Exception.Message)"
}

# ─────────────────────────────────────────────
# 5. Attendee credentials
# ─────────────────────────────────────────────
Start-LabStep "Emit attendee credentials"
@{ HackboxCredential = @{ name = 'Sales Database'; value = $sqlDb; note = 'Your TailspinToys database on the shared SQL MI' } }
@{ HackboxCredential = @{ name = 'Feedback Database'; value = $feedbackDb; note = 'Your feedback database' } }
@{ HackboxCredential = @{ name = 'Fabric Workspace'; value = $workspaceName; note = 'Your Fabric workspace' } }
@{ HackboxCredential = @{ name = 'Employee CSV Storage'; value = $userStorage; note = "Container '$userContainer'" } }

Write-Host "[lab] Deployment complete for $upn."
