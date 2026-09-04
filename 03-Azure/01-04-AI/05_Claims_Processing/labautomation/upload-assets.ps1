# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$StorageAccountName = "",

    [string]$ClaimsContainerName = "claims-data",

    [string]$PoliciesContainerName = "policies"
)

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$claimsDataRoot = Join-Path $scriptPath "data/claims"
$policiesDataRoot = Join-Path $scriptPath "data/policies"

if (-not (Test-Path -Path $claimsDataRoot -PathType Container)) {
    throw "Claim data folder not found at $claimsDataRoot"
}
if (-not (Test-Path -Path $policiesDataRoot -PathType Container)) {
    throw "Policy data folder not found at $policiesDataRoot"
}

$claimFiles = @(Get-ChildItem -Path $claimsDataRoot -Recurse -File)
$policyFiles = @(Get-ChildItem -Path $policiesDataRoot -File -Filter '*.md')
if ($claimFiles.Count -eq 0) {
    throw "No claim data files found at $claimsDataRoot"
}
if ($policyFiles.Count -eq 0) {
    throw "No policy documents found at $policiesDataRoot"
}

$currentContext = Get-AzContext
if (-not $currentContext -or -not $currentContext.Subscription -or $currentContext.Subscription.Id -ne $SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}

if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $storageAccounts = @(Get-AzStorageAccount -ResourceGroupName $ResourceGroupName)
    if ($storageAccounts.Count -ne 1) {
        throw "Expected one storage account in resource group '$ResourceGroupName', found $($storageAccounts.Count). Pass -StorageAccountName explicitly."
    }
    $StorageAccountName = $storageAccounts[0].StorageAccountName
}

$storageAccountKey = (Get-AzStorageAccountKey `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName)[0].Value
$storageContext = New-AzStorageContext `
    -StorageAccountName $StorageAccountName `
    -StorageAccountKey $storageAccountKey

Write-Host "Uploading $($claimFiles.Count) claim data file(s) to '$ClaimsContainerName'..." -ForegroundColor Yellow
$expectedClaimBlobs = @()
foreach ($file in $claimFiles) {
    $blobName = $file.FullName.Substring($claimsDataRoot.Length + 1) -replace '\\', '/'
    Set-AzStorageBlobContent `
        -Context $storageContext `
        -Container $ClaimsContainerName `
        -Blob $blobName `
        -File $file.FullName `
        -Force | Out-Null
    $expectedClaimBlobs += $blobName
    Write-Host "  - Uploaded $blobName" -ForegroundColor Green
}

Write-Host "Uploading $($policyFiles.Count) policy document(s) to '$PoliciesContainerName'..." -ForegroundColor Yellow
$expectedPolicyBlobs = @()
foreach ($file in $policyFiles) {
    Set-AzStorageBlobContent `
        -Context $storageContext `
        -Container $PoliciesContainerName `
        -Blob $file.Name `
        -File $file.FullName `
        -Force | Out-Null
    $expectedPolicyBlobs += $file.Name
    Write-Host "  - Uploaded $($file.Name)" -ForegroundColor Green
}

$actualClaimBlobs = @(
    Get-AzStorageBlob -Context $storageContext -Container $ClaimsContainerName |
    ForEach-Object { $_.Name }
)
$actualPolicyBlobs = @(
    Get-AzStorageBlob -Context $storageContext -Container $PoliciesContainerName |
    ForEach-Object { $_.Name }
)
$missingClaimBlobs = @($expectedClaimBlobs | Where-Object { $_ -notin $actualClaimBlobs })
$missingPolicyBlobs = @($expectedPolicyBlobs | Where-Object { $_ -notin $actualPolicyBlobs })

if ($missingClaimBlobs.Count -gt 0 -or $missingPolicyBlobs.Count -gt 0) {
    throw "Upload verification failed. Missing claim blobs: $($missingClaimBlobs.Count); missing policy blobs: $($missingPolicyBlobs.Count)."
}

Write-Host "Asset upload complete and verified." -ForegroundColor Green
Write-Host "  Storage account: $StorageAccountName"
Write-Host "  Claim assets verified: $($expectedClaimBlobs.Count)"
Write-Host "  Policy assets verified: $($expectedPolicyBlobs.Count)"
