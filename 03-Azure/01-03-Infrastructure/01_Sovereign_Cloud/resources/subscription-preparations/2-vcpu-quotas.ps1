<#
.SYNOPSIS
    Check and calculate vCPU quota requirements for the Sovereign Cloud MicroHack.

.DESCRIPTION
    This script checks current vCPU quota usage in a specified Azure region and calculates
    the required quotas for running the MicroHack lab based on the number of lab users.

    The shared Challenge 4/5/7 platform requires per participant:
    - 12 Standard DSv5 Family vCPUs
    - 4 Standard DCasv6 Family vCPUs
    - 16 Total Regional vCPUs

    The script can optionally submit quota increase requests using the Azure Quota REST API.

.PARAMETER Region
    Azure region for quota check (e.g., eastus, northeurope). If not provided, the script will prompt for selection.

.PARAMETER NumberOfLabUsers
    Number of lab participants hosted by each selected subscription

.PARAMETER ShowCurrentUsageOnly
    Only display current quota usage without calculating requirements

.PARAMETER SubmitQuotaRequests
    Automatically submit quota increase requests via REST API if needed

.PARAMETER ExportToJson
    Export results to a JSON file

.EXAMPLE
    .\2-vcpu-quotas.ps1
    Interactive mode - prompts for region and user count

.EXAMPLE
    .\2-vcpu-quotas.ps1 -Region "swedencentral" -NumberOfLabUsers 2 -SubmitQuotaRequests
    Check quotas for two participants in Sweden Central and submit increase requests if needed

.NOTES
    Author: MicroHack Team
    Date: January 2026

.LINK
    https://learn.microsoft.com/azure/quotas/per-vm-quota-requests
.LINK
    https://learn.microsoft.com/rest/api/quota/quota/create-or-update
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [int]$NumberOfLabUsers,

    [Parameter(Mandatory = $false)]
    [switch]$ShowCurrentUsageOnly,

    [Parameter(Mandatory = $false)]
    [switch]$SubmitQuotaRequests,

    [Parameter(Mandatory = $false)]
    [switch]$ExportToJson
)

# Ensure required modules are available
$requiredModules = @('Az.Compute', 'Az.Accounts')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "$module module is not installed. Please run: Install-Module -Name $module"
        exit 1
    }
}

# Import required modules
Import-Module Az.Compute, Az.Accounts -ErrorAction Stop

# Function to prompt for region if not provided
function Get-AzureRegion {
    if ([string]::IsNullOrWhiteSpace($Region)) {
        Write-Host "`n=== Select Azure Region ===" -ForegroundColor Cyan
        Write-Host "Recommended regions for Sovereign Cloud MicroHack:"
        Write-Host "  1. Sweden Central (swedencentral)"
        Write-Host "  2. Spain Central (spaincentral)"
        Write-Host "  3. Enter custom region"

        $choice = Read-Host "`nEnter your choice (1-3)"

        $script:Region = switch ($choice) {
            "1" { "swedencentral" }
            "2" { "spaincentral" }
            "3" { Read-Host "Enter Azure region (e.g., swedencentral, spaincentral)" }
            default {
                Write-Warning "Invalid choice. Defaulting to Sweden Central (swedencentral)."
                "swedencentral"
            }
        }
    }
    return $script:Region
}

# Function to prompt for number of lab users if not provided
function Get-LabUserCount {
    if ($NumberOfLabUsers -eq 0 -and -not $ShowCurrentUsageOnly) {
        do {
            $userInput = Read-Host "`nEnter the number of participants hosted by each selected subscription (1-60)"
            $script:NumberOfLabUsers = [int]$userInput
        } while ($NumberOfLabUsers -lt 1 -or $NumberOfLabUsers -gt 60)
    }
    return $script:NumberOfLabUsers
}

