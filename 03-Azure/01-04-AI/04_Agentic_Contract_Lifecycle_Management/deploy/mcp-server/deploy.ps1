#Requires -Version 5.1
<#
=============================================================================
 Challenge 4 · Deploy the CLM MCP server to Azure Container Apps (remote MCP)
 -----------------------------------------------------------------------------
 Windows/PowerShell twin of deploy.sh. Builds the image in the cloud (no local
 Docker) and prints the /mcp URL a Foundry agent connects to. Run it from the
 REPO ROOT; the build context is the src/ folder (Dockerfile + requirements.txt + app code).

 ZERO-CONFIG by default: reads your repo-root .env for AZURE_AI_PROJECT_ENDPOINT
 + MODEL_*, then auto-discovers the resource group, Foundry account id and region
 from that endpoint. Usually just:

     ./deploy/mcp-server/deploy.ps1          # from the repo root, no args

 Everything is overridable with parameters or env vars.

 Prereqs: az CLI logged in (az login) on your lab subscription, and a filled .env.
=============================================================================
#>
[CmdletBinding()]
param(
  [string]$AppName          = $env:APP_NAME,
  [string]$ResourceGroup    = $env:RESOURCE_GROUP,
  [string]$Location         = $env:LOCATION,
  [string]$ProjectEndpoint  = $env:AZURE_AI_PROJECT_ENDPOINT,
  [string]$FoundryAccountId = $env:FOUNDRY_ACCOUNT_ID,
  [string]$EnvFile          = $env:ENV_FILE
)
$ErrorActionPreference = "Stop"

# Zero-config: default to the repo-root .env, but fall back to src/.env - many
# participants copy src/.env.example in place and keep their .env there (it's the
# CWD their agents run from). An explicit -EnvFile / $env:ENV_FILE always wins.
if (-not $EnvFile) {
  if     (Test-Path ".env")     { $EnvFile = ".env" }
  elseif (Test-Path "src/.env") { $EnvFile = "src/.env" }
  else                          { $EnvFile = ".env" }
}

# ---- Load repo-root .env (only fills values you haven't already set) ---------
$envMap = @{}
if (Test-Path $EnvFile) {
  Write-Host "==> Reading $EnvFile"
  foreach ($line in Get-Content -LiteralPath $EnvFile) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#") -or ($t -notmatch "=")) { continue }
    $k = $t.Substring(0, $t.IndexOf("=")).Trim()
    $v = $t.Substring($t.IndexOf("=") + 1).Trim()
    if ($k) { $envMap[$k] = $v }
  }
}
function Get-Val([string]$explicit, [string]$key, [string]$default) {
  if ($explicit) { return $explicit }
  if ($envMap.ContainsKey($key) -and $envMap[$key]) { return $envMap[$key] }
  return $default
}

$AppName          = if ($AppName) { $AppName } else { "clm-mcp" }
$ProjectEndpoint  = Get-Val $ProjectEndpoint "AZURE_AI_PROJECT_ENDPOINT" ""
if (-not $ProjectEndpoint) { throw "AZURE_AI_PROJECT_ENDPOINT is not set. Fill it in your .env (repo-root .env or src/.env), pass -EnvFile <path> (e.g. -EnvFile .\src\.env), or pass -ProjectEndpoint <url>. See Challenge 1, Step 3." }
$ModelOrchestrator = Get-Val "" "MODEL_ORCHESTRATOR" "gpt-5.4"
$ModelDrafting     = Get-Val "" "MODEL_DRAFTING"     "gpt-5.4"
$ModelClauseRisk   = Get-Val "" "MODEL_CLAUSE_RISK"  "gpt-5.6-sol"

