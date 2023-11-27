
Import-Module AzureADPreview


# Connect to Azure AD

# - PLEASE UPDATE
Connect-AzureAD -AccountId admin@.onmicrosoft.com

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

# - PLEASE UPDATE
$PasswordProfile.Password = ""

$PasswordProfile.EnforceChangePasswordPolicy = $true
$PasswordProfile.ForceChangePasswordNextLogin = $true

# - PLEASE UPDATE
$tenant = ".onmicrosoft.com"


## MH - Migrate & Modernize" ##
$MHName = "MH - Migrate - Modernize"
# Create user accounts
for ($i = 1; $i -le 10; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}


## MH - MH - AVD" ##
$MHName = "MH - AVD"
# Create user accounts
for ($i = 11; $i -le 20; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}


## MH - MH - Business Continuity & Disaster Recovery" ##
$MHName = "MH - Business Continuity - Disaster Recovery"
# Create user accounts
for ($i = 21; $i -le 30; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}


## MH - MH - Azure Arc & Defender" ##
$MHName = "MH - Azure Arc - Defender"
# Create user accounts
for ($i = 31; $i -le 40; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}


## MH - MH - Advanced Monitoring" ##
$MHName = "MH - Advanced Monitoring"
# Create user accounts
for ($i = 41; $i -le 50 ; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}


## MH - MH - Linux Migration" ##
$MHName = "MH - Linux Migration"
# Create user accounts
for ($i = 51; $i -le  60 ; $i++) {
    $displayName = "MHUser$i"
    $userPrincipalName = "MHUser$i@$tenant"

    # Create user account
    New-AzureADUser -DisplayName $displayName -UserPrincipalName $userPrincipalName -PasswordProfile $PasswordProfile -AccountEnabled $true -MailNickName $displayName -ErrorAction SilentlyContinue
    $user = Get-AzureADUser -ObjectId $userPrincipalName

    # Add user to Azure AD group
    $group = Get-AzureADGroup -SearchString $MHName
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId -ErrorAction SilentlyContinue

    Write-Host "User account created: $($user.DisplayName) ($($user.UserPrincipalName))"
}



