<#!
.SYNOPSIS
Automates Azure AD (Entra ID) setup to enable SSO (OIDC group-based) for an existing Oracle Autonomous Database (ADB).

.DESCRIPTION
Creates (idempotently):
 1. Security groups for DB role mapping (ODB_DBA, ODB_READWRITE, ODB_READONLY) and optional custom names.
 2. An App Registration configured to emit group claims in access & id tokens.
 3. A Service Principal for the app.
 4. Outputs a metadata JSON file with endpoints & group/object IDs for use in Oracle ADB configuration.

This script only handles Azure side prerequisites. Oracle-side steps (executed via SQL*Plus / OCI) must use the produced metadata.

.REQUIREMENTS
 - Azure CLI (az) logged in with sufficient privileges (App Registration + Group + Graph Patch rights)
 - Permission to call Microsoft Graph (Application.ReadWrite.All, Group.ReadWrite.All) if tenant restrictions apply

.NOTES
Tested with Azure CLI >= 2.62 (Graph v1.0). Adjust if your CLI differs.
#>
[CmdletBinding()]param(
  [Parameter(Mandatory)] [string]$SubscriptionId,
  [Parameter(Mandatory)] [string]$TenantId,
  [string]$AppDisplayName = 'OracleADB-SSO',
  [string]$IdentifierUri,               # If blank a new api:// GUID URI is generated
  [string]$RedirectUri = 'https://localhost/redirect',
  [string]$GroupDbaName = 'ODB_DBA',
  [string]$GroupReadWriteName = 'ODB_READWRITE',
  [string]$GroupReadOnlyName = 'ODB_READONLY',
  [string[]]$DbaMembers = @(),          # User (objectId or UPN) list
  [string[]]$ReadWriteMembers = @(),
  [string[]]$ReadOnlyMembers = @(),
  [string]$OutputMetadataFile = './oracle-adb-entra-metadata.json',
  [switch]$SkipGroupCreation            # If groups already exist
)

function Ensure-AzContext {
  Write-Verbose 'Ensuring Azure CLI context.'
  $acct = az account show --only-show-errors 2>$null | ConvertFrom-Json
  if(-not $acct){
    Write-Host 'Logging in...' -ForegroundColor Cyan
    az login --only-show-errors | Out-Null
  }
  az account set -s $SubscriptionId --only-show-errors
}

function Get-GroupId($name){
  $gid = az ad group list --display-name $name --query '[0].id' -o tsv 2>$null
  return $gid
}

function Ensure-Group($name){
  $gid = Get-GroupId $name
  if($gid){ Write-Host "Group $name exists ($gid)"; return $gid }
  if($SkipGroupCreation){ throw "Group $name not found and creation skipped." }
  Write-Host "Creating group $name" -ForegroundColor Cyan
  $gid = az ad group create --display-name $name --mail-nickname $name --query id -o tsv
  return $gid
}

function Ensure-Members($groupName, [string[]]$members){
  if(-not $members -or $members.Count -eq 0){ return }
  $existing = az ad group member list --group $groupName --query '[].id' -o tsv | Sort-Object -Unique
  foreach($m in $members){
    $mid = $m
    if($m -notmatch '^[0-9a-f-]{36}$'){
      # Treat as UPN -> resolve objectId
      $mid = az ad user show --id $m --query id -o tsv 2>$null
      if(-not $mid){ Write-Warning "Could not resolve user $m"; continue }
    }
    if($existing -contains $mid){ continue }
    Write-Host "Adding member $m to $groupName" -ForegroundColor DarkCyan
    az ad group member add --group $groupName --member-id $mid --only-show-errors 2>$null
  }
}

