#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deploys the lab resources scoped to a subscription or resource group, then
seeds Cosmos DB and Blob Storage with the sample factory-operations data.
.DESCRIPTION
Provides a controlled deployment flow for lab environments, optionally limited to a resource group and specific Entra user IDs.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription, resourcegroup, or resourcegroup-with-subscriptionowner.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
For resource group deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions, ordered by preference.
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

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dataRoot = Join-Path $scriptPath "data"

# Keep seed assets inside the folder packaged by Hack Console.
# Partition key paths must match main.bicep's cosmosContainers.
$dataMappings = [ordered]@{
    "Machines"           = @{ File = "machines.json"; PartitionKeyPath = "/type" }
    "Thresholds"         = @{ File = "thresholds.json"; PartitionKeyPath = "/machineType" }
    "Telemetry"          = @{ File = "telemetry-samples.json"; PartitionKeyPath = "/machineId" }
    "KnowledgeBase"      = @{ File = "knowledge-base.json"; PartitionKeyPath = "/machineType" }
    "PartsInventory"     = @{ File = "parts-inventory.json"; PartitionKeyPath = "/category" }
    "Technicians"        = @{ File = "technicians.json"; PartitionKeyPath = "/department" }
    "WorkOrders"         = @{ File = "work-orders.json"; PartitionKeyPath = "/status" }
    "MaintenanceHistory" = @{ File = "maintenance-history.json"; PartitionKeyPath = "/machineId" }
    "MaintenanceWindows" = @{ File = "maintenance-windows.json"; PartitionKeyPath = "/isAvailable" }
    "Suppliers"          = @{ File = "suppliers.json"; PartitionKeyPath = "/category" }
}

foreach ($mapping in $dataMappings.Values) {
    $dataFile = Join-Path $dataRoot $mapping.File
    if (-not (Test-Path -LiteralPath $dataFile -PathType Leaf)) {
        throw "Required seed data file not found: '$dataFile'. Include the data folder when uploading labautomation to Hack Console."
    }
}
$kbWikiFolder = Join-Path $dataRoot "kb-wiki"
if (-not (Test-Path -LiteralPath $kbWikiFolder -PathType Container)) {
    throw "Required knowledge base folder not found: '$kbWikiFolder'. Include the data folder when uploading labautomation to Hack Console."
}
if (@(Get-ChildItem -LiteralPath $kbWikiFolder -Filter "*.md" -File).Count -eq 0) {
    throw "No knowledge base markdown files found in '$kbWikiFolder'."
}

if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral"
}

if($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStablehash $AllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"
    Write-Host "Deploying lab resources at the subscription level in subscription $SubscriptionId..."
    if(-not (Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue)) {
        Write-Host "Creating resource group '$effectiveResourceGroup' in location '$effectiveLocation'..."
        New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Verbose
    } else {
        Write-Host "Resource group '$effectiveResourceGroup' already exists."
    }
} else {
    $effectiveResourceGroup = $ResourceGroupName
}

if($AllowedEntraUserIds.Count -eq 0) {
    throw "At least one AllowedEntraUserIds value is required to assign lab access."
}

$resourceSuffix = Get-MhhStablehash $AllowedEntraUserIds -Length 12
$storageAccountName = "stpdm$resourceSuffix"
$cosmosAccountName = "cosmos-pdm-$resourceSuffix"
$foundryAccountName = "aipdm$resourceSuffix"
$foundryProjectName = "predictive-maintenance"
$apimName = "apim-pdm-$resourceSuffix"

@{"HackboxCredential" = @{ name = "ResourceGroupName"; value = $effectiveResourceGroup; note = "The name of the resource group where lab resources are deployed" }}
@{"HackboxCredential" = @{ name = "StorageAccountName"; value = $storageAccountName; note = "The name of the Azure Storage account (machine-wiki blob container)" }}
@{"HackboxCredential" = @{ name = "CosmosAccountName"; value = $cosmosAccountName; note = "The name of the Azure Cosmos DB account (FactoryOpsDB database)" }}
@{"HackboxCredential" = @{ name = "FoundryAccountName"; value = $foundryAccountName; note = "The name of the Microsoft Foundry account" }}
@{"HackboxCredential" = @{ name = "FoundryProjectName"; value = $foundryProjectName; note = "The name of the Microsoft Foundry project" }}
@{"HackboxCredential" = @{ name = "ApiManagementName"; value = $apimName; note = "The name of the API Management instance (Machine API / Maintenance API)" }}
@{"HackboxCredential" = @{ name = "EffectiveLocation"; value = $effectiveLocation; note = "The effective Azure region for the lab deployment" }}

$template = Join-Path $scriptPath "main.bicep"
$templateParameters = @{
    location = $effectiveLocation
    resourceSuffix = $resourceSuffix
    userObjectId = $AllowedEntraUserIds[0]
}

$deployment = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations $PreferredLocation `
    -ResourceGroupName $effectiveResourceGroup `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -Tag @{ CostControl = "Ignore"; SecurityControl = "Ignore" } `
    -TemplateFile $template `
    -TemplateParameterObject $templateParameters

