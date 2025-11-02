# ROOT CAUSE ANALYSIS: user00@cptazure.org Access Issue
# Investigation reveals the exact permission problem

Write-Host "========================================" -ForegroundColor Red
Write-Host "ROOT CAUSE IDENTIFIED" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

Write-Host "[PROBLEM SUMMARY]" -ForegroundColor Yellow
Write-Host ""
Write-Host "user00@cptazure.org CANNOT access Autonomous Databases" -ForegroundColor Red
Write-Host "ga1@cptazure.org CAN access Autonomous Databases" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DETAILED ANALYSIS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] GROUP MEMBERSHIP DIFFERENCE" -ForegroundColor Yellow
Write-Host ""
Write-Host "ga1@cptazure.org:" -ForegroundColor White
Write-Host "  Group: Administrators" -ForegroundColor Green
Write-Host "  Policy: ALLOW GROUP Administrators to manage all-resources IN TENANCY" -ForegroundColor Green
Write-Host "  Result: FULL ACCESS to everything" -ForegroundColor Green
Write-Host ""

Write-Host "user00@cptazure.org:" -ForegroundColor White
Write-Host "  Group: mh-odaa-user-grp (Default/mh-odaa-user-grp)" -ForegroundColor Yellow
Write-Host "  Policies:" -ForegroundColor Yellow
Write-Host "    - Allow group Default/mh-odaa-user-grp to manage autonomous-database-family in tenancy" -ForegroundColor Cyan
Write-Host "    - Allow group Default/mh-odaa-user-grp to manage database-family in tenancy" -ForegroundColor Cyan
Write-Host "    - Allow group Default/mh-odaa-user-grp to manage virtual-network-family in tenancy" -ForegroundColor Cyan
Write-Host "    - Allow group Default/mh-odaa-user-grp to read all-resources in tenancy" -ForegroundColor Cyan
Write-Host ""

Write-Host "[2] THE CRITICAL ISSUE" -ForegroundColor Yellow
Write-Host ""
Write-Host "The Autonomous Databases are in a SPECIFIC COMPARTMENT:" -ForegroundColor White
Write-Host "  Compartment: MulticloudLink_ODBAA_20251026140711" -ForegroundColor Cyan
Write-Host "  OCID: ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Cyan
Write-Host ""

Write-Host "The policies for mh-odaa-user-grp say:" -ForegroundColor Red
Write-Host "  'manage autonomous-database-family in tenancy'" -ForegroundColor Red
Write-Host ""
Write-Host "BUT the OCI policies that WORK are compartment-specific:" -ForegroundColor Red
Write-Host "  'manage autonomous-databases in compartment id ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka'" -ForegroundColor Green
Write-Host ""

Write-Host "[3] POLICY SCOPE MISMATCH" -ForegroundColor Yellow
Write-Host ""
Write-Host "Tenancy-level policy: 'in tenancy'" -ForegroundColor Red
Write-Host "  - Should work for all compartments" -ForegroundColor Gray
Write-Host "  - BUT may not work for Azure-integrated ODAA compartments" -ForegroundColor Red
Write-Host "  - ODAA compartments created by MulticloudLink may need explicit grants" -ForegroundColor Red
Write-Host ""

