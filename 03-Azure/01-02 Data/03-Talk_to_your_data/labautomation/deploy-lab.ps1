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

$SharedResourceGroup = 'rg-shared'
$FabricApi = 'https://api.fabric.microsoft.com/v1'
$TailspinToysBak = 'tailspintoys_before_launch.bak'
$TailspinToysFeedbackBak = 'tailspintoysfeedback_before_launch.bak'

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
}
Import-Module SqlServer -ErrorAction Stop

function Get-DbAccessToken {
    $t = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net/').Token
    if ($t -is [System.Security.SecureString]) { return (ConvertFrom-SecureString $t -AsPlainText) }
    return $t
}

function Invoke-MiSql {
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [string]$Query,
        [int]$QueryTimeout = 0
    )
    Invoke-Sqlcmd -ServerInstance $Server -Database $Database -AccessToken (Get-DbAccessToken) `
        -Query $Query -ConnectionTimeout 30 -QueryTimeout $QueryTimeout -ErrorAction Stop
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
    if ($LASTEXITCODE -ne 0) { throw "Fabric API $Method $Path failed: $raw" }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

# ─────────────────────────────────────────────
# 0. Resolve the attendee + shared SQL MI
# ─────────────────────────────────────────────
if (-not $AllowedEntraUserIds -or $AllowedEntraUserIds.Count -eq 0) { throw "No AllowedEntraUserIds supplied." }
$attendeeId = $AllowedEntraUserIds[0]
$user = Get-MhhLabUser -UserId $attendeeId
$short = ($user.ShortName -replace '[^a-zA-Z0-9]', '').ToLower()
if ([string]::IsNullOrWhiteSpace($short)) { $short = 'u' + (Get-MhhStableHash -Value $attendeeId -Length 12) }
$upn = $user.UserPrincipalName

$sqlDb = "TailspinToys_$short"
$feedbackDb = "TailspinToysFeedback_$short"

$mi = @(az sql mi list -g $SharedResourceGroup -o json | ConvertFrom-Json)
if (-not $mi -or $mi.Count -eq 0) { throw "No shared SQL Managed Instance found in '$SharedResourceGroup'. Did the shared hook run?" }
$miFqdn = $mi[0].fullyQualifiedDomainName
$publicFqdn = $miFqdn -replace '^([^.]+)\.', '$1.public.'
$server = "$publicFqdn,3342"

# ─────────────────────────────────────────────
# 1. Per-attendee ARM resources (CSV storage) into the attendee's RG
# ─────────────────────────────────────────────
Update-MhhToken
$rgResult = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations    $PreferredLocation `
    -ResourceGroupName     $ResourceGroupName `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -TemplateFile          (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{ attendeeObjectId = $attendeeId } `
    -DeploymentNamePrefix  'lab'

$userStorage = [string]$rgResult.Outputs['storageAccountName']
$userContainer = [string]$rgResult.Outputs['containerName']

# Upload the employee CSV into the attendee container.
$csvPath = Join-Path $PSScriptRoot 'csvdata/employees_user_data.csv'
if (-not (Test-Path $csvPath)) { throw "Employee CSV not found: $csvPath" }
$userStorageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $userStorage --query "[0].value" -o tsv
az storage blob upload --account-name $userStorage --account-key $userStorageKey `
    --container-name $userContainer --name (Split-Path $csvPath -Leaf) --file $csvPath --overwrite true --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to upload employee CSV." }

# ─────────────────────────────────────────────
# 2. Restore the two attendee databases in the shared SQL MI
# ─────────────────────────────────────────────
Update-MhhToken
$storageAccount = az storage account list -g $SharedResourceGroup --query "[0].name" -o tsv
$containerName = 'build'
$storageKey = az storage account keys list --resource-group $SharedResourceGroup --account-name $storageAccount --query "[0].value" -o tsv
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

$restores = @(
    @{ Db = $sqlDb; Bak = $TailspinToysBak },
    @{ Db = $feedbackDb; Bak = $TailspinToysFeedbackBak }
)
foreach ($r in $restores) {
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
Update-MhhToken
Invoke-MiSql -Server $server -Database 'master' -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$upn')
    CREATE LOGIN [$upn] FROM EXTERNAL PROVIDER;
"@ | Out-Null

$productSqlTemplate = Get-Content -Raw (Join-Path $PSScriptRoot 'sql/InsertProduct.sql')
foreach ($db in @($sqlDb, $feedbackDb)) {
    Invoke-MiSql -Server $server -Database $db -QueryTimeout 60 -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$upn')
    CREATE USER [$upn] FROM LOGIN [$upn];
ALTER ROLE [db_owner] ADD MEMBER [$upn];
"@ | Out-Null
}

# Ensure the Fabric Space Ranger product exists in the sales database (needed by the
# shared proc / Agent job, which read Product from each per-attendee database).
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
Update-MhhToken
$capacityName = az resource list -g $SharedResourceGroup --resource-type 'Microsoft.Fabric/capacities' --query "[0].name" -o tsv
$capacity = (Invoke-FabricApi -Method GET -Path 'capacities').value | Where-Object { $_.displayName -eq $capacityName } | Select-Object -First 1
if (-not $capacity) { throw "Fabric capacity '$capacityName' not visible via the Fabric API." }

$workspaceName = "Workspace_$short"
$workspace = (Invoke-FabricApi -Method GET -Path 'workspaces').value | Where-Object { $_.displayName -eq $workspaceName } | Select-Object -First 1
if (-not $workspace) {
    Write-Host "[lab] Creating Fabric workspace '$workspaceName'."
    $workspace = Invoke-FabricApi -Method POST -Path 'workspaces' -Body @{
        displayName = $workspaceName
        capacityId  = $capacity.id
    }
}
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
@{ HackboxCredential = @{ name = 'Sales Database'; value = $sqlDb; note = 'Your TailspinToys database on the shared SQL MI' } }
@{ HackboxCredential = @{ name = 'Feedback Database'; value = $feedbackDb; note = 'Your feedback database' } }
@{ HackboxCredential = @{ name = 'Fabric Workspace'; value = $workspaceName; note = 'Your Fabric workspace' } }
@{ HackboxCredential = @{ name = 'Employee CSV Storage'; value = $userStorage; note = "Container '$userContainer'" } }

Write-Host "[lab] Deployment complete for $upn."
