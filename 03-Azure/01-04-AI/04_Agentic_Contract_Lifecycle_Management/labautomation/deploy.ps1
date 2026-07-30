<#
  Challenge 1 — provision the Foundry CLM microhack resources and write .env (Windows).
  Usage:   ./labautomation/deploy.ps1 [-WithSql] [-WithBing]
  Requires: az CLI (az login), rights to deploy GPT + Anthropic Claude models.
  The bash script (labautomation/deploy.sh) is the primary path for Codespaces.
#>
param([switch]$WithSql, [switch]$WithBing)
$ErrorActionPreference = "Stop"

$Location    = $env:LOCATION    ?? "swedencentral"
$Suffix      = $env:SUFFIX      ?? -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
$Rg          = $env:RG          ?? "rg-clm-microhack"
$Foundry     = $env:FOUNDRY     ?? "clmfoundry$Suffix"
$Project     = $env:PROJECT     ?? "clm-project"
$Search      = $env:SEARCH      ?? "clmsearch$Suffix"
$AppInsights = "clm-appinsights"

$GptOrch = "gpt-5.4"; $GptMini = "gpt-5-mini"; $Gpt56Sol = "gpt-5.6-sol"; $Claude = "claude-opus-4-8"

# Claude can be skipped (no Anthropic quota / marketplace offer): set
# $env:DEPLOY_CLAUDE = "false". The drafting agent then uses the orchestrator (Clause & Risk stays on gpt-5.6-sol).
# When $env:DEPLOY_CLAUDE is NOT set, auto-probe Anthropic Claude Opus 4.8 quota in
# $Location and skip Claude when it is 0 — otherwise the deployment fails with
# "InsufficientQuota ... Claude Opus 4.8 ... available capacity 0". Availability !=
# quota: even in a region that offers the model a fresh sandbox sub usually starts at 0.
function Test-ClaudeQuota {
  param([string]$Region, [int]$RequiredCapacity = 20)
  $quotaFamily = "AIServices.GlobalStandard.claude-opus-4-8"
  try {
    $subId = az account show --query id -o tsv
    if (-not $subId) { throw "could not resolve subscription id (run az login)" }
    $uri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.CognitiveServices/locations/$Region/usages?api-version=2024-10-01"
    $json = az rest --method get --url $uri -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { throw "usages query failed" }
    $usages = ($json | ConvertFrom-Json).value
    $entry = $usages | Where-Object { $_.name.value -eq $quotaFamily } | Select-Object -First 1
    if (-not $entry) {
      $entry = $usages | Where-Object { $_.name.value -match 'claude-opus-4-8' } |
        Sort-Object { [double]$_.limit } -Descending | Select-Object -First 1
    }
    if (-not $entry) { Write-Host "  · Claude preflight: no quota entry for claude-opus-4-8 in $Region — skipping Claude (GPT-only)."; return $false }
    $limit = [double]$entry.limit; $used = [double]$entry.currentValue
    if ($limit -le 0 -or ($limit - $used) -lt $RequiredCapacity) {
      Write-Host "  · Claude preflight: insufficient quota in $Region (limit=$limit, used=$used, need=$RequiredCapacity) — skipping Claude (GPT-only)."
      return $false
    }
    Write-Host "  ✓ Claude preflight: claude-opus-4-8 deployable in $Region (limit=$limit, used=$used)."
    return $true
  }
  catch {
    Write-Host "  · Claude preflight: quota probe failed ($($_.Exception.Message)) — skipping Claude (GPT-only). Set `$env:DEPLOY_CLAUDE='true' to force it."
    return $false
  }
}

if ([string]::IsNullOrWhiteSpace($env:DEPLOY_CLAUDE)) {
  $DeployClaude = Test-ClaudeQuota -Region $Location
} else {
  $DeployClaude = $env:DEPLOY_CLAUDE.ToLower() -eq "true"
}
$DraftingModel = if ($DeployClaude) { $Claude } else { $GptOrch }

