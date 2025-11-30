<#
.SYNOPSIS
    Reset MFA authentication methods for workshop users to prepare for new attendees.

.DESCRIPTION
    This script removes all MFA authentication methods (except password) from workshop users,
    allowing new attendees to set up their own MFA on first login.
    
    Required permissions for the executing identity:
    - UserAuthenticationMethod.ReadWrite.All (Application permission)
    - Or run as a user with Authentication Administrator or Privileged Authentication Administrator role

.PARAMETER UserPrefix
    The prefix for user accounts (e.g., "user" for user00, user01, etc.)

.PARAMETER Domain
    The domain suffix for user accounts (e.g., "cptazure.org")

.PARAMETER UserCount
    Number of users to reset (e.g., 25 for user00-user24)

.PARAMETER IdentityFile
    Path to user_credentials.json to get user list (alternative to UserPrefix/UserCount)

.EXAMPLE
    .\reset-user-mfa.ps1 -UserPrefix "user" -Domain "cptazure.org" -UserCount 25

.EXAMPLE
    .\reset-user-mfa.ps1 -IdentityFile "..\identity\user_credentials.json"
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Manual")]
    [string]$UserPrefix = "user",
    
    [Parameter(ParameterSetName = "Manual")]
    [string]$Domain = "cptazure.org",
    
    [Parameter(ParameterSetName = "Manual")]
    [int]$UserCount = 25,
    
    [Parameter(ParameterSetName = "FromFile")]
    [string]$IdentityFile
)

$ErrorActionPreference = "Stop"

# Build user list
$users = @()
if ($IdentityFile) {
    if (-not (Test-Path $IdentityFile)) {
        Write-Error "Identity file not found: $IdentityFile"
        exit 1
    }
    $identity = Get-Content $IdentityFile | ConvertFrom-Json
    foreach ($userKey in $identity.users.PSObject.Properties.Name) {
        $users += $identity.users.$userKey.user_principal_name
    }
} else {
    for ($i = 0; $i -lt $UserCount; $i++) {
        $userNum = $i.ToString("D2")
        $users += "$UserPrefix$userNum@$Domain"
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MFA Reset Script for Workshop Users" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Users to process: $($users.Count)" -ForegroundColor Yellow
Write-Host ""

# Check Azure CLI login
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
} catch {
    Write-Error "Please login to Azure CLI first: az login"
    exit 1
}

$successCount = 0
$errorCount = 0
$noMfaCount = 0

foreach ($upn in $users) {
    Write-Host "`nProcessing: $upn" -ForegroundColor Cyan
    
    try {
        # Get all authentication methods for the user
        $methodsJson = az rest --method GET `
            --uri "https://graph.microsoft.com/v1.0/users/$upn/authentication/methods" `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: Failed to get auth methods - $methodsJson" -ForegroundColor Red
            $errorCount++
            continue
        }
        
        $methods = $methodsJson | ConvertFrom-Json
        $mfaMethods = $methods.value | Where-Object { 
            $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' 
        }
        
        if ($mfaMethods.Count -eq 0) {
            Write-Host "  No MFA methods registered (only password)" -ForegroundColor Gray
            $noMfaCount++
            continue
        }
        
        Write-Host "  Found $($mfaMethods.Count) MFA method(s) to remove:" -ForegroundColor Yellow
        
        foreach ($method in $mfaMethods) {
            $methodType = $method.'@odata.type' -replace '#microsoft.graph.', ''
            $methodId = $method.id
            
            Write-Host "    - $methodType (ID: $methodId)" -ForegroundColor Gray
            
            # Determine the correct endpoint for deletion based on method type
            $deleteUri = switch ($methodType) {
                "phoneAuthenticationMethod" { 
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/phoneMethods/$methodId"
                }
                "microsoftAuthenticatorAuthenticationMethod" { 
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/microsoftAuthenticatorMethods/$methodId"
                }
                "softwareOathAuthenticationMethod" {
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/softwareOathMethods/$methodId"
                }
                "fido2AuthenticationMethod" {
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/fido2Methods/$methodId"
                }
                "windowsHelloForBusinessAuthenticationMethod" {
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/windowsHelloForBusinessMethods/$methodId"
                }
                "emailAuthenticationMethod" {
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/emailMethods/$methodId"
                }
                "temporaryAccessPassAuthenticationMethod" {
                    "https://graph.microsoft.com/v1.0/users/$upn/authentication/temporaryAccessPassMethods/$methodId"
                }
                default { $null }
            }
            
            if ($deleteUri) {
                try {
                    $deleteResult = az rest --method DELETE --uri $deleteUri 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "      Removed successfully" -ForegroundColor Green
                    } else {
                        Write-Host "      Failed to remove: $deleteResult" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "      Failed to remove: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "      Unknown method type, skipping" -ForegroundColor Yellow
            }
        }
        
        $successCount++
        
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MFA Reset Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successfully processed: $successCount" -ForegroundColor Green
Write-Host "No MFA registered:      $noMfaCount" -ForegroundColor Gray
Write-Host "Errors:                 $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($errorCount -gt 0) {
    Write-Host "Some users had errors. Common causes:" -ForegroundColor Yellow
    Write-Host "  - Service principal needs UserAuthenticationMethod.ReadWrite.All permission" -ForegroundColor Yellow
    Write-Host "  - Or run this script as a user with Authentication Administrator role" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To add the permission to your service principal:" -ForegroundColor Cyan
    Write-Host "  1. Go to Azure Portal > Entra ID > App registrations" -ForegroundColor White
    Write-Host "  2. Find your app and go to API permissions" -ForegroundColor White
    Write-Host "  3. Add: Microsoft Graph > Application > UserAuthenticationMethod.ReadWrite.All" -ForegroundColor White
    Write-Host "  4. Grant admin consent" -ForegroundColor White
}
