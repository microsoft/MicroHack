param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$labRoot = Split-Path -Parent $scriptPath
$context = Get-AzContext
if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
    throw 'The platform Azure context must match SubscriptionId.'
}
if ($AllowedEntraUserIds.Count -eq 0) {
    throw 'At least one participant Entra object ID is required.'
}
foreach ($userId in $AllowedEntraUserIds) {
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($userId, [ref]$parsedId)) {
        throw "Invalid participant Entra object ID: $userId"
    }
}
if ($PreferredLocation.Count -gt 1) {
    throw 'Choose one approved Azure region. This lab does not silently fall back across regions.'
}
$location = if ($PreferredLocation.Count -eq 1) { $PreferredLocation[0].Trim() } else { 'uksouth' }
if ([string]::IsNullOrWhiteSpace($location)) {
    throw 'PreferredLocation must not be blank.'
}
$identityParts = @($SubscriptionId) + @($AllowedEntraUserIds | Sort-Object -Unique)
if ($DeploymentType -eq 'subscription') {
    $groupSuffix = Get-MhhStableHash $identityParts -Length 24
    $ResourceGroupName = "contact-$groupSuffix"
    $existingGroup = Get-AzResourceGroup | Where-Object ResourceGroupName -EQ $ResourceGroupName
    if (-not $existingGroup) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $location | Out-Null
    }
} elseif ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    throw 'ResourceGroupName is required for resource-group deployment modes.'
}
$group = Get-AzResourceGroup -Name $ResourceGroupName
if ($group.Location -ne $location) {
    throw "Existing resource group is in '$($group.Location)', not approved region '$location'. No resources were moved or deleted."
}
$suffix = Get-MhhStableHash (@($SubscriptionId, $ResourceGroupName) + $identityParts) -Length 12
$template = Join-Path $labRoot 'infra\main.bicep'
$result = New-AzResourceGroupDeployment `
    -Name "contact-$suffix" `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $template `
    -TemplateParameterObject @{
        resourceSuffix = $suffix
        participantObjectIds = @($AllowedEntraUserIds | Sort-Object -Unique)
    }
if ($result.ProvisioningState -ne 'Succeeded') {
    throw "Contact center foundation deployment did not succeed: $($result.ProvisioningState)"
}

# ARM returns output names in camelCase and Outputs is case-sensitive; a PowerShell hashtable is not.
$outputs = @{}
foreach ($key in $result.Outputs.Keys) {
    $outputs[$key] = [string]$result.Outputs[$key].Value
}

# Publish the mock CRM (Azure Functions Flex Consumption): the app, its Functions entry point and each pack's
# profile and CRM seed data. Basic auth is disabled, so the zip goes to Kudu with an Entra token (requires
# Contributor or Website Contributor on the app). No remote build: the app uses only the standard library.
$package = Join-Path ([IO.Path]::GetTempPath()) ("crm-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $package | Out-Null
    foreach ($file in 'app.py', 'function_app.py', 'host.json', 'requirements.txt') {
        Copy-Item (Join-Path $labRoot "crm\$file") $package
    }
    foreach ($pack in Get-ChildItem (Join-Path $labRoot 'data\packs') -Directory) {
        $target = New-Item -ItemType Directory -Path (Join-Path $package "packs\$($pack.Name)")
        Copy-Item (Join-Path $pack.FullName 'pack.json'), (Join-Path $pack.FullName 'crm.json') $target
    }
    $zip = "$package.zip"
    Compress-Archive -Path (Join-Path $package '*') -DestinationPath $zip -Force
    $token = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/'
    $plainToken = if ($token.Token -is [securestring]) { [Net.NetworkCredential]::new('', $token.Token).Password } else { $token.Token }
    # No build step: the CRM uses only the standard library, and the Flex Python worker provides azure.functions.
    $scm = "https://$($outputs['CrmWebAppName']).scm.azurewebsites.net/api/publish?RemoteBuild=false"
    $published = $false
    for ($attempt = 1; $attempt -le 5 -and -not $published; $attempt++) {
        try {
            Invoke-WebRequest -Method Post -Uri $scm -InFile $zip -ContentType 'application/zip' -TimeoutSec 600 `
                -Headers @{ Authorization = "Bearer $plainToken" } -UseBasicParsing | Out-Null
            $published = $true
        } catch {
            if ($attempt -eq 5) { throw "Could not publish the CRM web app: $_" }
            Write-Warning "CRM publish attempt $attempt failed, retrying in 30 seconds: $_"
            Start-Sleep -Seconds 30
        }
    }
} finally {
    Remove-Item -Recurse -Force $package, "$package.zip" -ErrorAction SilentlyContinue
}

$healthy = $false
for ($check = 0; $check -lt 24 -and -not $healthy; $check++) {
    try {
        $health = Invoke-RestMethod -Uri "$($outputs['CrmUrl'])/health" -TimeoutSec 30
        $healthy = $health.status -eq 'ok' -and $health.packs.Count -eq 5
    } catch {
        $healthy = $false
    }
    if (-not $healthy) { Start-Sleep -Seconds 10 }
}
if (-not $healthy) {
    throw "The CRM web app did not become healthy at $($outputs['CrmUrl'])/health."
}

@{ HackboxCredential = @{ name = 'ResourceGroupName'; value = $ResourceGroupName; note = 'Your lab resource group' } }
@{ HackboxCredential = @{ name = 'EffectiveLocation'; value = $location; note = 'Azure region of your lab resources' } }
foreach ($name in @('FoundryProjectEndpoint', 'FoundryAccountName', 'ModelDeploymentName', 'EmbeddingDeploymentName', 'AnalysisModelDeploymentName', 'StorageAccountName', 'SearchServiceName', 'SearchEndpoint', 'CrmUrl', 'ApplicationInsightsName')) {
    if ([string]::IsNullOrWhiteSpace($outputs[$name])) {
        throw "Required template output missing: $name"
    }
    @{ HackboxCredential = @{ name = $name; value = $outputs[$name]; note = 'Lab resource name or endpoint; not a secret' } }
}
