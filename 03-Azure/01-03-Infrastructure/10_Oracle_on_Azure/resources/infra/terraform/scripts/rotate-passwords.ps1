<#
.SYNOPSIS
    Rotate passwords for all MicroHack users to revoke access after an event.

.DESCRIPTION
    This script automates the password rotation workflow by:
    1. Updating the password_rotation_trigger in terraform.tfvars
    2. Running terraform apply to regenerate all passwords
    3. Outputting the new credentials (or confirming access is revoked)

    Use this script AFTER an event ends to immediately revoke participant access,
    or BEFORE an event to generate fresh credentials.

.PARAMETER TriggerValue
    The new value for password_rotation_trigger. 
    If not specified, generates one based on current date/time.

.PARAMETER Phase
    Either "start" (before event) or "end" (after event to revoke access).
    Default: "end"

.PARAMETER EventName
    Optional event name for the trigger value.
    Example: -EventName "workshop-dec" generates "workshop-dec-end-20251129"

.PARAMETER TfVarsPath
    Path to terraform.tfvars file. Default: current directory.

.PARAMETER AutoApprove
    Skip terraform apply confirmation prompt.

.PARAMETER SkipApply
    Only update tfvars file, don't run terraform apply.

.EXAMPLE
    # After event ends - revoke all access immediately
    .\rotate-passwords.ps1 -Phase end

.EXAMPLE
    # Before new event - generate fresh credentials
    .\rotate-passwords.ps1 -Phase start -EventName "december-workshop"

.EXAMPLE
    # Custom trigger value
    .\rotate-passwords.ps1 -TriggerValue "revoked-2025-11-29"

.EXAMPLE
    # Just update tfvars, apply manually later
    .\rotate-passwords.ps1 -Phase end -SkipApply

.NOTES
    This script modifies terraform.tfvars and runs terraform apply.
    The password changes take effect immediately in Azure AD.
#>

[CmdletBinding()]
param(
    [string]$TriggerValue,
    
    [ValidateSet('start', 'end')]
    [string]$Phase = 'end',
    
    [string]$EventName,
    
    [string]$TfVarsPath = ".",
    
    [switch]$AutoApprove,
    
    [switch]$SkipApply
)

$ErrorActionPreference = 'Stop'

# Resolve tfvars path
$tfvarsFile = Join-Path (Resolve-Path $TfVarsPath) "terraform.tfvars"
if (-not (Test-Path $tfvarsFile)) {
    # Try identity subfolder
    $tfvarsFile = Join-Path (Resolve-Path $TfVarsPath) "identity/terraform.tfvars"
}
if (-not (Test-Path $tfvarsFile)) {
    throw "terraform.tfvars not found in $TfVarsPath or $TfVarsPath/identity"
}

$tfvarsDir = Split-Path $tfvarsFile -Parent

# Generate trigger value if not provided
if (-not $TriggerValue) {
    $dateSuffix = Get-Date -Format "yyyyMMdd-HHmm"
    if ($EventName) {
        $TriggerValue = "$EventName-$Phase-$dateSuffix"
    } else {
        $TriggerValue = "$Phase-$dateSuffix"
    }
}

Write-Host "`n" -NoNewline
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           PASSWORD ROTATION - $(if ($Phase -eq 'end') { 'REVOKE ACCESS' } else { 'NEW CREDENTIALS' })             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Phase -eq 'end') {
    Write-Host "  ⚠️  This will REVOKE ACCESS for all current participants!" -ForegroundColor Yellow
    Write-Host "  All existing passwords will be invalidated immediately." -ForegroundColor Yellow
} else {
    Write-Host "  ✅ This will generate FRESH CREDENTIALS for a new event." -ForegroundColor Green
    Write-Host "  New user_credentials.json will be created." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Trigger value: " -NoNewline
Write-Host $TriggerValue -ForegroundColor Magenta
Write-Host "  Config file:   $tfvarsFile"
Write-Host ""

# Read current tfvars
$content = Get-Content $tfvarsFile -Raw

# Check if password_rotation_trigger exists
if ($content -match 'password_rotation_trigger\s*=\s*"([^"]*)"') {
    $oldValue = $Matches[1]
    Write-Host "  Current trigger: " -NoNewline
    Write-Host $oldValue -ForegroundColor DarkGray
    
    # Replace the value
    $newContent = $content -replace '(password_rotation_trigger\s*=\s*)"[^"]*"', "`$1`"$TriggerValue`""
} else {
    Write-Host "  Adding password_rotation_trigger to tfvars..." -ForegroundColor Yellow
    $newContent = $content + "`n`npassword_rotation_trigger = `"$TriggerValue`"`n"
}

# Write updated tfvars
$newContent | Set-Content $tfvarsFile -NoNewline
Write-Host ""
Write-Host "  ✓ Updated terraform.tfvars" -ForegroundColor Green

if ($SkipApply) {
    Write-Host ""
    Write-Host "  Skipping terraform apply (use -SkipApply:$false to apply)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To apply manually, run:" -ForegroundColor Cyan
    Write-Host "    cd $tfvarsDir" -ForegroundColor White
    Write-Host "    terraform apply" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Confirm before apply (unless AutoApprove)
if (-not $AutoApprove) {
    Write-Host ""
    $confirm = Read-Host "  Apply now? (yes/no)"
    if ($confirm -notmatch '^(y|yes)$') {
        Write-Host ""
        Write-Host "  Aborted. The tfvars file has been updated." -ForegroundColor Yellow
        Write-Host "  Run 'terraform apply' in $tfvarsDir to complete." -ForegroundColor Yellow
        exit 0
    }
}

# Run terraform apply
Write-Host ""
Write-Host "  Running terraform apply..." -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Push-Location $tfvarsDir
try {
    $applyArgs = @('apply')
    if ($AutoApprove) {
        $applyArgs += '-auto-approve'
    }
    
    & terraform @applyArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        if ($Phase -eq 'end') {
            Write-Host "  ✅ ACCESS REVOKED - All previous passwords are now invalid!" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Participants from the previous event can no longer log in." -ForegroundColor White
        } else {
            Write-Host "  ✅ NEW CREDENTIALS GENERATED!" -ForegroundColor Green
            Write-Host ""
            $credFile = Join-Path $tfvarsDir "user_credentials.json"
            if (Test-Path $credFile) {
                Write-Host "  Credentials saved to: $credFile" -ForegroundColor White
                Write-Host ""
                Write-Host "  Distribute this file to your new participants." -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host ""
        Write-Host "  ❌ Terraform apply failed!" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""
