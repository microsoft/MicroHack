#Requires -Version 5.1
<#
=============================================================================
 Challenge 5 · Deploy the Teams "capture reference" bot to Azure Container Apps
 -----------------------------------------------------------------------------
 Windows/PowerShell twin of deploy.sh. Removes the local run + dev tunnel from
 Task 6: builds the bot image in the cloud (no local Docker) and prints a stable
 public HTTPS messaging endpoint to paste into your Azure Bot. You still message
 the bot once in Teams — it echoes TEAMS_SERVICE_URL + TEAMS_CONVERSATION_ID back
 in the chat so you can paste them into your local .env and run proactive_alerts.py.

 Run from the REPO ROOT so the build context (requirements.txt + src/) is correct:

     ./deploy/capture-bot/deploy.ps1          # zero-config, reads .env

 Needs in .env (Task 6 step 1 — your OWN single-tenant app):
     MICROSOFT_APP_ID, MICROSOFT_APP_PASSWORD, MICROSOFT_APP_TENANT_ID
 Resource group / region auto-discovered from AZURE_AI_PROJECT_ENDPOINT
 (override with -ResourceGroup / -Location). This bot calls no Foundry models,
 so it needs no managed identity.

 Prereq: az CLI logged in (az login). The app secret is passed as a plain
 container env var for lab simplicity — this bot is throwaway; delete it when done.
=============================================================================
#>
[CmdletBinding()]
param(
  [string]$AppName        = $env:APP_NAME,
  [string]$ResourceGroup  = $env:RESOURCE_GROUP,
  [string]$Location       = $env:LOCATION,
  [string]$AppId          = $env:MICROSOFT_APP_ID,
  [string]$AppPassword    = $env:MICROSOFT_APP_PASSWORD,
  [string]$AppTenant      = $env:MICROSOFT_APP_TENANT_ID,
  [string]$ProjectEndpoint = $env:AZURE_AI_PROJECT_ENDPOINT,
  [string]$EnvFile        = $(if ($env:ENV_FILE) { $env:ENV_FILE } else { ".env" })
)
$ErrorActionPreference = "Stop"

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

$AppName     = if ($AppName) { $AppName } else { "clm-capture-bot" }
$AppId       = Get-Val $AppId       "MICROSOFT_APP_ID"        ""
$AppPassword = Get-Val $AppPassword "MICROSOFT_APP_PASSWORD"  ""
$AppTenant   = Get-Val $AppTenant   "MICROSOFT_APP_TENANT_ID" ""
if (-not $AppId)       { throw "set MICROSOFT_APP_ID — your OWN single-tenant app (Task 6 step 1)" }
if (-not $AppPassword) { throw "set MICROSOFT_APP_PASSWORD — the client-secret Value" }
if (-not $AppTenant)   { throw "set MICROSOFT_APP_TENANT_ID — your directory (tenant) id" }
$ProjectEndpoint = Get-Val $ProjectEndpoint "AZURE_AI_PROJECT_ENDPOINT" ""

# ---- Auto-discover RG / region from the Foundry project endpoint -------------
if ((-not $ResourceGroup -or -not $Location) -and $ProjectEndpoint) {
  $endpointHost = ([Uri]$ProjectEndpoint).Host
  $account = $endpointHost.Split(".")[0]
  Write-Host "==> Discovering the lab resource group from '$account'"
  $row = az cognitiveservices account list `
      --query "[?name=='$account'].[resourceGroup,location] | [0]" -o tsv 2>$null
  if (-not $row) {
    $row = az cognitiveservices account list --query "[0].[resourceGroup,location]" -o tsv 2>$null
  }
  if ($row) {
    $parts = $row -split "`t"
    if (-not $ResourceGroup) { $ResourceGroup = $parts[0] }
    if (-not $Location)      { $Location      = $parts[1] }
  }
}
if (-not $Location) { $Location = "swedencentral" }
if (-not $ResourceGroup) { throw "could not determine ResourceGroup - set it explicitly (is 'az login' done?)" }

Write-Host "==> Using:"
Write-Host "    app name       = $AppName"
Write-Host "    resource group = $ResourceGroup"
Write-Host "    region         = $Location"
Write-Host "    bot app id     = $AppId"

Write-Host "==> Ensuring the containerapp CLI extension + providers are ready"
az extension add --name containerapp --upgrade --only-show-errors 2>$null | Out-Null
az provider register --namespace Microsoft.App --wait 2>$null | Out-Null
az provider register --namespace Microsoft.OperationalInsights --wait 2>$null | Out-Null

# The shared Dockerfile runs the capture bot when APP_ROLE=capture-bot, and binds
# 0.0.0.0 (via CAPTURE_BOT_HOST) so the Container Apps ingress can reach :3978.
Write-Host "==> Building + deploying '$AppName' to Azure Container Apps (image builds in the cloud)"
az containerapp up `
  --name $AppName `
  --resource-group $ResourceGroup `
  --location $Location `
  --source . `
  --ingress external `
  --target-port 3978 `
  --env-vars `
      "APP_ROLE=capture-bot" `
      "CAPTURE_BOT_HOST=0.0.0.0" `
      "CAPTURE_BOT_PORT=3978" `
      "MICROSOFT_APP_ID=$AppId" `
      "MICROSOFT_APP_PASSWORD=$AppPassword" `
      "MICROSOFT_APP_TENANT_ID=$AppTenant"

$Fqdn = az containerapp show -n $AppName -g $ResourceGroup --query properties.configuration.ingress.fqdn -o tsv
Write-Host ""
Write-Host "============================================================"
Write-Host " clm-capture-bot is live. Set this as your Azure Bot's Messaging endpoint"
Write-Host " (your Bot -> Configuration -> Messaging endpoint -> Apply):"
Write-Host ""
Write-Host "     https://$Fqdn/api/messages"
Write-Host ""
Write-Host " Then: your Bot -> Channels -> Microsoft Teams -> Open in Teams -> send 'hi'."
Write-Host " The bot replies with TEAMS_SERVICE_URL + TEAMS_CONVERSATION_ID — paste those"
Write-Host " two lines into your local .env, then fire the alert:"
Write-Host "     python src/proactive_alerts.py --from-renewals --days 30"
Write-Host ""
Write-Host " Missed the reply? Read the values from the logs:"
Write-Host "     az containerapp logs show -n $AppName -g $ResourceGroup --tail 50"
Write-Host ""
Write-Host " Clean up when done:"
Write-Host "     az containerapp delete -n $AppName -g $ResourceGroup --yes"
Write-Host "============================================================"