# Anthropic Marketplace attestation — REQUIRED by the Cognitive Services RP for
# every Claude deployment. Override via $env:CLAUDE_ORGANIZATION_NAME / _COUNTRY_CODE /
# _INDUSTRY. Omitting these is what triggers InvalidModelProviderData.
$ClaudeOrg      = $env:CLAUDE_ORGANIZATION_NAME ?? "Contoso"
$ClaudeCountry  = $env:CLAUDE_COUNTRY_CODE       ?? "US"
$ClaudeIndustry = $env:CLAUDE_INDUSTRY           ?? "technology"

Write-Host "▶ Resource group: $Rg ($Location); Foundry $Foundry / project $Project"

az group create -n $Rg -l $Location -o none

az cognitiveservices account create -n $Foundry -g $Rg -l $Location `
  --kind AIServices --sku S0 --custom-domain $Foundry --yes -o none
Write-Host "  ✓ Foundry account created"

az cognitiveservices account project create --account-name $Foundry -g $Rg --project-name $Project -o none 2>$null `
  ; if ($LASTEXITCODE -ne 0) { Write-Host "  ! Create project '$Project' in the portal, then re-run." }

function Deploy-Model($name, $model, $version, $format, $cap) {
  Write-Host "  → deploying $name ($format $model v$version)"
  az cognitiveservices account deployment create -n $Foundry -g $Rg `
    --deployment-name $name --model-name $model --model-version $version --model-format $format `
    --sku-name GlobalStandard --sku-capacity $cap -o none 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Host "    ! $name failed — check availability in $Location." }
}
Deploy-Model $GptOrch  "gpt-5.4"          "2026-03-05" "OpenAI"    30
Deploy-Model $GptMini  "gpt-5-mini"       "2025-08-07" "OpenAI"    30
# Clause & Risk runs on gpt-5.6-sol — its own deployment, independent of Claude.
Deploy-Model $Gpt56Sol "gpt-5.6-sol"      "2026-07-09" "OpenAI"    30
# Claude: Anthropic deployments REQUIRE a modelProviderData block the CLI can't
# send, so deploy via the ARM REST API (auto-accepts the marketplace offer).
function Deploy-Claude {
  $subId = az account show --query id -o tsv
  $url = "https://management.azure.com/subscriptions/$subId/resourceGroups/$Rg/providers/Microsoft.CognitiveServices/accounts/$Foundry/deployments/$Claude`?api-version=2025-04-01-preview"
  $bodyObj = @{
    sku = @{ name = "GlobalStandard"; capacity = 20 }
    properties = @{
      model = @{ format = "Anthropic"; name = "claude-opus-4-8"; version = "2" }
      modelProviderData = @{ organizationName = $ClaudeOrg; countryCode = $ClaudeCountry; industry = $ClaudeIndustry }
    }
  }
  $tmp = New-TemporaryFile
  ($bodyObj | ConvertTo-Json -Depth 5) | Set-Content -Path $tmp -Encoding utf8
  Write-Host "  → deploying $Claude (Anthropic claude-opus-4-8 v2) with modelProviderData"
  az rest --method put --url $url --body "@$tmp" -o none 2>$null
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  if ($LASTEXITCODE -ne 0) {
    Write-Host "    ! Claude deployment request failed — check Anthropic eligibility in $Location, or set `$env:DEPLOY_CLAUDE='false' to skip."
    return
  }
  foreach ($i in 1..30) {
    $state = az rest --method get --url $url --query "properties.provisioningState" -o tsv 2>$null
    if ($state -eq "Succeeded") { Write-Host "    ✓ Claude deployment succeeded"; return }
    if ($state -eq "Failed" -or $state -eq "Canceled") { Write-Host "    ! Claude deployment $state — set `$env:DEPLOY_CLAUDE='false' to skip."; return }
    Start-Sleep -Seconds 10
  }
  Write-Host "    · Claude still provisioning — check the Foundry portal before the smoke test."
}
if ($DeployClaude) {
  Deploy-Claude
} else {
  Write-Host "  · Skipping Claude (DEPLOY_CLAUDE=false) — drafting uses $GptOrch"
}

