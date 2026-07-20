# ===============================================================================
# Import AzureAD Group Members into Terraform State
# ===============================================================================
# This script imports existing Azure AD group members that were created but not
# properly recorded in the Terraform state due to provider inconsistency issues.
# ===============================================================================

$groupId = "5fbc2654-d343-401a-be86-08327fe66ec2"

# Array of member IDs that need to be imported
$memberIds = @(
    @{Index="1"; MemberId="4ea70970-70db-42c4-95b7-73f41ba24581"},
    @{Index="2"; MemberId="cbdd8d02-c46a-4ea0-a47e-f28008085dd0"},
    @{Index="3"; MemberId="58206206-8aa7-4129-9929-2fc265e3cbc5"},
    @{Index="4"; MemberId="3fe7f0ca-4973-4715-becc-fd54a4548f89"},
    @{Index="5"; MemberId="d63585dd-7b7d-4cb0-8669-92c5069e217d"},
    @{Index="6"; MemberId="745e8c8f-2f72-43d5-8d3d-d9f336170a4f"},
    @{Index="7"; MemberId="ab3a331d-125c-4a7c-8297-00acf1ef1fb4"},
    @{Index="8"; MemberId="0eb36f70-ef4a-4e09-885e-0ff020f98eb6"},
    @{Index="9"; MemberId="364a1222-403e-458e-af8c-45fa1a6da218"},
    @{Index="10"; MemberId="ad23fc68-2de0-4294-8ea9-fb44157082a6"},
    @{Index="11"; MemberId="89684302-ba16-4ae5-a92f-1ec1becd8fea"},
    @{Index="13"; MemberId="56dddc14-4c5b-45f6-bc4b-44b162aca280"},
    @{Index="14"; MemberId="8436121d-7155-46b7-8c58-8b5550e195a0"},
    @{Index="15"; MemberId="1ade0926-08a4-4f92-abda-48b17b690d19"},
    @{Index="16"; MemberId="c0f5b12e-abf0-4a40-98ac-41a6527d1676"},
    @{Index="17"; MemberId="ca867d56-e247-4374-b9d1-6dc18048d06e"},
    @{Index="18"; MemberId="f9014895-857d-4e05-a6ff-12058b2a1bad"},
    @{Index="19"; MemberId="27322a8d-0315-4de1-a72f-882840fdc8b6"}
)

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "Importing Azure AD Group Members into Terraform State" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($member in $memberIds) {
    $index = $member.Index
    $memberId = $member.MemberId
    $resourceId = "$groupId/member/$memberId"
    $terraformResource = "module.entra_id_users.azuread_group_member.aks_deployment_users[`"$index`"]"
    
    Write-Host "Importing member $index..." -NoNewline
    
    try {
        $output = terraform import $terraformResource $resourceId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " SUCCESS" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  Error: $output" -ForegroundColor Yellow
            $failCount++
        }
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $failCount++
    }
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "Import Summary" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "Successful imports: $successCount" -ForegroundColor Green
Write-Host "Failed imports:     $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All group members have been successfully imported!" -ForegroundColor Green
    Write-Host "You can now run 'terraform apply' to continue." -ForegroundColor Cyan
} else {
    Write-Host "Some imports failed. Please review the errors above." -ForegroundColor Yellow
}
