# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

# Get the script directory.
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$effectiveAllowedEntraUserIds = @(
    $AllowedEntraUserIds |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim() } |
    Sort-Object -Unique
)

if ($effectiveAllowedEntraUserIds.Count -eq 0) {
    Write-Host "[ERROR] AllowedEntraUserIds must contain at least one participant Microsoft Entra object ID." -ForegroundColor Red
    Write-Host "The lab cannot be deployed without granting the participant the Foundry User role." -ForegroundColor Red
    exit 1
}

foreach ($entraUserId in $effectiveAllowedEntraUserIds) {
    $parsedEntraUserId = [guid]::Empty
    if (-not [guid]::TryParse($entraUserId, [ref]$parsedEntraUserId)) {
        Write-Host "[ERROR] AllowedEntraUserIds contains an invalid Microsoft Entra object ID: '$entraUserId'" -ForegroundColor Red
        exit 1
    }
}

function Publish-HackboxCredential {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Note
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    @{
        HackboxCredential = @{
            name = $Name
            value = $Value
            note = $Note
        }
    }
}

# Resolve effective location and enforce template constraint.
$effectiveLocation = if ($PreferredLocation.Count -gt 0) { $PreferredLocation[0] } else { "swedencentral" }
if ($effectiveLocation -ne "swedencentral") {
    Write-Host "[WARN] Requested location '$effectiveLocation' is not supported by this template. Using 'swedencentral'." -ForegroundColor Yellow
    $effectiveLocation = "swedencentral"
}

Write-Host "Claims Processing Hackathon - Lab Deployment" -ForegroundColor Cyan
Write-Host "DeploymentType: $DeploymentType" -ForegroundColor Yellow
Write-Host "Subscription ID: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Location: $effectiveLocation" -ForegroundColor Yellow
Write-Host "ResourceGroupName: $ResourceGroupName" -ForegroundColor Yellow
Write-Host ""

