#requires -Version 7

$RequiredModules = @(
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.SignIns',
    'ImportExcel'
)

foreach ($module in $RequiredModules) {
    Install-PSResource -Name $module -TrustRepository
}

Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","UserAuthenticationMethod.ReadWrite.All" -UseDeviceCode

Get-MgContext

# Lab users and group creation
$UserNamePrefix = "LabUser-"
$UserNamePrefix = "AdminLabUser-"
$Password = Read-Host -Prompt "Enter password"
$UPNSuffix = Read-Host -Prompt "Enter UPN suffix, example: @xxx.onmicrosoft.com"
$UserCount = 5
$UserCount = 60
$StartIndex = 0
$GroupName = "LabUsers"
$GroupId = Get-MgGroup -Filter "DisplayName eq '$GroupName'" | Select-Object -ExpandProperty Id
if (-not $GroupId) {
    $GroupParams = @{
        DisplayName     = $GroupName
        MailEnabled     = $false
        MailNickname    = $GroupName
        SecurityEnabled = $true
    }

    $Group = New-MgGroup @GroupParams
    $GroupId = $Group.Id
}

foreach ($i in 1..$UserCount) {

    $UserNumber = $StartIndex+$i
    $UserName = "$UserNamePrefix$UserNumber"
    $UserName = "$UserNamePrefix{0:D2}" -f $UserNumber
    $UserPrincipalName = $UserName + $UPNSuffix
    $PasswordProfile = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordProfile
    $PasswordProfile.ForceChangePasswordNextSignIn = $true
    $PasswordProfile.Password = $Password

    $UserParams = @{
        AccountEnabled = $true
        DisplayName = $UserName
        MailNickname = $UserName
        UserPrincipalName = $UserPrincipalName
        PasswordProfile = $PasswordProfile
        OutVariable = "CreatedUser"
    }

    Write-Host "Creating user : $UserPrincipalName"

    try {
        New-MgUser @UserParams
    }
    catch {
        Write-Host "Error creating user $UserPrincipalName : $_"
    }

    # Add user to group
    $UserId = $CreatedUser.Id
    try {
        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $UserId
    }
    catch {
        Write-Host "Error adding user $UserPrincipalName to group $GroupName : $_"
    }

}

# Configure Temporary Access Pass (TAP) for users
# Note: TAP requires Entra ID Premium P2 license
# https://learn.microsoft.com/en-us/entra/identity/authentication/howto-authentication-temporary-access-pass
$UserNamePrefix = "LabUser-"
$Users = Get-MgUser -Filter "startsWith(DisplayName,'$UserNamePrefix')"
$TAPs = @()

foreach ($user in $Users[5..$Users.Count]) {
    $properties = @{}
    $properties.isUsableOnce = $false
    $properties.startDateTime = Get-Date -Hour 00 -Minute 0 -Second 0 -Millisecond 0 -Day 17 -Month 9 -Year 2025
    #$properties.startDateTime = (Get-Date).AddMinutes(1)
    $properties.endDateTime = $properties.startDateTime.AddDays(1)
    $propertiesJSON = $properties | ConvertTo-Json

    Write-Host "Creating Temporary Access Pass for user: $($user.UserPrincipalName)" -ForegroundColor Green

    try {
        New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -BodyParameter $propertiesJSON -OutVariable "CreatedTAP"
    }
    catch {
        Write-Host "Error creating TAP for user $($user.UserPrincipalName) : $_"
    }

$TAPs += [pscustomobject]@{
        UserPrincipalName = $user.UserPrincipalName
        TemporaryAccessPass = $CreatedTAP.TemporaryAccessPass
        LifetimeInMinutes = $CreatedTAP.LifetimeInMinutes
        IsUsableOnce = $CreatedTAP.IsUsableOnce
        StartDateTime = $CreatedTAP.StartDateTime
        EndDateTime = $CreatedTAP.StartDateTime.AddMinutes($CreatedTAP.LifetimeInMinutes)
    }

}

Export-Excel -InputObject $TAPs -Path ".\TemporaryAccessPasses.xlsx" -AutoSize -Title "Temporary Access Passes" -WorksheetName "TAPs" -TableName "TAPs" -TableStyle Light1