# Function to select subscriptions
function Select-AzureSubscriptions {
    Write-Host "`n=== Select Azure Subscription(s) ===" -ForegroundColor Cyan

    $subscriptions = Get-AzSubscription | Sort-Object Name

    if ($subscriptions.Count -eq 0) {
        Write-Error "No subscriptions found. Please ensure you're logged in with Connect-AzAccount."
        exit 1
    }

    Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        $sub = $subscriptions[$i]
        Write-Host ("  {0,2}. {1} ({2})" -f ($i + 1), $sub.Name, $sub.Id) -ForegroundColor Gray
    }

    Write-Host "`nOptions:" -ForegroundColor Cyan
    Write-Host "  - Enter a single number (e.g., 1)"
    Write-Host "  - Enter 'all' to select all subscriptions"
    Write-Host "  - Press Enter to use the current subscription only"

    $selection = Read-Host "`nYour selection"

    $selectedSubscriptions = @()

    if ([string]::IsNullOrWhiteSpace($selection)) {
        $currentContext = Get-AzContext
        $selectedSubscriptions = @($subscriptions | Where-Object { $_.Id -eq $currentContext.Subscription.Id })
        Write-Host "Using current subscription: $($currentContext.Subscription.Name)" -ForegroundColor Green
    }
    elseif ($selection.ToLower() -eq 'all') {
        $selectedSubscriptions = $subscriptions
        Write-Host "Selected all $($subscriptions.Count) subscriptions" -ForegroundColor Green
    }
    else {
        $idx = [int]$selection - 1
        if ($idx -ge 0 -and $idx -lt $subscriptions.Count) {
            $selectedSubscriptions = @($subscriptions[$idx])
        } else {
            Write-Error "Invalid selection"
            exit 1
        }
    }

    return $selectedSubscriptions
}

# Function to register Microsoft.Quota resource provider
function Register-QuotaProvider {
    Write-Host "`nChecking Microsoft.Quota resource provider registration..." -ForegroundColor Cyan

    $provider = Get-AzResourceProvider -ProviderNamespace Microsoft.Quota | Where-Object { $_.RegistrationState -eq 'Registered' }

    if (-not $provider) {
        Write-Host "Microsoft.Quota resource provider is not registered. Registering now..." -ForegroundColor Yellow
        Register-AzResourceProvider -ProviderNamespace Microsoft.Quota | Out-Null
        Write-Host "Registration initiated. This may take a few minutes..." -ForegroundColor Yellow

        # Wait for registration
        $timeout = 120  # 2 minutes
        $elapsed = 0
        do {
            Start-Sleep -Seconds 5
            $elapsed += 5
            $provider = Get-AzResourceProvider -ProviderNamespace Microsoft.Quota
            $state = $provider.RegistrationState
            Write-Host "  Registration state: $state (elapsed: ${elapsed}s)" -ForegroundColor Gray
        } while ($state -ne 'Registered' -and $elapsed -lt $timeout)

        if ($state -eq 'Registered') {
            Write-Host "Microsoft.Quota resource provider registered successfully." -ForegroundColor Green
        } else {
            Write-Warning "Microsoft.Quota resource provider registration is taking longer than expected. Please check manually."
        }
    } else {
        Write-Host "Microsoft.Quota resource provider is already registered." -ForegroundColor Green
    }
}

function Get-ResponseHeaderValue {
    param(
        [System.Net.Http.Headers.HttpResponseHeaders]$Headers,
        [string]$Name
    )

    $header = $Headers | Where-Object { $_.Key -ieq $Name } | Select-Object -First 1
    return @($header.Value)[0]
}

