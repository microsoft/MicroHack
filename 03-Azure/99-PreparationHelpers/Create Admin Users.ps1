
$numberOfUsers = 10

# Connect to Azure AD

# - PLEASE UPDATE
Connect-AzureAD -AccountId admin@.onmicrosoft.com

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

# - PLEASE UPDATE
$PasswordProfile.Password = ""
$PasswordProfile.EnforceChangePasswordPolicy = $false
$PasswordProfile.ForceChangePasswordNextLogin = $false

# - PLEASE UPDATE
$tenant = ".onmicrosoft.com"

#Create Groups
New-AzureADGroup -DisplayName "MH - Migrate - Modernize" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
New-AzureADGroup -DisplayName "MH - AVD" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
New-AzureADGroup -DisplayName "MH - Business Continuity - Disaster Recovery" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
New-AzureADGroup -DisplayName "MH - Azure Arc - Defender" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
New-AzureADGroup -DisplayName "MH - Advanced Monitoring" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
New-AzureADGroup -DisplayName "MH - Linux Migration" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"

# Create user accounts
for ($i = 1; $i -le $numberOfUsers; $i++) {
    $displayName = "Admin$i"
    $userPrincipalName = "admin$i@$tenant"

    $user = New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName
    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}
