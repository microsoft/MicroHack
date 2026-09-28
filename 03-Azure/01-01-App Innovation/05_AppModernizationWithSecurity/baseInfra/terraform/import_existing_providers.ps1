# Import existing registered Azure resource providers into Terraform state
# This script reads the provider list from locals.tf and imports already-registered providers

param(
    [Parameter(Mandatory=$true)]
    [string]$VarFile,
    [string]$WorkspaceName = $null
)

Write-Host "=== Azure Resource Provider Import Script ===" -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "modules/resource_provider_registration/locals.tf")) {
    Write-Error "locals.tf not found. Please run this script from the terraform directory."
    exit 1
}

# Check if tfvars file exists
if (-not (Test-Path $VarFile)) {
    Write-Error "Tfvars file not found: $VarFile"
    exit 1
}

# Parse subscription_id from tfvars file
Write-Host "Reading tfvars file: $VarFile" -ForegroundColor Yellow
$tfvarsContent = Get-Content $VarFile -Raw
if ($tfvarsContent -match 'subscription_id\s*=\s*"([^"]+)"') {
    $SubscriptionId = $matches[1]
    Write-Host "Found subscription_id: $SubscriptionId" -ForegroundColor Green
} else {
    Write-Error "Could not find subscription_id in $VarFile"
    exit 1
}

# Switch to workspace if specified
if ($WorkspaceName) {
    Write-Host "Switching to workspace: $WorkspaceName" -ForegroundColor Yellow
    terraform workspace select $WorkspaceName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to switch to workspace $WorkspaceName"
        exit 1
    }
}

# Extract provider list from locals.tf
Write-Host "`nExtracting provider list from locals.tf..." -ForegroundColor Yellow
$localsContent = Get-Content "modules/resource_provider_registration/locals.tf" -Raw

# Parse the resource_providers list
$providersMatch = [regex]::Match($localsContent, 'resource_providers\s*=\s*\[(.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $providersMatch.Success) {
    Write-Error "Could not parse resource_providers list from locals.tf"
    exit 1
}

$providersList = $providersMatch.Groups[1].Value
$providers = [regex]::Matches($providersList, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

Write-Host "Found $($providers.Count) providers in locals.tf" -ForegroundColor Green

# Get currently registered providers from Azure
Write-Host "`nChecking which providers are already registered in subscription..." -ForegroundColor Yellow
$registeredProvidersJson = az provider list --subscription $SubscriptionId --query "[?registrationState=='Registered'].namespace" -o json
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to list resource providers for subscription $SubscriptionId. Run 'az login' and confirm you have access to that subscription."
    exit 1
}
$registeredProviders = $registeredProvidersJson | ConvertFrom-Json

Write-Host "Found $($registeredProviders.Count) registered providers in Azure" -ForegroundColor Green

# Find providers that are both in locals.tf and already registered
$toImport = $providers | Where-Object { $registeredProviders -contains $_ }

Write-Host "`nProviders to import: $($toImport.Count)" -ForegroundColor Cyan

if ($toImport.Count -eq 0) {
    Write-Host "No providers need to be imported. Either they're not registered yet or already in state." -ForegroundColor Yellow
    exit 0
}

# Show list of providers to import
Write-Host "`nProviders that will be imported:" -ForegroundColor Yellow
$toImport | ForEach-Object { Write-Host "  - $_" }

# Import each provider
Write-Host "`nStarting import process..." -ForegroundColor Cyan
$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($provider in $toImport) {
    Write-Host "`nImporting $provider..." -ForegroundColor Yellow
    
    # Terraform resource address
    $resourceAddress = "module.resource_providers[0].azurerm_resource_provider_registration.providers[`"$provider`"]"
    
    # Azure resource ID
    $resourceId = "/subscriptions/$SubscriptionId/providers/$provider"
    
    # Try to import with var-file
    terraform import -var-file="$VarFile" $resourceAddress $resourceId 
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Successfully imported $provider" -ForegroundColor Green
        $successCount++
    } elseif ($LASTEXITCODE -eq 1) {
        # Check if it's already in state
        $stateCheck = terraform state show $resourceAddress 2>&1
        if ($stateCheck -match "No instance found") {
            Write-Host "  ✗ Failed to import $provider" -ForegroundColor Red
            $failCount++
        } else {
            Write-Host "  ~ Already in state: $provider" -ForegroundColor Gray
            $skippedCount++
        }
    }
}

# Summary
Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan
Write-Host "Successfully imported: $successCount" -ForegroundColor Green
Write-Host "Already in state: $skippedCount" -ForegroundColor Gray
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

if ($successCount -gt 0) {
    Write-Host "`nRun 'terraform plan' to verify the import was successful." -ForegroundColor Yellow
}