az search service create -n $Search -g $Rg -l $Location --sku basic --partition-count 1 --replica-count 1 -o none
Write-Host "  ✓ Azure AI Search created"

# Corpus source is SharePoint (BYO) — nothing to create; seed_corpus.py wires the
# AI Search SharePoint indexer. Fill SHAREPOINT_* in .env first (see challenge-0 README).
Write-Host "  · Corpus source is SharePoint (BYO) — set SHAREPOINT_* in .env, then run seed_corpus.py"

az monitor app-insights component create --app $AppInsights -g $Rg -l $Location --kind web -o none
$AppInsightsConn = az monitor app-insights component show --app $AppInsights -g $Rg --query connectionString -o tsv
Write-Host "  ✓ Application Insights created"

# Connect App Insights to the Foundry project so the portal Tracing tab renders
# spans. Creating the component (above) is NOT enough — the project needs a
# connection to it, otherwise Tracing stays empty even when spans reach App
# Insights. (Challenge 3.)
$AppInsightsId = az monitor app-insights component show --app $AppInsights -g $Rg --query id -o tsv
$SubId = az account show --query id -o tsv
$ProjectArmId = "/subscriptions/$SubId/resourceGroups/$Rg/providers/Microsoft.CognitiveServices/accounts/$Foundry/projects/$Project"
if ($AppInsightsId -and $AppInsightsConn) {
  $AiBody = @{ properties = @{ category = "AppInsights"; target = $AppInsightsId; authType = "ApiKey";
    credentials = @{ key = $AppInsightsConn }; isSharedToAll = $true;
    metadata = @{ ApiType = "Azure"; ResourceId = $AppInsightsId } } } |
    ConvertTo-Json -Depth 6 -Compress
  $AiTmp = New-TemporaryFile
  $AiBody | Out-File -FilePath $AiTmp -Encoding utf8
  az rest --method put --url "https://management.azure.com$ProjectArmId/connections/clm-appinsights`?api-version=2025-04-01-preview" --body "@$($AiTmp.FullName)" -o none 2>$null
  if ($LASTEXITCODE -eq 0) { Write-Host "  ✓ Application Insights connected to project '$Project' — portal Tracing enabled" }
  else { Write-Host "    ! App Insights connection failed — in the portal open project '$Project' → Tracing → Connect and pick '$AppInsights'." }
  Remove-Item $AiTmp -ErrorAction SilentlyContinue
}

# Grounding with Bing Search (optional web grounding for the Clause & Risk agent).
# Bing search data leaves the Azure compliance boundary — opt in with -WithBing.
$BingConnName = ""
if ($WithBing) {
  $Bing = "clmbing$Suffix"; $BingConnName = "clm-bing"
  Write-Host "  → provisioning Grounding with Bing Search ($Bing)"
  az provider register --namespace Microsoft.Bing -o none 2>$null
  az resource create -g $Rg -n $Bing --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --is-full-object `
    --properties '{\"location\":\"global\",\"sku\":{\"name\":\"G1\"},\"kind\":\"Bing.Grounding\",\"properties\":{}}' -o none 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Host "    ! Bing resource create failed — ensure Microsoft.Bing is registered/available." }
  $BingId  = az resource show -g $Rg -n $Bing --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --query id -o tsv
  $BingKey = az resource invoke-action -g $Rg -n $Bing --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --action listKeys --query key1 -o tsv
  $SubId = az account show --query id -o tsv
  $ProjectArmId = "/subscriptions/$SubId/resourceGroups/$Rg/providers/Microsoft.CognitiveServices/accounts/$Foundry/projects/$Project"
  if ($BingId -and $BingKey) {
    $Body = @{ properties = @{ category = "ApiKey"; target = "https://api.bing.microsoft.com/"; authType = "ApiKey";
      credentials = @{ key = $BingKey }; isSharedToAll = $true;
      metadata = @{ ApiType = "Azure"; Location = "global"; ResourceId = $BingId; type = "bing_grounding" } } } |
      ConvertTo-Json -Depth 6 -Compress
    $Tmp = New-TemporaryFile
    $Body | Out-File -FilePath $Tmp -Encoding utf8
    az rest --method put --url "https://management.azure.com$ProjectArmId/connections/$BingConnName`?api-version=2025-04-01-preview" --body "@$($Tmp.FullName)" -o none 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  ✓ Bing connection '$BingConnName' created on project '$Project'" }
    else { Write-Host "    ! Bing connection create failed — add '$BingConnName' to project '$Project' in the portal." }
    Remove-Item $Tmp -ErrorAction SilentlyContinue
  }
} else {
  Write-Host "  · Skipping Bing web grounding (-WithBing to provision). Clause & Risk runs corpus-only."
}