# Ensure we are in the correct subscription context.
$currentContext = Get-AzContext
if (-not $currentContext -or -not $currentContext.Subscription -or $currentContext.Subscription.Id -ne $SubscriptionId) {
    Write-Host "[WARN] Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}

# Ensure all resource providers required by the lab are registered.
$requiredResourceProviders = @(
    'Microsoft.ApiManagement'
    'Microsoft.DocumentDB'
    'Microsoft.Search'
    'Microsoft.AlertsManagement'
)

foreach ($providerNamespace in $requiredResourceProviders) {
    $provider = Get-AzResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop
    if ($provider.RegistrationState -eq 'Registered') {
        continue
    }

    Write-Host "Registering resource provider: $providerNamespace" -ForegroundColor Yellow
    try {
        Register-AzResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop | Out-Null

        $registrationAttempts = 0
        do {
            Start-Sleep -Seconds 2
            $provider = Get-AzResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop
            $registrationAttempts++
        } while ($provider.RegistrationState -ne 'Registered' -and $registrationAttempts -lt 30)

        if ($provider.RegistrationState -ne 'Registered') {
            throw "Registration did not complete within 60 seconds."
        }
    }
    catch {
        Write-Host "[ERROR] Could not register resource provider '$providerNamespace': $_" -ForegroundColor Red
        Write-Host "Ask a subscription Owner or Contributor with the Microsoft.Resources/subscriptions/providers/register/action permission to register it." -ForegroundColor Red
        exit 1
    }
}

# Determine effective resource group name.
$effectiveResourceGroup = $ResourceGroupName
if ($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStableHash $effectiveAllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"

    Write-Host "Creating resource group (subscription mode): $effectiveResourceGroup" -ForegroundColor Yellow
    New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Force | Out-Null
}

# Template file path.
$templateFile = Join-Path $scriptPath "azuredeploy.json"
if (-not (Test-Path $templateFile)) {
    Write-Host "[ERROR] Template file not found at $templateFile" -ForegroundColor Red
    exit 1
}

# Deploy resources.
Write-Host "Deploying infrastructure resources..." -ForegroundColor Yellow
try {
    $deploymentParameters = @{
        ResourceGroupName = $effectiveResourceGroup
        TemplateFile = $templateFile
        location = $effectiveLocation
        deployModelDeployments = $true
        allowedEntraUserIds = $effectiveAllowedEntraUserIds
        Verbose = $true
        ErrorAction = 'Stop'
    }

    $deployment = New-AzResourceGroupDeployment @deploymentParameters

    Write-Host "Deployment succeeded." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Deployment failed: $_" -ForegroundColor Red
    exit 1
}

# Confirm every participant received the Foundry data-plane role required by
# the agent SDK. Account scope is inherited by the project and covers the
# Microsoft.CognitiveServices/accounts/AIServices/agents actions.
$aiFoundryAccountName = $deployment.Outputs.aiFoundryHubName.Value
$aiFoundryAccountScope = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveResourceGroup/providers/Microsoft.CognitiveServices/accounts/$aiFoundryAccountName"
foreach ($entraUserId in $effectiveAllowedEntraUserIds) {
    $foundryUserAssignment = Get-AzRoleAssignment `
        -ObjectId $entraUserId `
        -RoleDefinitionName 'Foundry User' `
        -Scope $aiFoundryAccountScope `
        -ErrorAction SilentlyContinue

    if (-not $foundryUserAssignment) {
        Write-Host "Granting Foundry User to participant: $entraUserId" -ForegroundColor Yellow
        New-AzRoleAssignment `
            -ObjectId $entraUserId `
            -RoleDefinitionName 'Foundry User' `
            -Scope $aiFoundryAccountScope `
            -ErrorAction Stop | Out-Null
    }

    Write-Host "Verified Foundry User role for participant: $entraUserId" -ForegroundColor Green
}

Write-Host ""
Write-Host "Deployed Resources:" -ForegroundColor Cyan
$resources = Get-AzResource -ResourceGroupName $effectiveResourceGroup
foreach ($resource in $resources) {
    Write-Host "  - $($resource.ResourceType): $($resource.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Returning lab credentials to platform..." -ForegroundColor Yellow

Publish-HackboxCredential -Name "ResourceGroupName" -Value $effectiveResourceGroup -Note "Azure Resource Group containing all lab resources"
Publish-HackboxCredential -Name "DeploymentLocation" -Value $effectiveLocation -Note "Azure region where resources are deployed"
Publish-HackboxCredential -Name "AZURE_RESOURCE_GROUP" -Value $effectiveResourceGroup -Note "Resource group name for challenge scripts"

$storageAccounts = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.Storage/storageAccounts' }
$searchServices = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.Search/searchServices' }
$aiFoundry = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.CognitiveServices/accounts' -and $_.Name -like '*aifoundry*' }
$projectResources = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.CognitiveServices/accounts/projects' }

$storageAccountName = if ($storageAccounts) { $storageAccounts[0].Name } else { "" }
$searchServiceName = if ($searchServices) { $searchServices[0].Name } else { "" }
$aiFoundryName = if ($aiFoundry) { $aiFoundry[0].Name } else { "" }

$aiFoundryProjectName = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('aiFoundryProjectName')) {
    $deployment.Outputs.aiFoundryProjectName.Value
}
elseif ($projectResources) {
    ($projectResources[0].Name -split '/')[1]
}
else {
    ""
}

$searchIndexName = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('searchIndexName')) {
    $deployment.Outputs.searchIndexName.Value
}
else {
    "crash-statements"
}

$blobContainerName = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('blobContainerName')) {
    $deployment.Outputs.blobContainerName.Value
}
else {
    "claims-data"
}

$policiesContainerName = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('policiesContainerName')) {
    $deployment.Outputs.policiesContainerName.Value
}
else {
    "policies"
}

$storageAccountKey = ""
$storageConnectionString = ""
if ($storageAccountName) {
    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $effectiveResourceGroup -Name $storageAccountName)[0].Value
    $storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageAccountKey;EndpointSuffix=core.windows.net"
}

$searchAdminKey = ""
if ($searchServiceName) {
    try {
        $searchKeysPath = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveResourceGroup/providers/Microsoft.Search/searchServices/$searchServiceName/listAdminKeys?api-version=2023-11-01"
        $searchKeysResponse = Invoke-AzRestMethod -Method POST -Path $searchKeysPath
        $searchKeysJson = $searchKeysResponse.Content | ConvertFrom-Json
        $searchAdminKey = $searchKeysJson.primaryKey
    }
    catch {
        Write-Host "[WARN] Could not retrieve Search admin key: $_" -ForegroundColor Yellow
    }
}