@{"HackboxCredential" = @{ name = "Region"; value = $deployment.LocationUsed; note = "The Azure region the lab deployment succeeded in" }}

# =============================================================================
# Post-deployment data seeding.
# Runs once per participant, immediately after their resources are created, so
# they never have to run a manual seeding step. Uses only PowerShell + az CLI
# (both available in the provisioning runner) -- no bash, no Python.
# =============================================================================

# $deployment.Outputs is already a flattened "name -> value" hashtable (see
# Invoke-MhhDeploymentWithRegionFallback's documented return value).
$outputs = $deployment.Outputs

$cosmosEndpoint = $outputs["cosmosDbEndpoint"]
$cosmosDatabaseName = $outputs["cosmosDbDatabaseName"]
$storageAccount = $outputs["storageAccountName"]
$machineWikiContainer = $outputs["machineWikiContainerName"]

Write-Host "Seeding Cosmos DB container documents into '$cosmosAccountName / $cosmosDatabaseName'..."

$cosmosKey = az cosmosdb keys list --name $cosmosAccountName --resource-group $effectiveResourceGroup --query primaryMasterKey -o tsv
if([string]::IsNullOrEmpty($cosmosKey)) {
    throw "Could not retrieve the Cosmos DB primary master key for '$cosmosAccountName'."
}
$cosmosKeyBytes = [Convert]::FromBase64String($cosmosKey)

function Invoke-CosmosDocumentUpsert {
    param(
        [string]$Endpoint,
        [byte[]]$KeyBytes,
        [string]$Database,
        [string]$Collection,
        [string]$PartitionKeyPath,
        [object]$Document
    )

    $verb = "post"
    $resourceType = "docs"
    $resourceLink = "dbs/$Database/colls/$Collection"
    $date = [DateTime]::UtcNow.ToString("r")
    $stringToSign = "$verb`n$resourceType`n$resourceLink`n$($date.ToLowerInvariant())`n`n"

    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $KeyBytes
    $signatureBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signatureBytes)
    $authHeader = [System.Uri]::EscapeDataString("type=master&ver=1.0&sig=$signature")

    $uri = "$Endpoint$resourceLink/docs"
    $body = $Document | ConvertTo-Json -Depth 20 -Compress

    # The Cosmos DB Gateway REST API requires the partition key value(s) to be
    # supplied explicitly via x-ms-documentdb-partitionkey, even on create -
    # it is not inferred from the request body. Single-level partition key
    # paths only (matches this hack's containers, e.g. "/type" -> .type).
    $partitionKeyPropertyName = $PartitionKeyPath.TrimStart('/')
    $partitionKeyValue = $Document.$partitionKeyPropertyName
    $partitionKeyHeader = ConvertTo-Json -InputObject @($partitionKeyValue) -Compress

    Invoke-RestMethod -Uri $uri -Method Post `
        -Headers @{
            "Authorization"                              = $authHeader
            "x-ms-date"                                   = $date
            "x-ms-version"                                = "2018-12-31"
            "x-ms-documentdb-is-upsert"                   = "true"
            "x-ms-documentdb-partitionkey"                = $partitionKeyHeader
        } `
        -ContentType "application/json" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
}

foreach($container in $dataMappings.Keys) {
    $mapping = $dataMappings[$container]
    $dataFile = Join-Path $dataRoot $mapping.File

    $documents = Get-Content -Raw -LiteralPath $dataFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $count = 0
    foreach($document in $documents) {
        try {
            Invoke-CosmosDocumentUpsert -Endpoint $cosmosEndpoint -KeyBytes $cosmosKeyBytes `
                -Database $cosmosDatabaseName -Collection $container `
                -PartitionKeyPath $mapping.PartitionKeyPath -Document $document
            $count++
        } catch {
            throw "Failed to upsert document '$($document.id)' into '$container': $($_.Exception.Message)"
        }
    }
    Write-Host "Seeded $count document(s) into '$container'."
}

Write-Host "Uploading knowledge base wiki articles to '$storageAccount / $machineWikiContainer'..."

$storageKey = az storage account keys list --account-name $storageAccount --resource-group $effectiveResourceGroup --query "[0].value" -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($storageKey)) {
    throw "Could not retrieve the storage account key for '$storageAccount'."
}

# CLI progress is written to stderr and appears as child-job errors in Hack Console.
az storage blob upload-batch `
    --account-name $storageAccount `
    --account-key $storageKey `
    --destination $machineWikiContainer `
    --source $kbWikiFolder `
    --pattern "*.md" `
    --no-progress `
    --overwrite | Out-Null

if($LASTEXITCODE -ne 0) {
    throw "Failed to upload knowledge base wiki articles from '$kbWikiFolder' to '$storageAccount / $machineWikiContainer'."
} else {
    Write-Host "Knowledge base wiki articles uploaded successfully."
}

Write-Host "Lab deployment and data seeding complete for resource group '$effectiveResourceGroup'."