$SqlConn = ""
if ($WithSql) {
  $SqlServer = "clmsql$Suffix"; $SqlDb = "clmdb"; $SqlPwd = "Clm!" + [System.Guid]::NewGuid().ToString("N").Substring(0,12)
  az sql server create -n $SqlServer -g $Rg -l $Location --admin-user clmadmin --admin-password $SqlPwd -o none
  az sql db create -s $SqlServer -g $Rg -n $SqlDb --service-objective Basic -o none
  az sql server firewall-rule create -s $SqlServer -g $Rg -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
  $SqlConn = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:$SqlServer.database.windows.net,1433;Database=$SqlDb;Uid=clmadmin;Pwd=$SqlPwd;Encrypt=yes;TrustServerCertificate=no;"
  Write-Host "  ✓ Azure SQL created"
} else {
  Write-Host "  · Skipping Azure SQL (-WithSql to provision). Tool falls back to src/data/contracts_seed.json."
}

$ProjectEndpoint = "https://$Foundry.services.ai.azure.com/api/projects/$Project"
$SearchEndpoint  = "https://$Search.search.windows.net"

@"
# Autogenerated by labautomation/deploy.ps1 — do not commit.
AZURE_AI_PROJECT_ENDPOINT=$ProjectEndpoint

MODEL_ORCHESTRATOR=$GptOrch
MODEL_DRAFTING=$DraftingModel
MODEL_CLAUSE_RISK=$Gpt56Sol
MODEL_RENEWAL=$GptMini

AZURE_SEARCH_ENDPOINT=$SearchEndpoint
AZURE_SEARCH_INDEX=clm-corpus
AZURE_SEARCH_CONNECTION_NAME=clm-search

# Web grounding (Grounding with Bing Search) — set when deployed with -WithBing.
AZURE_BING_CONNECTION_NAME=$BingConnName

# SharePoint corpus (BYO) — fill these in before running seed_corpus.py.
SHAREPOINT_SITE_URL=
SHAREPOINT_DOC_LIBRARY=Documents
SHAREPOINT_APP_ID=
SHAREPOINT_APP_SECRET=
SHAREPOINT_TENANT_ID=

APPLICATIONINSIGHTS_CONNECTION_STRING=$AppInsightsConn
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true

AZURE_SQL_CONNECTION_STRING=$SqlConn

MICROSOFT_APP_ID=
MICROSOFT_APP_PASSWORD=
MICROSOFT_APP_TENANT_ID=
TEAMS_SERVICE_URL=
TEAMS_CONVERSATION_ID=
"@ | Out-File -FilePath ".env" -Encoding utf8

Write-Host "`n✅ Deployment complete. Wrote .env. Next: python src/scripts/seed_corpus.py; python src/scripts/smoke_test.py"