# Wait for an asynchronous quota request to reach a terminal state
function Wait-QuotaRequestStatus {
    param(
        [string]$OperationStatusUrl,
        [int]$RetryAfterSeconds = 5,
        [int]$MaxAttempts = 20
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Start-Sleep -Seconds $RetryAfterSeconds
        $response = Invoke-AzRestMethod -Uri $OperationStatusUrl -Method GET

        if ($response.StatusCode -eq 202) {
            Write-Host "  Request is still processing (attempt $attempt of $MaxAttempts)..." -ForegroundColor Gray
            continue
        }

        if ($response.StatusCode -ne 200) {
            Write-Host "  Status check failed with HTTP $($response.StatusCode)." -ForegroundColor Red
            return $false
        }

        $content = $response.Content | ConvertFrom-Json
        $state = $content.properties.provisioningState

        if ($state -eq 'Succeeded') {
            Write-Host "  Quota request completed successfully." -ForegroundColor Green
            return $true
        }

        if ($state -in @('InProgress', 'Accepted', 'Running')) {
            Write-Host "  Request is still processing (attempt $attempt of $MaxAttempts)..." -ForegroundColor Gray
            continue
        }

        $error = if($content.properties.error) { $content.properties.error } else { $content.error }
        $errorCode = if($error.code) { $error.code } else { $content.properties.errorCode }
        $message = $error.message
        if (-not $message) {
            $message = $content.properties.message
        }
        if (-not $message) {
            $message = $content.properties.errorMessage
        }
        if (-not $message) {
            $message = "Quota request ended without error details."
        }

        Write-Host "  Quota request ended in state '$state'." -ForegroundColor Red
        if ($errorCode) {
            Write-Host "  Azure error: $errorCode - $message" -ForegroundColor Red
        } elseif ($message) {
            Write-Host "  Azure message: $message" -ForegroundColor Red
        }
        return $false
    }

    Write-Host "  Timed out waiting for the quota request to complete." -ForegroundColor Red
    Write-Host "  Check status at: $OperationStatusUrl" -ForegroundColor Gray
    return $false
}

