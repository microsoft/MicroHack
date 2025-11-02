# Fix OCI Console Compartment Selection Issue
# This script provides the correct compartment information

Write-Host "========================================" -ForegroundColor Red
Write-Host "OCI CONSOLE ERROR ANALYSIS" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

Write-Host "ERROR DETAILS:" -ForegroundColor Yellow
Write-Host "  Message: Forbidden" -ForegroundColor White
Write-Host "  Current Compartment: 4aecf0e8-2fe2-4187-bc93-0356bd2..." -ForegroundColor Red
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ROOT CAUSE IDENTIFIED" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[CRITICAL] You are in the WRONG COMPARTMENT!" -ForegroundColor Red
Write-Host ""
Write-Host "The compartment ID '4aecf0e8-2fe2-4187-bc93-0356bd2...' is an" -ForegroundColor Yellow
Write-Host "AZURE SUBSCRIPTION ID, not an OCI compartment!" -ForegroundColor Yellow
Write-Host ""
Write-Host "This happens because:" -ForegroundColor White
Write-Host "  1. OCI Console shows Azure-related compartments due to ODAA integration" -ForegroundColor Gray
Write-Host "  2. You accidentally selected an Azure subscription compartment" -ForegroundColor Gray
Write-Host "  3. Your Autonomous Databases are in a different OCI compartment" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SOLUTION - CHANGE TO CORRECT COMPARTMENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "STEP 1: Click the Compartment Selector" -ForegroundColor Green
Write-Host "  - Located in the top left of OCI Console" -ForegroundColor Gray
Write-Host "  - Currently shows: '4aecf0e8-2fe2-4187-bc93-0356bd2...'" -ForegroundColor Gray
Write-Host ""

Write-Host "STEP 2: Select the CORRECT OCI Compartment" -ForegroundColor Green
Write-Host ""
Write-Host "  Compartment Name: MulticloudLink_ODBAA_20251026140711" -ForegroundColor Cyan
Write-Host "  Compartment OCID: ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Cyan
Write-Host ""
Write-Host "  How to find it:" -ForegroundColor White
Write-Host "    1. Click on compartment dropdown" -ForegroundColor Gray
Write-Host "    2. Look for compartment starting with 'MulticloudLink_ODBAA'" -ForegroundColor Gray
Write-Host "    3. Click to select it" -ForegroundColor Gray
Write-Host ""

Write-Host "STEP 3: Navigate to Autonomous Databases" -ForegroundColor Green
Write-Host "  - Menu: Databases > Autonomous Database" -ForegroundColor Gray
Write-Host "  - Or use direct link below" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DIRECT NAVIGATION LINK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use this URL to navigate directly to the correct compartment:" -ForegroundColor White
Write-Host ""

$correctCompartmentId = "ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka"
$directUrl = "https://cloud.oracle.com/db/adb/databases?region=eu-paris-1&compartmentId=$correctCompartmentId"

Write-Host $directUrl -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPARTMENT COMPARISON" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "WRONG Compartment (Azure Subscription - DON'T USE):" -ForegroundColor Red
Write-Host "  ID: 4aecf0e8-2fe2-4187-bc93-0356bd2..." -ForegroundColor Red
Write-Host "  Type: Azure Subscription ID" -ForegroundColor Red
Write-Host "  Status: No OCI resources here" -ForegroundColor Red
Write-Host ""

Write-Host "CORRECT Compartment (OCI - USE THIS):" -ForegroundColor Green
Write-Host "  Name: MulticloudLink_ODBAA_20251026140711" -ForegroundColor Green
Write-Host "  ID: ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Green
Write-Host "  Type: OCI Compartment" -ForegroundColor Green
Write-Host "  Status: Contains your Autonomous Databases" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WHY THIS HAPPENS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Oracle Database@Azure (ODAA) creates a hybrid environment:" -ForegroundColor White
Write-Host ""
Write-Host "  - OCI compartments contain the actual Oracle databases" -ForegroundColor Gray
Write-Host "  - Azure subscriptions are referenced but don't contain OCI resources" -ForegroundColor Gray
Write-Host "  - OCI Console shows BOTH in the compartment selector" -ForegroundColor Gray
Write-Host "  - You must select the OCI compartment, not Azure subscription" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "After switching to the correct compartment, you should see:" -ForegroundColor White
Write-Host ""

# Try to list databases
Write-Host "Checking for databases in correct compartment..." -ForegroundColor Cyan
$adbResult = oci db autonomous-database list --compartment-id $correctCompartmentId --all 2>$null | ConvertFrom-Json

if ($adbResult -and $adbResult.data) {
    $activeDBs = $adbResult.data | Where-Object { $_.'lifecycle-state' -eq 'AVAILABLE' }
    if ($activeDBs) {
        Write-Host "[SUCCESS] Found $($activeDBs.Count) AVAILABLE database(s):" -ForegroundColor Green
        foreach ($db in $activeDBs) {
            Write-Host "  - $($db.'display-name')" -ForegroundColor White
        }
    } else {
        Write-Host "[INFO] No AVAILABLE databases found" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARNING] Could not retrieve database list via CLI" -ForegroundColor Yellow
    Write-Host "  This is okay - use the OCI Console to verify" -ForegroundColor Gray
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "QUICK REFERENCE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Copy this compartment OCID to clipboard:" -ForegroundColor White
Write-Host ""
Write-Host "  $correctCompartmentId" -ForegroundColor Cyan
Write-Host ""
Write-Host "Paste it in the compartment OCID search box if needed." -ForegroundColor Gray
Write-Host ""