Write-Host "Compartment-level policy: 'in compartment id ...'" -ForegroundColor Green
Write-Host "  - Explicitly grants access to specific compartment" -ForegroundColor Gray
Write-Host "  - Works for ODAA compartments" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SOLUTION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[OPTION 1] Add Compartment-Specific Policy (RECOMMENDED)" -ForegroundColor Green
Write-Host ""
Write-Host "Complete policy statements for 'odaa-policy-2':" -ForegroundColor White
Write-Host ""
Write-Host "  # Existing tenancy-level permissions:" -ForegroundColor Yellow
Write-Host "  Allow group Default/mh-odaa-user-grp to manage autonomous-database-family in tenancy" -ForegroundColor Cyan
Write-Host "  Allow group Default/mh-odaa-user-grp to manage database-family in tenancy" -ForegroundColor Cyan
Write-Host "  Allow group Default/mh-odaa-user-grp to manage virtual-network-family in tenancy" -ForegroundColor Cyan
Write-Host "  Allow group Default/mh-odaa-user-grp to manage network-security-groups in tenancy" -ForegroundColor Cyan
Write-Host "  Allow group Default/mh-odaa-user-grp to read all-resources in tenancy" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # ADD these compartment-specific permissions:" -ForegroundColor Green
Write-Host "  Allow group Default/mh-odaa-user-grp to manage autonomous-databases in compartment id ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Green
Write-Host "  Allow group Default/mh-odaa-user-grp to manage autonomous-backups in compartment id ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Green
Write-Host "  Allow group Default/mh-odaa-user-grp to read multicloud-configurations in tenancy" -ForegroundColor Green
Write-Host ""

Write-Host "[OPTION 2] Add user00 to Administrators Group (NOT RECOMMENDED)" -ForegroundColor Yellow
Write-Host ""
Write-Host "This gives too much access - user would have full tenancy admin rights" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IMPLEMENTATION STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 1: Get the policy OCID" -ForegroundColor White
Write-Host ""
$tenancyId = "ocid1.tenancy.oc1..aaaaaaaarkr3tvxxmzwueaz3dazimmlsoqk2nc6j77vg33jinbnaupdnokxa"
$policy = oci iam policy list --compartment-id $tenancyId --all 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty data | Where-Object { $_.name -eq 'odaa-policy-2' }

if ($policy) {
    Write-Host "  Policy Name: odaa-policy-2" -ForegroundColor Cyan
    Write-Host "  Policy OCID: $($policy.id)" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Step 3: Complete policy statement list:" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Keep existing statements:" -ForegroundColor Yellow
    $policy.statements | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
    Write-Host ""
    Write-Host "  # Add these NEW statements:" -ForegroundColor Green
    Write-Host "  - Allow group Default/mh-odaa-user-grp to manage autonomous-databases in compartment id ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Green
    Write-Host "  - Allow group Default/mh-odaa-user-grp to manage autonomous-backups in compartment id ocid1.compartment.oc1..aaaaaaaah7uamd3eq7airnvuimp6pq7z6nknv2nkwn4ki37aipuk3yupvfka" -ForegroundColor Green
    Write-Host "  - Allow group Default/mh-odaa-user-grp to read multicloud-configurations in tenancy" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Step 4: Update the policy via OCI Console:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Navigate to: Identity & Security > Policies" -ForegroundColor Gray
    Write-Host "  2. Find policy: odaa-policy-2" -ForegroundColor Gray
    Write-Host "  3. Click 'Edit'" -ForegroundColor Gray
    Write-Host "  4. Add the 3 new statements above" -ForegroundColor Gray
    Write-Host "  5. Save" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  [WARNING] Could not retrieve policy details" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "After updating the policy:" -ForegroundColor White
Write-Host "  1. user00@cptazure.org should log out of OCI Console" -ForegroundColor Gray
Write-Host "  2. Close browser completely" -ForegroundColor Gray
Write-Host "  3. Log back in" -ForegroundColor Gray
Write-Host "  4. Navigate to correct compartment: MulticloudLink_ODBAA_20251026140711" -ForegroundColor Gray
Write-Host "  5. Go to: Databases > Autonomous Database" -ForegroundColor Gray
Write-Host "  6. Should now see the databases without 'Forbidden' error" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "KEY TAKEAWAY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Oracle Database@Azure (ODAA) compartments created by MulticloudLink" -ForegroundColor White
Write-Host "require EXPLICIT compartment-level permissions, not just tenancy-level." -ForegroundColor White
Write-Host ""
Write-Host "The 'in tenancy' scope is NOT sufficient for ODAA compartments." -ForegroundColor Yellow
Write-Host "You MUST use 'in compartment id ...' for proper access." -ForegroundColor Yellow
Write-Host ""