function Ensure-AppRegistration {
  param([string]$name,[string]$redirect,[string]$identifierUri)
  $app = az ad app list --display-name $name --query '[0]' -o json | ConvertFrom-Json
  if(-not $app){
    if(-not $identifierUri -or $identifierUri -eq ''){ $identifierUri = "api://$([guid]::NewGuid())" }
    Write-Host "Creating App Registration $name" -ForegroundColor Cyan
    $appJson = az ad app create `
      --display-name $name `
      --sign-in-audience AzureADMyOrg `
      --identifier-uris $identifierUri `
      --web-redirect-uris $redirect `
      --enable-access-token-issuance true `
      --enable-id-token-issuance true -o json | ConvertFrom-Json
    $app = $appJson
  }
  else {
    if($identifierUri){ Write-Verbose 'Identifier URI provided but app exists; skipping update.' }
  }
  # Ensure group claims
  if($app.groupMembershipClaims -ne 'SecurityGroup'){
    Write-Host 'Setting groupMembershipClaims=SecurityGroup' -ForegroundColor Cyan
    az ad app update --id $app.appId --set groupMembershipClaims=SecurityGroup --only-show-errors | Out-Null
  }
  # Ensure optional group claims (access & id tokens)
  $objectId = $app.id  # Directory (object) id
  Write-Host 'Ensuring optional claims for groups' -ForegroundColor Cyan
  $claimsBody = @{ optionalClaims = @{ idToken = @(@{ name='groups' }); accessToken = @(@{ name='groups' }) } } | ConvertTo-Json -Depth 6
  az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$objectId" --headers 'Content-Type=application/json' --body $claimsBody --only-show-errors | Out-Null

  # Ensure service principal
  $sp = az ad sp list --filter "appId eq '$($app.appId)'" --query '[0]' -o json | ConvertFrom-Json
  if(-not $sp){
    Write-Host 'Creating Service Principal' -ForegroundColor Cyan
    $sp = az ad sp create --id $app.appId -o json | ConvertFrom-Json
  }
  return $app
}

function Write-Metadata {
  param($app,$groupMap)
  $issuer = "https://login.microsoftonline.com/$TenantId/v2.0"
  $metadata = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    tenantId     = $TenantId
    subscriptionId = $SubscriptionId
    app = @{ displayName=$app.displayName; appId=$app.appId; identifierUris=$app.identifierUris; objectId=$app.id }
    oidc = @{ issuer=$issuer; authorization_endpoint="https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize"; token_endpoint="https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"; jwks_uri="https://login.microsoftonline.com/$TenantId/discovery/v2.0/keys" }
    groups = $groupMap
    guidance = @{ oracle_next_steps = @(
      'In ADB: map Entra ID group object IDs to database roles/users.',
      'Use DBMS_CLOUD_ADMIN.CREATE_CLOUD_USER or appropriate role mapping feature.',
      'Grant privileges based on ODB_DBA / ODB_READWRITE / ODB_READONLY mappings.',
      'Test: Acquire token (az account get-access-token --resource <identifierUri>) and connect using Oracle client supporting OAuth.'
    ) }
  }
  $json = ($metadata | ConvertTo-Json -Depth 8)
  Set-Content -Path $OutputMetadataFile -Value $json -Encoding UTF8
  Write-Host "Metadata written to $OutputMetadataFile" -ForegroundColor Green
}

# ------------- MAIN -------------
Ensure-AzContext

$groupIds = @{}
$gidDba = Ensure-Group $GroupDbaName; $groupIds[$GroupDbaName] = $gidDba
$gidRw  = Ensure-Group $GroupReadWriteName; $groupIds[$GroupReadWriteName] = $gidRw
$gidRo  = Ensure-Group $GroupReadOnlyName; $groupIds[$GroupReadOnlyName] = $gidRo

Ensure-Members $GroupDbaName $DbaMembers
Ensure-Members $GroupReadWriteName $ReadWriteMembers
Ensure-Members $GroupReadOnlyName $ReadOnlyMembers

$app = Ensure-AppRegistration -name $AppDisplayName -redirect $RedirectUri -identifierUri $IdentifierUri

Write-Metadata -app $app -groupMap $groupIds

Write-Host 'Done.' -ForegroundColor Green

<#!
EXAMPLE:
  pwsh ./Enable-EntraSSO-OracleADB.ps1 -SubscriptionId '00000000-0000-0000-0000-000000000000' -TenantId '11111111-1111-1111-1111-111111111111' `
    -DbaMembers user1@contoso.com -ReadWriteMembers user2@contoso.com -ReadOnlyMembers user3@contoso.com

Then configure Oracle ADB using the produced oracle-adb-entra-metadata.json.
#>