# Function to submit quota increase request via REST API
function Submit-QuotaIncreaseRequest {
    param(
        [string]$SubscriptionId,
        [string]$Location,
        [string]$QuotaName,
        [int]$NewLimit
    )

    # API version for Quota REST API
    $apiVersion = "2023-02-01"

    # Construct the URI
    $scope = "subscriptions/$SubscriptionId/providers/Microsoft.Compute/locations/$Location"
    $uri = "/$scope/providers/Microsoft.Quota/quotas/${QuotaName}?api-version=$apiVersion"

    # Construct the request body
    $body = @{
        properties = @{
            name = @{
                value = $QuotaName
            }
            limit = @{
                limitObjectType = "LimitValue"
                value = $NewLimit
            }
        }
    } | ConvertTo-Json -Depth 10

    Write-Host "`nSubmitting quota increase request for $QuotaName to $NewLimit vCPUs..." -ForegroundColor Cyan
    Write-Verbose "URI: $uri"
    Write-Verbose "Body: $body"

    try {
        $response = Invoke-AzRestMethod -Path $uri -Method PUT -Payload $body

        if ($response.StatusCode -in @(200, 202)) {
            Write-Host "  Request submitted successfully! Status Code: $($response.StatusCode)" -ForegroundColor Green

            # Parse response content
            $content = $response.Content | ConvertFrom-Json

            if ($content.properties) {
                Write-Verbose "Quota details: $($content.properties | ConvertTo-Json -Depth 5)"
            }

            if ($response.StatusCode -eq 202) {
                $locationHeader = Get-ResponseHeaderValue -Headers $response.Headers -Name 'Location'
                if (-not $locationHeader) {
                    Write-Host "  Azure accepted the request but did not return a status URL." -ForegroundColor Red
                    return $false
                }

                $retryAfter = Get-ResponseHeaderValue -Headers $response.Headers -Name 'Retry-After'
                $retryAfterSeconds = if ($retryAfter -as [int]) { [int]$retryAfter } else { 5 }

                Write-Host "  Waiting for the asynchronous request to complete..." -ForegroundColor Yellow
                Write-Host "  $locationHeader" -ForegroundColor Gray
                return Wait-QuotaRequestStatus `
                    -OperationStatusUrl $locationHeader `
                    -RetryAfterSeconds $retryAfterSeconds
            }

            return $true
        } else {
            Write-Host "  Request failed with status code: $($response.StatusCode)" -ForegroundColor Red
            Write-Host "  Response: $($response.Content)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  Error submitting quota request: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Map display names to API resource names
$quotaNameMapping = @{
    "Total Regional vCPUs"                         = "cores"
    "Standard DSv5 Family vCPUs"                   = "StandardDSv5Family"
    "Standard DSv6 Family vCPUs"                   = "StandardDSv6Family"
    "Standard DASv5 Family vCPUs"                  = "StandardDASv5Family"
    "Standard DCasv6 Family vCPUs (Confidential)"  = "standardDCasv6Family"
    "Standard DCadsv6 Family vCPUs (Confidential)" = "standardDCadsv6Family"
    "Standard ESv5 Family vCPUs"                   = "StandardESv5Family"
}

# Check if user is logged in
try {
    $context = Get-AzContext
    if (-not $context) {
        $cliAccountJson = if (Get-Command az -ErrorAction SilentlyContinue) {
            az account show --output json 2>$null
        }

        if ($LASTEXITCODE -eq 0 -and $cliAccountJson) {
            $cliAccount = $cliAccountJson | ConvertFrom-Json
            $accessToken = az account get-access-token `
                --resource https://management.azure.com/ `
                --query accessToken `
                --output tsv

            if ($LASTEXITCODE -ne 0 -or -not $accessToken) {
                throw "Failed to acquire an Azure Resource Manager token from Azure CLI."
            }

            Write-Host "`nUsing current Azure CLI subscription: $($cliAccount.name)" -ForegroundColor Green
            Connect-AzAccount `
                -AccessToken $accessToken `
                -AccountId $cliAccount.user.name `
                -Tenant $cliAccount.tenantId `
                -Subscription $cliAccount.id `
                -SkipValidation `
                -Scope Process | Out-Null
        } else {
            Write-Host "`nNo Azure context found. Please login..." -ForegroundColor Yellow
            Connect-AzAccount | Out-Null
        }

        $context = Get-AzContext
    }
} catch {
    Write-Error "Failed to get Azure context. Please run Connect-AzAccount first."
    exit 1
}

# Get region
$Region = Get-AzureRegion
Write-Host "`nSelected Region: $Region" -ForegroundColor Green

# Select subscription(s)
$selectedSubscriptions = Select-AzureSubscriptions

# Process each subscription
foreach ($subscription in $selectedSubscriptions) {
    Write-Host "`n" + ("=" * 100) -ForegroundColor Cyan
    Write-Host "Processing Subscription: $($subscription.Name)" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan

    Set-AzContext -SubscriptionId $subscription.Id | Out-Null

    # Get current quota usage
    Write-Host "`nRetrieving current vCPU quota usage for region: $Region..." -ForegroundColor Cyan

    try {
        $quotaUsage = Get-AzVMUsage -Location $Region
    } catch {
        Write-Error "Failed to retrieve quota usage. Error: $($_.Exception.Message)"
        continue
    }

    # Define quota names relevant for Sovereign Cloud MicroHack
    $quotaNames = @{
        "cores"                    = "Total Regional vCPUs"
        "StandardDSv5Family"       = "Standard DSv5 Family vCPUs"
        "StandardDSv6Family"       = "Standard DSv6 Family vCPUs"
        "StandardDASv5Family"      = "Standard DASv5 Family vCPUs"
        "standardDCasv6Family"     = "Standard DCasv6 Family vCPUs (Confidential)"
        "standardDCadsv6Family"    = "Standard DCadsv6 Family vCPUs (Confidential)"
        "StandardESv5Family"       = "Standard ESv5 Family vCPUs"
    }

    # Display current usage
    Write-Host "`n=== Current vCPU Quota Usage in $Region (Sovereign Cloud MicroHack SKUs) ===" -ForegroundColor Cyan
    Write-Host ("=" * 80)

    $currentQuotas = @{}

    foreach ($quota in $quotaUsage) {
        $quotaValue = $quota.Name.Value
        $quotaName = $quota.Name.LocalizedValue

        if ($quotaNames.Keys -contains $quotaValue) {
            $current = $quota.CurrentValue
            $limit = $quota.Limit
            $available = $limit - $current
            $percentUsed = if ($limit -gt 0) { [math]::Round(($current / $limit) * 100, 2) } else { 0 }

            Write-Host ("`n{0,-50} : {1,6} / {2,6} ({3,6}% used)" -f $quotaName, $current, $limit, $percentUsed)
            Write-Host ("  Available: {0,6} vCPUs" -f $available) -ForegroundColor $(if ($available -lt 20) { "Yellow" } else { "Green" })

            $currentQuotas[$quotaValue] = @{
                Name      = $quotaName
                Current   = $current
                Limit     = $limit
                Available = $available
            }
        }
    }

    Write-Host ("=" * 80)

    if ($ShowCurrentUsageOnly) {
        continue
    }

    # Get number of lab users
    $NumberOfLabUsers = Get-LabUserCount

    # Calculate requirements for the shared Challenge 4/5/7 participant platform.

    Write-Host "`n=== Lab Requirements Calculation ===" -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host "`nNumber of lab users: $NumberOfLabUsers" -ForegroundColor Green

    $requirements = @{
        "cores" = @{
            PerUser = 16
            Shared  = 0
            Name    = "Total Regional vCPUs"
        }
        "StandardDSv5Family" = @{
            PerUser = 12
            Shared  = 0
            Name    = "Standard DSv5 Family vCPUs"
        }
        "standardDCasv6Family" = @{
            PerUser = 4
            Shared  = 0
            Name    = "Standard DCasv6 Family vCPUs (Confidential)"
        }
    }

    Write-Host "`nRequired vCPUs per lab user + shared infrastructure:"
    foreach ($key in $requirements.Keys) {
        $req = $requirements[$key]
        $total = ($req.PerUser * $NumberOfLabUsers) + $req.Shared
        Write-Host ("  {0,-50} : {1,6} vCPUs" -f $req.Name, $total)
    }

    Write-Host "`n=== Quota Availability Analysis ===" -ForegroundColor Cyan
    Write-Host ("=" * 80)

    $quotaIncreaseNeeded = $false
    $quotaRequests = @()

    foreach ($key in $requirements.Keys) {
        $req = $requirements[$key]
        $totalNeeded = ($req.PerUser * $NumberOfLabUsers) + $req.Shared

        if ($currentQuotas.ContainsKey($key)) {
            $current = $currentQuotas[$key]
            $available = $current.Available

            Write-Host ("`n{0}" -f $req.Name) -ForegroundColor Yellow
            Write-Host ("  Current Limit    : {0,6} vCPUs" -f $current.Limit)
            Write-Host ("  Current Usage    : {0,6} vCPUs" -f $current.Current)
            Write-Host ("  Available        : {0,6} vCPUs" -f $available)
            Write-Host ("  Required for Lab : {0,6} vCPUs" -f $totalNeeded)

            if ($available -lt $totalNeeded) {
                $shortfall = $totalNeeded - $available
                $newLimit = $current.Current + $totalNeeded
                Write-Host ("  STATUS           : INSUFFICIENT") -ForegroundColor Red
                Write-Host ("  Shortfall        : {0,6} vCPUs" -f $shortfall) -ForegroundColor Red
                Write-Host ("  Recommended Limit: {0,6} vCPUs" -f $newLimit) -ForegroundColor Yellow

                $quotaIncreaseNeeded = $true
                $quotaRequests += [PSCustomObject]@{
                    QuotaName        = $req.Name
                    CurrentLimit     = $current.Limit
                    Required         = $totalNeeded
                    Shortfall        = $shortfall
                    RecommendedLimit = $newLimit
                }
            } else {
                Write-Host ("  STATUS           : SUFFICIENT") -ForegroundColor Green
            }
        }
    }

    Write-Host ("=" * 80)

    if ($quotaIncreaseNeeded) {
        Write-Host "`n=== ACTION REQUIRED: Quota Increase Needed ===" -ForegroundColor Red
        Write-Host ("=" * 80)

        Write-Host "`nThe following quotas need to be increased:" -ForegroundColor Yellow
        $quotaRequests | Format-Table -Property QuotaName, CurrentLimit, Required, Shortfall, RecommendedLimit -AutoSize

        # Check if user wants to submit quota requests via REST API
        if ($SubmitQuotaRequests) {
            Write-Host "`n=== Submitting Quota Requests via REST API (Automated) ===" -ForegroundColor Cyan
            Write-Host ("=" * 80)

            # Register Microsoft.Quota provider
            Register-QuotaProvider

            Write-Host "`nNote: This will submit quota increase requests using the Azure Quota REST API." -ForegroundColor Yellow
            Write-Host "The requests will be reviewed by Azure and typically approved within minutes for adjustable quotas." -ForegroundColor Yellow

            $confirmation = Read-Host "`nDo you want to proceed with submitting quota requests? (Y/N)"

            if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
                $successCount = 0
                $failCount = 0

                foreach ($req in $quotaRequests) {
                    $apiResourceName = $quotaNameMapping[$req.QuotaName]

                    if ($apiResourceName) {
                        $success = Submit-QuotaIncreaseRequest `
                            -SubscriptionId $context.Subscription.Id `
                            -Location $Region `
                            -QuotaName $apiResourceName `
                            -NewLimit $req.RecommendedLimit

                        if ($success) {
                            $successCount++
                        } else {
                            $failCount++
                        }

                        Start-Sleep -Seconds 2  # Brief pause between requests
                    } else {
                        Write-Warning "Could not map quota name: $($req.QuotaName)"
                        $failCount++
                    }
                }

                Write-Host "`n=== Quota Request Summary ===" -ForegroundColor Cyan
                Write-Host "Successfully submitted: $successCount requests" -ForegroundColor $(if ($successCount -gt 0) { "Green" } else { "Gray" })
                Write-Host "Failed: $failCount requests" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })

                if ($successCount -gt 0) {
                    Write-Host "`nQuota requests have been submitted. Check the Azure Portal for approval status." -ForegroundColor Green
                    Write-Host "You can also check status programmatically using the operation status URLs provided above." -ForegroundColor Gray
                }
            } else {
                Write-Host "`nQuota request submission cancelled." -ForegroundColor Yellow
            }

            Write-Host "`n"
        }

        Write-Host "`n=== Alternative Options for Quota Increase ===" -ForegroundColor Cyan
        Write-Host ("=" * 80)

        if (-not $SubmitQuotaRequests) {
            Write-Host "`nOPTION 1: Automated PowerShell Submission" -ForegroundColor Cyan
            Write-Host "Rerun this script with the -SubmitQuotaRequests parameter to automatically submit quota increase requests:"
            Write-Host ""
            Write-Host "  .\2-vcpu-quotas.ps1 -Region '$Region' -NumberOfLabUsers $NumberOfLabUsers -SubmitQuotaRequests" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This will use the Azure Quota REST API via Invoke-AzRestMethod to submit all required quota requests."
            Write-Host ""
        }

        Write-Host "`nOPTION $(if ($SubmitQuotaRequests) { '1' } else { '2' }): Azure Portal (Manual UI)" -ForegroundColor Cyan
        Write-Host "  1. Sign in to the Azure Portal: https://portal.azure.com"
        Write-Host "  2. Search for 'Quotas' and select it"
        Write-Host "  3. Select 'Compute' from the Overview page"
        Write-Host "  4. Filter by Region: $Region"
        Write-Host "  5. Select the quotas you need to increase:"

        foreach ($req in $quotaRequests) {
            Write-Host ("     - {0}: Request {1} vCPUs" -f $req.QuotaName, $req.RecommendedLimit) -ForegroundColor Yellow
        }

        Write-Host "  6. Click 'New Quota Request'"
        Write-Host "  7. Enter the new limits and submit"
        Write-Host "`n  Note: If the quota is 'Adjustable', it will be reviewed and typically approved within minutes."
        Write-Host "        If the quota is 'Non-Adjustable', you'll need to create a support request."

        Write-Host "`nDocumentation:" -ForegroundColor Cyan
        Write-Host "  - VM-family vCPU quotas : https://learn.microsoft.com/azure/quotas/per-vm-quota-requests"
        Write-Host "  - Regional vCPU quotas  : https://learn.microsoft.com/azure/quotas/regional-quota-requests"
        Write-Host "  - Quota REST API        : https://learn.microsoft.com/rest/api/quota/quota/create-or-update"
        Write-Host "  - Invoke-AzRestMethod   : https://learn.microsoft.com/powershell/azure/manage-azure-resources-invoke-azrestmethod"
    } else {
        Write-Host "`n=== SUCCESS: Current Quotas Are Sufficient ===" -ForegroundColor Green
        Write-Host ("=" * 80)
        Write-Host "`nYour current quotas are sufficient to run the Sovereign Cloud MicroHack with $NumberOfLabUsers users." -ForegroundColor Green
    }
}

Write-Host "`n"