$aiFoundryKey = ""
if ($aiFoundryName) {
    try {
        $foundryKeysPath = "/subscriptions/$SubscriptionId/resourceGroups/$effectiveResourceGroup/providers/Microsoft.CognitiveServices/accounts/$aiFoundryName/listKeys?api-version=2024-10-01"
        $foundryKeysResponse = Invoke-AzRestMethod -Method POST -Path $foundryKeysPath
        $foundryKeysJson = $foundryKeysResponse.Content | ConvertFrom-Json
        $aiFoundryKey = $foundryKeysJson.key1
    }
    catch {
        Write-Host "[WARN] Could not retrieve AI Foundry key: $_" -ForegroundColor Yellow
    }
}

$searchServiceEndpoint = if ($searchServiceName) { "https://$searchServiceName.search.windows.net" } else { "" }
$aiFoundryEndpoint = if ($aiFoundryName) { "https://$aiFoundryName.cognitiveservices.azure.com/" } else { "" }
$deployedProjectEndpoint = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('aiFoundryProjectEndpoint')) {
    $deployment.Outputs.aiFoundryProjectEndpoint.Value
}
else {
    ""
}
$aiFoundryProjectEndpoint = if ($deployedProjectEndpoint -like 'https://*.services.ai.azure.com/api/projects/*') {
    $deployedProjectEndpoint.TrimEnd('/')
}
elseif ($aiFoundryName -and $aiFoundryProjectName) {
    "https://$aiFoundryName.services.ai.azure.com/api/projects/$aiFoundryProjectName"
}
else {
    ""
}

Publish-HackboxCredential -Name "StorageAccountName" -Value $storageAccountName -Note "Storage account for claim data and policy documents"
Publish-HackboxCredential -Name "SearchServiceName" -Value $searchServiceName -Note "Azure AI Search service for Foundry IQ grounding"
Publish-HackboxCredential -Name "SearchIndexName" -Value $searchIndexName -Note "Azure AI Search index used for crash statement retrieval"
Publish-HackboxCredential -Name "ClaimsBlobContainerName" -Value $blobContainerName -Note "Blob container for claim images and derived artifacts"
Publish-HackboxCredential -Name "PoliciesBlobContainerName" -Value $policiesContainerName -Note "Blob container for policy markdown files"

Publish-HackboxCredential -Name "AZURE_STORAGE_ACCOUNT_NAME" -Value $storageAccountName -Note "Storage account name for .env"
Publish-HackboxCredential -Name "AZURE_STORAGE_ACCOUNT_KEY" -Value $storageAccountKey -Note "Storage account key for .env"
Publish-HackboxCredential -Name "AZURE_STORAGE_CONNECTION_STRING" -Value $storageConnectionString -Note "Storage connection string for challenge 3"
Publish-HackboxCredential -Name "AZURE_STORAGE_CONTAINER_NAME" -Value $blobContainerName -Note "Claims container name for .env"
Publish-HackboxCredential -Name "AZURE_POLICIES_CONTAINER_NAME" -Value $policiesContainerName -Note "Policies container name for challenge 3"

Publish-HackboxCredential -Name "SEARCH_SERVICE_NAME" -Value $searchServiceName -Note "Azure AI Search service name"
Publish-HackboxCredential -Name "SEARCH_SERVICE_ENDPOINT" -Value $searchServiceEndpoint -Note "Azure AI Search endpoint"
Publish-HackboxCredential -Name "SEARCH_ADMIN_KEY" -Value $searchAdminKey -Note "Azure AI Search admin key"
Publish-HackboxCredential -Name "FOUNDRY_IQ_SEARCH_ENDPOINT" -Value $searchServiceEndpoint -Note "Foundry IQ search endpoint"
Publish-HackboxCredential -Name "FOUNDRY_IQ_SEARCH_KEY" -Value $searchAdminKey -Note "Foundry IQ search key"
Publish-HackboxCredential -Name "FOUNDRY_IQ_SEARCH_INDEX_NAME" -Value $searchIndexName -Note "Foundry IQ search index name"

Publish-HackboxCredential -Name "AIFoundryName" -Value $aiFoundryName -Note "AI Foundry account for agents and models"
Publish-HackboxCredential -Name "AIFoundryProjectName" -Value $aiFoundryProjectName -Note "AI Foundry project name for agent workflow runs"

