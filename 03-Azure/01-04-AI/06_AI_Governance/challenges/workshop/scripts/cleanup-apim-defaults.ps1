[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$apimApiVersion = '2024-05-01'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message"
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-AzdValue {
    param(
        [string]$Name,
        [switch]$Required
    )

    $value = (& azd env get-value $Name 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $value = $null
    }

    $value = ConvertTo-TrimmedCliOutput $value
    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        throw "Required azd environment value is missing: $Name. Run azd up first, then rerun this script."
    }

    return $value
}

function ConvertTo-TrimmedCliOutput {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]($Value | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text.Trim()
}

function Remove-DefaultProduct {
    param([string]$ProductId)

    & az apim product show `
        --resource-group $script:ResourceGroup `
        --service-name $script:ApimName `
        --product-id $ProductId `
        --only-show-errors `
        -o none *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Step "Deleting APIM default product: $ProductId"
        & az apim product delete `
            --resource-group $script:ResourceGroup `
            --service-name $script:ApimName `
            --product-id $ProductId `
            --delete-subscriptions true `
            --yes `
            --only-show-errors `
            -o none
    }
    else {
        Write-Host "Default product already absent: $ProductId"
    }
}

function Remove-DefaultSubscription {
    param([string]$SubscriptionName)

    $subscriptionUri = "/subscriptions/$script:SubscriptionId/resourceGroups/$script:ResourceGroup/providers/Microsoft.ApiManagement/service/$script:ApimName/subscriptions/${SubscriptionName}?api-version=$apimApiVersion"

    & az rest `
        --method delete `
        --uri $subscriptionUri `
        --headers 'If-Match=*' `
        --only-show-errors `
        -o none *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deleted default subscription: $SubscriptionName"
    }
    else {
        Write-Host "Default subscription already absent or could not be deleted: $SubscriptionName"
    }
}

Assert-Command az
Assert-Command azd

& az account show *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI is not logged in. Run az login, then rerun this script.'
}

$script:ResourceGroup = Get-AzdValue -Name 'AZURE_RESOURCE_GROUP' -Required
$script:SubscriptionId = Get-AzdValue -Name 'AZURE_SUBSCRIPTION_ID'
$script:ApimName = Get-AzdValue -Name 'APIM_NAME'

if (-not [string]::IsNullOrWhiteSpace($script:SubscriptionId)) {
    & az account set --subscription $script:SubscriptionId
}
else {
    $script:SubscriptionId = ConvertTo-TrimmedCliOutput (& az account show --query id -o tsv)
}

if ([string]::IsNullOrWhiteSpace($script:ApimName)) {
    $script:ApimName = ConvertTo-TrimmedCliOutput (& az apim list --resource-group $script:ResourceGroup --query '[0].name' -o tsv 2>$null)
}

if ([string]::IsNullOrWhiteSpace($script:ApimName)) {
    throw 'Could not resolve the APIM service name from azd or the resource group.'
}

$skuName = ConvertTo-TrimmedCliOutput (& az apim show --resource-group $script:ResourceGroup --name $script:ApimName --query 'sku.name' -o tsv)

if ($skuName -ne 'Developer') {
    Write-Host "APIM SKU is $skuName. Cleanup only runs for Developer SKU, so no action was taken."
    exit 0
}

Write-Step "Developer SKU detected for APIM service $script:ApimName"

Remove-DefaultProduct -ProductId 'starter'
Remove-DefaultProduct -ProductId 'unlimited'

Write-Step 'Checking for remaining default APIM subscriptions'
$subscriptionListUri = "/subscriptions/$script:SubscriptionId/resourceGroups/$script:ResourceGroup/providers/Microsoft.ApiManagement/service/$script:ApimName/subscriptions?api-version=$apimApiVersion"
$remainingSubscriptions = (& az rest `
    --method get `
    --uri $subscriptionListUri `
    --query "value[?name != 'master'].name" `
    -o tsv 2>$null)

if ($LASTEXITCODE -ne 0) {
    $remainingSubscriptions = $null
}

$remainingSubscriptionNames = @($remainingSubscriptions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToString().Trim() })
if ($remainingSubscriptionNames.Count -eq 0) {
    Write-Host 'No remaining subscriptions were found after preserving master.'
    exit 0
}

foreach ($subscriptionName in $remainingSubscriptionNames) {
    Remove-DefaultSubscription -SubscriptionName $subscriptionName
}

Write-Host "`nAPIM default cleanup completed."