# ---- Auto-discover RG / Foundry account / region from the project endpoint ---
if (-not $FoundryAccountId -or -not $ResourceGroup -or -not $Location) {
  $endpointHost = ([Uri]$ProjectEndpoint).Host
  $account = $endpointHost.Split(".")[0]
  Write-Host "==> Discovering the Foundry account '$account' in your subscription"
  $row = az cognitiveservices account list `
      --query "[?name=='$account'].[id,resourceGroup,location] | [0]" -o tsv 2>$null
  if (-not $row) {
    $row = az cognitiveservices account list --query "[0].[id,resourceGroup,location]" -o tsv 2>$null
    if ($row) { Write-Host "    (no exact name match - using the first AI account found)" }
  }
  if ($row) {
    $parts = $row -split "`t"
    if (-not $FoundryAccountId) { $FoundryAccountId = $parts[0] }
    if (-not $ResourceGroup)    { $ResourceGroup    = $parts[1] }
    if (-not $Location)         { $Location         = $parts[2] }
  }
}
if (-not $ResourceGroup -and $FoundryAccountId -match "/resourceGroups/([^/]+)/") {
  $ResourceGroup = $Matches[1]
}
if (-not $Location) { $Location = "swedencentral" }
if (-not $ResourceGroup) { throw "could not determine ResourceGroup - set it explicitly (is 'az login' done?)" }

Write-Host "==> Using:"
Write-Host "    resource group   = $ResourceGroup"
Write-Host "    region           = $Location"
Write-Host ("    Foundry account  = " + $(if ($FoundryAccountId) { $FoundryAccountId } else { "<none found - role grant will be skipped>" }))
Write-Host "    project endpoint = $ProjectEndpoint"

Write-Host "==> Ensuring the containerapp CLI extension + providers are ready"
az extension add --name containerapp --upgrade --only-show-errors 2>$null | Out-Null
# Provider registration is a SUBSCRIPTION-scope action. In a resource-group lab you
# only own the RG, so re-registering fails with AuthorizationFailed — but the platform
# already registered these when it provisioned the lab. Check first; only try to register
# if actually needed. EAP is relaxed here because PowerShell 5.1 treats az's stderr as a
# terminating error under $ErrorActionPreference='Stop' — these calls must stay best-effort.
$eapSaved = $ErrorActionPreference
$ErrorActionPreference = "Continue"
foreach ($ns in @("Microsoft.App", "Microsoft.OperationalInsights")) {
  $state = az provider show --namespace $ns --query registrationState -o tsv 2>$null
  if ($state -eq "Registered") { Write-Host "    $ns already registered"; continue }
  Write-Host "    registering $ns (needs subscription rights; skipping if not allowed)"
  az provider register --namespace $ns --only-show-errors 2>$null | Out-Null
}
$ErrorActionPreference = $eapSaved