Publish-HackboxCredential -Name "AI_FOUNDRY_HUB_NAME" -Value $aiFoundryName -Note "AI Foundry hub/account name"
Publish-HackboxCredential -Name "AI_FOUNDRY_PROJECT_NAME" -Value $aiFoundryProjectName -Note "AI Foundry project name"
Publish-HackboxCredential -Name "AI_FOUNDRY_ENDPOINT" -Value $aiFoundryEndpoint -Note "AI Foundry cognitive endpoint"
Publish-HackboxCredential -Name "AI_FOUNDRY_KEY" -Value $aiFoundryKey -Note "AI Foundry key for model calls"
Publish-HackboxCredential -Name "AI_FOUNDRY_PROJECT_ENDPOINT" -Value $aiFoundryProjectEndpoint -Note "AI Foundry project endpoint for SDK"
Publish-HackboxCredential -Name "FOUNDRY_PROJECT_ENDPOINT" -Value $aiFoundryProjectEndpoint -Note "Foundry project endpoint for challenges 4-6"
Publish-HackboxCredential -Name "FOUNDRY_MODEL" -Value "gpt-5.4" -Note "Primary model deployment for challenges 4-6"
Publish-HackboxCredential -Name "FOUNDRY_QUARANTINE_MODEL" -Value "gpt-5.4" -Note "Quarantine model for challenge 5"
Publish-HackboxCredential -Name "MODEL_DEPLOYMENT_NAME" -Value "gpt-5.4" -Note "Model deployment name for challenges 2-3"

Publish-HackboxCredential -Name "MISTRAL_DOCUMENT_AI_DEPLOYMENT_NAME" -Value "mistral-document-ai-2512" -Note "Mistral OCR deployment name"
Publish-HackboxCredential -Name "MISTRAL_DOCUMENT_AI_ENDPOINT" -Value $aiFoundryEndpoint -Note "Mistral OCR endpoint"
Publish-HackboxCredential -Name "MISTRAL_DOCUMENT_AI_KEY" -Value $aiFoundryKey -Note "Mistral OCR key"
Publish-HackboxCredential -Name "MISTRAL_DOCUMENT_AI_API_VERSION" -Value "2024-05-01-preview" -Note "Mistral OCR API version used by scripts"

if ($storageAccounts) {
    Write-Host ""
    Write-Host "Uploading claim data assets to blob storage..." -ForegroundColor Yellow

    $storageAccountName = $storageAccounts[0].Name
    $uploadContainerName = if ($deployment.Outputs -and $deployment.Outputs.ContainsKey('blobContainerName')) {
        $deployment.Outputs.blobContainerName.Value
    }
    else {
        "claims-data"
    }

    $claimsDataRoot = Join-Path (Split-Path -Parent $scriptPath) "data\claims"

    if (Test-Path $claimsDataRoot) {
        try {
            $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

            $claimFiles = Get-ChildItem -Path $claimsDataRoot -Recurse -File
            foreach ($file in $claimFiles) {
                $blobName = $file.FullName.Substring($claimsDataRoot.Length + 1) -replace '\\', '/'
                Set-AzStorageBlobContent -Context $storageContext -Container $uploadContainerName -Blob $blobName -File $file.FullName -Force | Out-Null
                Write-Host "  - Uploaded $blobName" -ForegroundColor Green
            }

            Write-Host "Uploaded $($claimFiles.Count) claim data file(s) to container '$uploadContainerName'." -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Failed to upload claim data assets: $_" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[WARN] Claim data folder not found at $claimsDataRoot; skipping upload." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Uploading policy documents to blob storage..." -ForegroundColor Yellow

    $policiesDataRoot = Join-Path (Split-Path -Parent $scriptPath) "data\policies"

    if (Test-Path $policiesDataRoot) {
        try {
            if (-not $storageContext) {
                $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
            }

            $policyFiles = Get-ChildItem -Path $policiesDataRoot -File -Filter '*.md'
            foreach ($file in $policyFiles) {
                Set-AzStorageBlobContent -Context $storageContext -Container $policiesContainerName -Blob $file.Name -File $file.FullName -Force | Out-Null
                Write-Host "  - Uploaded $($file.Name)" -ForegroundColor Green
            }

            Write-Host "Uploaded $($policyFiles.Count) policy document(s) to container '$policiesContainerName'." -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Failed to upload policy documents: $_" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[WARN] Policy data folder not found at $policiesDataRoot; skipping upload." -ForegroundColor Yellow
    }
}

Write-Host "Lab deployment complete." -ForegroundColor Green
