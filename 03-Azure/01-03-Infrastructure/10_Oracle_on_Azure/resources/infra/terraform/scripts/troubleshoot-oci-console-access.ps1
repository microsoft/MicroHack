# Troubleshoot OCI Console Access Issues
# This script helps diagnose authorization failures when accessing OCI Console

param(
    [string]$TenancyId = "ocid1.tenancy.oc1..aaaaaaaarkr3tvxxmzwueaz3dazimmlsoqk2nc6j77vg33jinbnaupdnokxa",
    [string]$GroupName = "mh-odaa-user-grp",
    [string]$GroupId = "ocid1.group.oc1..aaaaaaaa5rwo34zlumtegqq7jraavoca5nmoadn6s5vxkagmpe2coyawqwoa",
    [string]$CompartmentId = "ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OCI Console Access Troubleshooting" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Error: Authorization failed or requested resource not found" -ForegroundColor Red
Write-Host "Page: Autonomous AI Databases" -ForegroundColor Yellow
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ANALYSIS OF THE ISSUE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] COMPARTMENT ACCESS ISSUE" -ForegroundColor Yellow
Write-Host ""
Write-Host "The error typically occurs when:" -ForegroundColor White
Write-Host "  - User is trying to access a compartment they don't have permissions for" -ForegroundColor Gray
Write-Host "  - User is accessing via federation but landing in wrong compartment" -ForegroundColor Gray
Write-Host "  - OCI Console is cached with old compartment selection" -ForegroundColor Gray
Write-Host ""

Write-Host "[2] CURRENT IAM POLICY REVIEW" -ForegroundColor Yellow
Write-Host ""
Write-Host "Your group has these permissions:" -ForegroundColor White
Write-Host "  - manage autonomous-database-family in tenancy" -ForegroundColor Green
Write-Host "  - manage database-family in tenancy" -ForegroundColor Green
Write-Host "  - manage virtual-network-family in tenancy" -ForegroundColor Green
Write-Host "  - read all-resources in tenancy" -ForegroundColor Green
Write-Host ""
Write-Host "These permissions should be SUFFICIENT for accessing ADB." -ForegroundColor Green
Write-Host ""

Write-Host "[3] POTENTIAL ROOT CAUSES" -ForegroundColor Yellow
Write-Host ""
Write-Host "A. Federated User Session Issues:" -ForegroundColor Cyan
Write-Host "   - Session not fully initialized after federation login" -ForegroundColor Gray
Write-Host "   - Identity mapping delay between Entra ID and OCI" -ForegroundColor Gray
Write-Host "   - Browser cookies/cache containing stale session data" -ForegroundColor Gray
Write-Host ""
Write-Host "B. Compartment Navigation Issues:" -ForegroundColor Cyan
Write-Host "   - OCI Console defaulting to root compartment" -ForegroundColor Gray
Write-Host "   - Resources exist in different compartment than selected" -ForegroundColor Gray
Write-Host "   - Compartment OCID mismatch" -ForegroundColor Gray
Write-Host ""
Write-Host "C. Resource State Issues:" -ForegroundColor Cyan
Write-Host "   - Some resources in TERMINATED state" -ForegroundColor Gray
Write-Host "   - Console trying to load deleted/inaccessible resources" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOMMENDED SOLUTIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[SOLUTION 1] Clear Browser Cache and Re-login (MOST COMMON FIX)" -ForegroundColor Green
Write-Host ""
Write-Host "Steps:" -ForegroundColor White
Write-Host "  1. Sign out from OCI Console completely" -ForegroundColor Gray
Write-Host "  2. Clear browser cache and cookies" -ForegroundColor Gray
Write-Host "  3. Close all browser windows" -ForegroundColor Gray
Write-Host "  4. Open new incognito/private window" -ForegroundColor Gray
Write-Host "  5. Navigate to OCI Console: https://cloud.oracle.com" -ForegroundColor Gray
Write-Host "  6. Select region: eu-paris-1" -ForegroundColor Gray
Write-Host "  7. Click 'Sign in with Microsoft'" -ForegroundColor Gray
Write-Host "  8. Authenticate with Entra ID credentials" -ForegroundColor Gray
Write-Host "  9. Wait for full session initialization (10-15 seconds)" -ForegroundColor Gray
Write-Host " 10. Manually select correct compartment from dropdown" -ForegroundColor Gray
Write-Host ""