Write-Host "==> Building + deploying '$AppName' to Azure Container Apps (image builds in the cloud)"
# Self-heal: az containerapp up auto-names the env '<app>-env' and REUSES it by name.
# A prior crashed/aborted run can leave that env stuck in a non-Succeeded state, which
# then fails every re-run with 'ManagedEnvironmentNotProvisioned'. Delete a bad one first.
$EnvName = "$AppName-env"
$envState = az containerapp env show -n $EnvName -g $ResourceGroup --query "properties.provisioningState" -o tsv 2>$null
if ($envState -and $envState -ne "Succeeded") {
  Write-Host "!! Container Apps environment '$EnvName' is '$envState' (a prior failed run) - deleting it so it can be recreated cleanly" -ForegroundColor Yellow
  az containerapp env delete -n $EnvName -g $ResourceGroup --yes 2>$null | Out-Null
}
$eapUp = $ErrorActionPreference
$ErrorActionPreference = 'Continue'   # handle a cloud-build failure with a clear message, not a raw NativeCommandError
az containerapp up `
  --name $AppName `
  --resource-group $ResourceGroup `
  --location $Location `
  --source src `
  --ingress external `
  --target-port 8000 `
  --env-vars `
      "AZURE_AI_PROJECT_ENDPOINT=$ProjectEndpoint" `
      "MODEL_ORCHESTRATOR=$ModelOrchestrator" `
      "MODEL_DRAFTING=$ModelDrafting" `
      "MODEL_CLAUSE_RISK=$ModelClauseRisk" `
      "MCP_TRANSPORT=streamable-http" `
      "MCP_PORT=8000"
$upExit = $LASTEXITCODE
$ErrorActionPreference = $eapUp
if ($upExit -ne 0) {
  Write-Host ""
  Write-Host "!! 'az containerapp up' failed (exit $upExit) - stopping before the identity/role steps." -ForegroundColor Red
  Write-Host "   Read the FIRST error above; the two common ones are:" -ForegroundColor Red
  Write-Host "   - \"'NoneType' object has no attribute 'linux'\" (in queue_acr_build): Azure CLI 2.86.0 bug" -ForegroundColor Red
  Write-Host "     (Azure/azure-cli#33369). Fix: 'az upgrade' (need >= 2.87.0), reopen the shell, re-run." -ForegroundColor Red
  Write-Host "   - 'ManagedEnvironmentNotProvisioned': the env '$EnvName' is stuck from a prior run." -ForegroundColor Red
  Write-Host "     Fix: az containerapp env delete -n $EnvName -g $ResourceGroup --yes , then re-run." -ForegroundColor Red
  Write-Host "   Re-running is safe - the ACR image + a healthy env are reused." -ForegroundColor Red
  exit 1
}

Write-Host "==> Enabling the app's system-assigned managed identity"
az containerapp identity assign --name $AppName --resource-group $ResourceGroup --system-assigned | Out-Null
$PrincipalId = az containerapp show -n $AppName -g $ResourceGroup --query identity.principalId -o tsv
Write-Host "    principalId = $PrincipalId"
if (-not $PrincipalId) {
  Write-Host "!! Could not read the app's managed-identity principalId - the app may not have been created." -ForegroundColor Red
  Write-Host "   Skipping the role assignment. Re-run the deploy once the app exists." -ForegroundColor Red
  exit 1
}

if ($FoundryAccountId) {
  Write-Host "==> Granting the identity access to your Foundry models"
  # 53ca6127... is the built-in role "Azure AI User" (recently RENAMED to "Foundry User").
  # Assign it by role-definition GUID, because the display name "Azure AI User" no longer
  # resolves ('az ... --role "Azure AI User"' fails with "Role ... doesn't exist"). Fall
  # back to the older inference roles by name if the GUID ever isn't present in the tenant.
  $ok = $false
  foreach ($role in @("53ca6127-db72-4b80-b1b0-d745d6d5456d", "Cognitive Services User", "Cognitive Services OpenAI User")) {
    $out = az role assignment create --assignee-object-id $PrincipalId `
        --assignee-principal-type ServicePrincipal `
        --role $role --scope $FoundryAccountId 2>&1
    if ($LASTEXITCODE -eq 0 -or ($out -match "already exists")) { $ok = $true; break }
  }
  if ($ok) { Write-Host "    role assigned (identity propagation can take ~1 minute)" }
  else { Write-Host "!! role assignment failed - grant 'Azure AI User' (role id 53ca6127-db72-4b80-b1b0-d745d6d5456d) on $FoundryAccountId to $PrincipalId yourself" -ForegroundColor Yellow }
} else {
  Write-Host "!! FOUNDRY_ACCOUNT_ID not found - grant a data-plane role to the identity yourself:"
  Write-Host "     az role assignment create --assignee-object-id $PrincipalId ``"
  Write-Host "       --assignee-principal-type ServicePrincipal ``"
  Write-Host "       --role 53ca6127-db72-4b80-b1b0-d745d6d5456d --scope <your Foundry account resource id>"
}

$Fqdn = az containerapp show -n $AppName -g $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv
Write-Host ""
Write-Host "============================================================"
Write-Host " clm-mcp is live. Use this MCP endpoint in Foundry / CLM_MCP_URL:"
Write-Host "     https://$Fqdn/mcp"
Write-Host "============================================================"
