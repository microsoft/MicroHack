[CmdletBinding()]
param(
    [string]$ApimName = $env:HR_MCP_APIM_NAME,
    [string]$ApimResourceGroup = $env:HR_MCP_APIM_RESOURCE_GROUP,
    [string]$BackendBaseUrl = $env:HR_MCP_APIM_BACKEND_BASE_URL,
    [string]$ApiName = $env:HR_MCP_APIM_API_NAME,
    [string]$ApiPath = $env:HR_MCP_APIM_PATH,
    [string]$BackendName = $env:HR_MCP_APIM_BACKEND_NAME,
    [string]$ProductId = $env:HR_MCP_APIM_PRODUCT_ID,
    [string]$SubscriptionName = $env:HR_MCP_APIM_SUBSCRIPTION_NAME,
    [string]$RequiredScopeClaim = $env:HR_MCP_REQUIRED_SCOPE_CLAIM,
    [string]$RequiredRole = $(if ($env:HR_MCP_APP_ROLE_VALUE) { $env:HR_MCP_APP_ROLE_VALUE } else { 'Mcp.Invoke' }),
    [string]$BackendHostHeader = $env:HR_MCP_APIM_BACKEND_HOST_HEADER,
    [switch]$RequirePrivateBackend
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) { $PSNativeCommandUseErrorActionPreference = $false }

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" }
function Assert-Command { param([string]$Name) if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Required command not found: $Name" } }
function ConvertTo-TrimmedCliOutput { param([AllowNull()]$Value) if ($null -eq $Value) { return $null }; $text = [string]($Value | Select-Object -First 1); if ([string]::IsNullOrWhiteSpace($text)) { return $null }; return $text.Trim() }
function Get-AzdValue { param([string]$Name) $value = (& azd env get-value $Name 2>$null); if ($LASTEXITCODE -ne 0) { return $null }; return ConvertTo-TrimmedCliOutput $value }
function Get-FirstNonEmpty { param([AllowNull()][string[]]$Values) foreach ($value in $Values) { if (-not [string]::IsNullOrWhiteSpace($value)) { return $value } }; return $null }
function Save-AzdValue { param([string]$Name, [AllowNull()][string]$Value) if (-not [string]::IsNullOrWhiteSpace($Value)) { & azd env set $Name $Value *> $null } }
function Remove-McpSuffix { param([AllowNull()][string]$Url) if ([string]::IsNullOrWhiteSpace($Url)) { return $null }; $u = $Url.TrimEnd('/'); if ($u.EndsWith('/mcp', [StringComparison]::OrdinalIgnoreCase)) { return $u.Substring(0, $u.Length - 4).TrimEnd('/') }; return $u }
function Test-Truthy { param([AllowNull()][string]$Value) return $Value -in @('1','true','TRUE','True','yes','YES','Yes') }

Assert-Command az
Assert-Command azd
& az account show *> $null
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI is not logged in. Run az login, then rerun this script.' }

$azdResourceGroup = Get-AzdValue AZURE_RESOURCE_GROUP
$azdSubscriptionId = Get-AzdValue AZURE_SUBSCRIPTION_ID
$azdTenantId = Get-AzdValue AZURE_TENANT_ID
$subscriptionId = Get-FirstNonEmpty @($env:AZURE_SUBSCRIPTION_ID, $azdSubscriptionId)
if ($subscriptionId) { & az account set --subscription $subscriptionId }

$tenantId = Get-FirstNonEmpty @($env:HR_MCP_TENANT_ID, (Get-AzdValue HR_MCP_TENANT_ID), $env:AZURE_TENANT_ID, $azdTenantId, (ConvertTo-TrimmedCliOutput (& az account show --query tenantId -o tsv)))
$ApimName = Get-FirstNonEmpty @($ApimName, $env:APIM_NAME, $env:AZURE_APIM_NAME, (Get-AzdValue HR_MCP_APIM_NAME), (Get-AzdValue APIM_NAME), (Get-AzdValue AZURE_APIM_NAME))
$ApimResourceGroup = Get-FirstNonEmpty @($ApimResourceGroup, $env:APIM_RESOURCE_GROUP, $env:AZURE_APIM_RESOURCE_GROUP, (Get-AzdValue HR_MCP_APIM_RESOURCE_GROUP), (Get-AzdValue APIM_RESOURCE_GROUP), (Get-AzdValue AZURE_APIM_RESOURCE_GROUP), $azdResourceGroup)

if ([string]::IsNullOrWhiteSpace($ApimName)) {
    if (-not [string]::IsNullOrWhiteSpace($ApimResourceGroup)) {
        $countInRg = ConvertTo-TrimmedCliOutput (& az apim list --resource-group $ApimResourceGroup --query 'length(@)' -o tsv 2>$null)
        if ($countInRg -eq '1') {
            $ApimName = ConvertTo-TrimmedCliOutput (& az apim list --resource-group $ApimResourceGroup --query '[0].name' -o tsv)
            Write-Warning "APIM name was not provided; using the only APIM instance in resource group '$ApimResourceGroup': $ApimName"
        }
    }
    if ([string]::IsNullOrWhiteSpace($ApimName)) {
        $count = ConvertTo-TrimmedCliOutput (& az apim list --query 'length(@)' -o tsv 2>$null)
        if ($count -eq '1') {
            $ApimName = ConvertTo-TrimmedCliOutput (& az apim list --query '[0].name' -o tsv)
            $ApimResourceGroup = ConvertTo-TrimmedCliOutput (& az apim list --query '[0].resourceGroup' -o tsv)
            Write-Warning "APIM name was not provided; using the only APIM instance in the subscription: $ApimName"
        } else {
            throw 'Could not determine APIM instance. Set HR_MCP_APIM_NAME and HR_MCP_APIM_RESOURCE_GROUP, or azd env values APIM_NAME/AZURE_APIM_NAME.'
        }
    }
}

& az apim show --name $ApimName --resource-group $ApimResourceGroup *> $null
if ($LASTEXITCODE -ne 0) {
    $matchesJson = (& az apim list --query "[?name=='$ApimName']" -o json 2>$null)
    $matches = $matchesJson | ConvertFrom-Json
    if ($matches.Count -eq 1) {
        $ApimResourceGroup = $matches[0].resourceGroup
        Write-Warning "Resolved APIM resource group for ${ApimName}: $ApimResourceGroup"
    } else {
        throw "APIM '$ApimName' was not found in resource group '$ApimResourceGroup'. Set HR_MCP_APIM_RESOURCE_GROUP explicitly."
    }
}

$privateRequired = (Test-Truthy (Get-FirstNonEmpty @($env:HR_MCP_APIM_REQUIRE_PRIVATE_BACKEND, (Get-AzdValue HR_MCP_APIM_REQUIRE_PRIVATE_BACKEND)))) -or $RequirePrivateBackend.IsPresent
$privateBackend = Get-FirstNonEmpty @($env:HR_MCP_PRIVATE_BACKEND_URL, (Get-AzdValue HR_MCP_PRIVATE_BACKEND_URL))
$acaInternalFqdn = Get-FirstNonEmpty @($env:HR_MCP_ACA_INTERNAL_FQDN, (Get-AzdValue HR_MCP_ACA_INTERNAL_FQDN))
if ([string]::IsNullOrWhiteSpace($privateBackend) -and -not [string]::IsNullOrWhiteSpace($acaInternalFqdn)) { $privateBackend = "https://$acaInternalFqdn" }
$directUrl = Get-FirstNonEmpty @($env:HR_MCP_DIRECT_URL, (Get-AzdValue HR_MCP_DIRECT_URL))
$directMcpUrl = Get-FirstNonEmpty @($env:HR_MCP_DIRECT_MCP_URL, (Get-AzdValue HR_MCP_DIRECT_MCP_URL))

if ($privateRequired) {
    # $BackendBaseUrl defaults to $env:HR_MCP_APIM_BACKEND_BASE_URL (an explicit override for THIS run only).
    # The azd-persisted value is deliberately not consulted, so the freshly deployed $privateBackend wins
    # after a teardown + redeploy when the ACA managed-environment domain changes.
    $BackendBaseUrl = Get-FirstNonEmpty @($BackendBaseUrl, $privateBackend)
    if ([string]::IsNullOrWhiteSpace($BackendBaseUrl)) { throw 'Private APIM-to-ACA backend was requested. Set HR_MCP_PRIVATE_BACKEND_URL or HR_MCP_APIM_BACKEND_BASE_URL after VNet/DNS routing is ready.' }
} else {
    $BackendBaseUrl = Get-FirstNonEmpty @($BackendBaseUrl, $privateBackend, $directUrl, (Remove-McpSuffix $directMcpUrl))
}
$BackendBaseUrl = Remove-McpSuffix $BackendBaseUrl
if ([string]::IsNullOrWhiteSpace($BackendBaseUrl)) { throw 'Could not determine HR MCP backend base URL. Set HR_MCP_DIRECT_URL, HR_MCP_DIRECT_MCP_URL, or HR_MCP_APIM_BACKEND_BASE_URL.' }

$backendHost = ($BackendBaseUrl -replace '^[a-zA-Z]+://', '') -replace '/.*$', ''
if ($backendHost -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') {
    # IP backend: APIM must send the ACA internal FQDN as the Host header for ingress routing.
    if ([string]::IsNullOrWhiteSpace($BackendHostHeader)) {
        $BackendHostHeader = Get-FirstNonEmpty @($acaInternalFqdn, (Get-AzdValue HR_MCP_ACA_INTERNAL_FQDN))
    }
} else {
    # FQDN backend: always tie the Host header to the chosen backend host so a stale persisted
    # HR_MCP_APIM_BACKEND_HOST_HEADER can never disagree with the backend URL after a redeploy.
    $BackendHostHeader = $backendHost
}

$audience = Get-FirstNonEmpty @($env:HR_MCP_AUDIENCE, (Get-AzdValue HR_MCP_AUDIENCE))
$scope = Get-FirstNonEmpty @($env:HR_MCP_SCOPE, (Get-AzdValue HR_MCP_SCOPE))
if ([string]::IsNullOrWhiteSpace($RequiredScopeClaim) -and -not [string]::IsNullOrWhiteSpace($scope)) { $RequiredScopeClaim = ($scope -split '/')[-1] }
if ([string]::IsNullOrWhiteSpace($tenantId)) { throw 'HR_MCP_TENANT_ID is missing.' }
if ([string]::IsNullOrWhiteSpace($audience)) { throw 'HR_MCP_AUDIENCE is missing. Run deploy-hr-mcp first or set it explicitly.' }
if ([string]::IsNullOrWhiteSpace($RequiredScopeClaim)) { throw 'HR_MCP_SCOPE is missing. Run deploy-hr-mcp first or set HR_MCP_REQUIRED_SCOPE_CLAIM.' }

$ApiName = Get-FirstNonEmpty @($ApiName, (Get-AzdValue HR_MCP_APIM_API_NAME), 'hr-mcp-api')
$ApiPath = Get-FirstNonEmpty @($ApiPath, (Get-AzdValue HR_MCP_APIM_PATH), 'hr-mcp')
$BackendName = Get-FirstNonEmpty @($BackendName, (Get-AzdValue HR_MCP_APIM_BACKEND_NAME), 'hr-mcp-aca-backend')
$ProductId = Get-FirstNonEmpty @($ProductId, (Get-AzdValue HR_MCP_APIM_PRODUCT_ID), 'MCP-HR-Tools-DEV')
$SubscriptionName = Get-FirstNonEmpty @($SubscriptionName, (Get-AzdValue HR_MCP_APIM_SUBSCRIPTION_NAME), 'MCP-HR-Tools-DEV-SUB-01')

$scriptDir = Split-Path -Parent $PSCommandPath
$infraDir = Resolve-Path (Join-Path $scriptDir '..' 'infra')
$gatewayUrl = ConvertTo-TrimmedCliOutput (& az apim show --name $ApimName --resource-group $ApimResourceGroup --query gatewayUrl -o tsv)
$mcpUrl = "$($gatewayUrl.TrimEnd('/'))/$ApiPath/mcp"

Write-Step 'Publishing HR MCP API, backend, product, policy, and subscription to APIM'
& az deployment group create `
    --name 'publish-hr-mcp-apim' `
    --resource-group $ApimResourceGroup `
    --template-file (Join-Path $infraDir 'main.bicep') `
    --parameters `
        apimName=$ApimName `
        apiName=$ApiName `
        apiPath=$ApiPath `
        backendName=$BackendName `
        backendBaseUrl=$BackendBaseUrl `
        productId=$ProductId `
        subscriptionName=$SubscriptionName `
        tenantId=$tenantId `
        jwtAudience=$audience `
        requiredScope=$RequiredScopeClaim `
        requiredRole=$RequiredRole `
        backendHostHeader=$BackendHostHeader `
    --only-show-errors `
    -o none
if ($LASTEXITCODE -ne 0) { throw 'APIM publication deployment failed.' }

Write-Step 'Saving HR MCP APIM outputs to azd environment'
Save-AzdValue HR_MCP_APIM_NAME $ApimName
Save-AzdValue HR_MCP_APIM_RESOURCE_GROUP $ApimResourceGroup
Save-AzdValue HR_MCP_APIM_API_NAME $ApiName
Save-AzdValue HR_MCP_APIM_PATH $ApiPath
Save-AzdValue HR_MCP_APIM_MCP_URL $mcpUrl
Save-AzdValue HR_MCP_APIM_PRODUCT_ID $ProductId
Save-AzdValue HR_MCP_APIM_SUBSCRIPTION_NAME $SubscriptionName
Save-AzdValue HR_MCP_APIM_BACKEND_NAME $BackendName
Save-AzdValue HR_MCP_APIM_BACKEND_BASE_URL $BackendBaseUrl
Save-AzdValue HR_MCP_APIM_BACKEND_HOST_HEADER $BackendHostHeader

Write-Host "`nHR MCP APIM publication is ready."
Write-Host "APIM: $ApimName ($ApimResourceGroup)"
Write-Host "Backend base URL: $BackendBaseUrl"
Write-Host "MCP endpoint: $mcpUrl"
Write-Host "Product: $ProductId"
Write-Host "Subscription: $SubscriptionName"
Write-Host 'Use the APIM subscription key plus Authorization: Bearer <Entra token> when calling the APIM MCP endpoint.'
Write-Host ''
Write-Host 'Smoke test from the repository root:'
Write-Host '  cd workshop; uv run python ./mcp-hr/scripts/test-hr-mcp-apim.py'
Write-Host ''
Write-Host 'If automatic subscription-key retrieval is unavailable, set it without printing it:'
Write-Host "  `$env:HR_MCP_APIM_SUBSCRIPTION_KEY = az apim subscription show --resource-group '$ApimResourceGroup' --service-name '$ApimName' --sid '$SubscriptionName' --query primaryKey -o tsv"
Write-Host '  cd workshop; uv run python ./mcp-hr/scripts/test-hr-mcp-apim.py'