Write-Host "[SOLUTION 2] Verify Compartment Selection" -ForegroundColor Green
Write-Host ""
Write-Host "Steps:" -ForegroundColor White
Write-Host "  1. After login, check compartment selector (top left)" -ForegroundColor Gray
Write-Host "  2. Ensure you're NOT in root compartment" -ForegroundColor Gray
Write-Host "  3. Navigate to correct compartment:" -ForegroundColor Gray
Write-Host "     Compartment: ociodaashared" -ForegroundColor Cyan
Write-Host "     OCID: $CompartmentId" -ForegroundColor Cyan
Write-Host "  4. Then navigate to: Databases > Autonomous Database" -ForegroundColor Gray
Write-Host ""

Write-Host "[SOLUTION 3] Use Direct Navigation URL" -ForegroundColor Green
Write-Host ""
Write-Host "Navigate directly to Autonomous Databases in your compartment:" -ForegroundColor White
Write-Host ""
Write-Host "https://cloud.oracle.com/db/adb/databases?region=eu-paris-1&compartmentId=$CompartmentId" -ForegroundColor Cyan
Write-Host ""

Write-Host "[SOLUTION 4] Check Federation Identity Mapping" -ForegroundColor Green
Write-Host ""
Write-Host "Verify your federated user is properly mapped:" -ForegroundColor White
Write-Host "  1. In OCI Console, go to: Identity & Security > Federation" -ForegroundColor Gray
Write-Host "  2. Verify the identity provider is active" -ForegroundColor Gray
Write-Host "  3. Check group mappings between Entra ID and OCI" -ForegroundColor Gray
Write-Host "  4. Confirm your user appears in the mh-odaa-user-grp" -ForegroundColor Gray
Write-Host ""

Write-Host "[SOLUTION 5] Wait for Session Synchronization" -ForegroundColor Green
Write-Host ""
Write-Host "For federated users, initial login may take time:" -ForegroundColor White
Write-Host "  - Wait 2-3 minutes after first login" -ForegroundColor Gray
Write-Host "  - Do not click rapidly or navigate immediately" -ForegroundColor Gray
Write-Host "  - Let OCI fully synchronize your identity and permissions" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "After applying solutions, verify access:" -ForegroundColor White
Write-Host ""
Write-Host "1. Check you can see the navigation menu" -ForegroundColor Gray
Write-Host "2. Verify compartment selector shows correct compartment" -ForegroundColor Gray
Write-Host "3. Navigate to: Databases > Autonomous Database" -ForegroundColor Gray
Write-Host "4. You should see the 'user00' database (AVAILABLE)" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ADDITIONAL DIAGNOSTICS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking current resources..." -ForegroundColor Cyan
Write-Host ""

$adbList = oci db autonomous-database list --compartment-id $CompartmentId --all 2>$null | ConvertFrom-Json

if ($adbList) {
    Write-Host "[OK] Found Autonomous Databases in compartment:" -ForegroundColor Green
    $adbList.data | Where-Object { $_.'lifecycle-state' -ne 'TERMINATED' } | ForEach-Object {
        Write-Host "  - $($_.'display-name') [$($_.'lifecycle-state')]" -ForegroundColor White
    }
} else {
    Write-Host "[WARNING] Could not retrieve Autonomous Databases via CLI" -ForegroundColor Yellow
}
Write-Host ""

$groupUsers = oci iam group list-users --group-id $GroupId --all 2>$null | ConvertFrom-Json

if ($groupUsers) {
    Write-Host "[OK] Users in group '$GroupName':" -ForegroundColor Green
    $groupUsers.data | Where-Object { $_.'lifecycle-state' -eq 'ACTIVE' } | ForEach-Object {
        Write-Host "  - $($_.name)" -ForegroundColor White
    }
} else {
    Write-Host "[WARNING] Could not retrieve group members via CLI" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IF ISSUE PERSISTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If the error continues after trying all solutions:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Contact Oracle Support with this information:" -ForegroundColor White
Write-Host "   - OPC Request ID: csidf607a99642698936f58cff8e9b72/..." -ForegroundColor Gray
Write-Host "   - Tenancy: $TenancyId" -ForegroundColor Gray
Write-Host "   - User: <your-user>@cptazure.org" -ForegroundColor Gray
Write-Host "   - Issue: Federated user cannot access ADB console page" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Check Oracle Cloud Status:" -ForegroundColor White
Write-Host "   https://ocistatus.oraclecloud.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Verify no recent policy changes in Entra ID" -ForegroundColor White
Write-Host "   that might affect federation" -ForegroundColor Gray
Write-Host ""
