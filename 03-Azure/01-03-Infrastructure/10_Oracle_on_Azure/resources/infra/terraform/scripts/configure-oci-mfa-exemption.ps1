# Configure OCI MFA Exemption for Federated Entra ID Users
# This script provides guidance on configuring OCI to exempt federated users from MFA

param(
    [string]$TenancyId = "ocid1.tenancy.oc1..aaaaaaaarkr3tvxxmzwueaz3dazimmlsoqk2nc6j77vg33jinbnaupdnokxa",
    [string]$GroupName = "mh-odaa-user-grp",
    [string]$GroupId = "ocid1.group.oc1..aaaaaaaa5rwo34zlumtegqq7jraavoca5nmoadn6s5vxkagmpe2coyawqwoa"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OCI MFA Exemption Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify group exists
Write-Host "Verifying federated group exists in OCI..." -ForegroundColor Cyan
$group = oci iam group get --group-id $GroupId 2>$null | ConvertFrom-Json

if ($group) {
    Write-Host "[OK] Found group: $($group.data.name)" -ForegroundColor Green
    Write-Host "     OCID: $($group.data.id)" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Group not found" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check authentication policy
Write-Host "Checking tenancy authentication policy..." -ForegroundColor Cyan
$authPolicy = oci iam authentication-policy get --compartment-id $TenancyId | ConvertFrom-Json
Write-Host "[OK] Password policy minimum length: $($authPolicy.data.'password-policy'.'minimum-password-length')" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IMPORTANT INFORMATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Federated users from Entra ID:" -ForegroundColor Yellow
Write-Host "  - Authenticate through Entra ID FIRST" -ForegroundColor White
Write-Host "  - MFA is enforced by Entra ID Conditional Access" -ForegroundColor White
Write-Host "  - After auth, SAML token is passed to OCI" -ForegroundColor White
Write-Host "  - OCI trusts the SAML assertion" -ForegroundColor White
Write-Host "  - Federated users bypass OCI MFA by design" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOMMENDED ACTIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[Option 1] No Action Required (RECOMMENDED)" -ForegroundColor Green
Write-Host "  Federated users are already exempt from OCI MFA" -ForegroundColor Gray
Write-Host "  They authenticate through Entra ID with MFA" -ForegroundColor Gray
Write-Host ""

Write-Host "[Option 2] Create Explicit Exemption Policy via OCI Console" -ForegroundColor Yellow
Write-Host "  Only needed if you have BOTH local and federated users" -ForegroundColor Gray
Write-Host "  AND you want to document the exemption explicitly" -ForegroundColor Gray
Write-Host ""
Write-Host "  Steps:" -ForegroundColor White
Write-Host "    1. Log into OCI Console" -ForegroundColor Gray
Write-Host "    2. Navigate to: Identity and Security" -ForegroundColor Gray
Write-Host "    3. Click: Policies" -ForegroundColor Gray
Write-Host "    4. Click: Create Policy" -ForegroundColor Gray
Write-Host "    5. Enable 'Show manual editor'" -ForegroundColor Gray
Write-Host "    6. Add this statement:" -ForegroundColor Gray
Write-Host ""
Write-Host "       Exempt group id $GroupId from mfa-requirement where request.user.type = 'FEDERATED'" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TESTING FEDERATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To verify federation is working:" -ForegroundColor White
Write-Host "  1. Open OCI Console in incognito/private window" -ForegroundColor Gray
Write-Host "  2. Click 'Sign in with Microsoft'" -ForegroundColor Gray
Write-Host "  3. Authenticate with Entra ID (MFA enforced by Entra)" -ForegroundColor Gray
Write-Host "  4. After Entra auth, redirected to OCI Console" -ForegroundColor Gray
Write-Host "  5. You should NOT be prompted for MFA again in OCI" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Federated Group: $GroupName" -ForegroundColor White
Write-Host "Group OCID: $GroupId" -ForegroundColor Gray
Write-Host "Tenancy: $TenancyId" -ForegroundColor Gray
Write-Host ""
Write-Host "Federated users authenticate through Entra ID and should not be" -ForegroundColor Green
Write-Host "prompted for MFA in OCI after successful Entra ID authentication." -ForegroundColor Green
Write-Host ""
