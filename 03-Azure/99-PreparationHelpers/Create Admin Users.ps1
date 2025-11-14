#requires -Version 7

$RequiredModules = @(
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups'
)

foreach ($module in $RequiredModules) {
    Install-PSResource -Name $module -TrustRepository
}

Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","UserAuthenticationMethod.ReadWrite.All" -UseDeviceCode

Get-MgContext

# Lab users and group creation
$UserNamePrefix = "AdminLabUser-"
$Password = Read-Host -Prompt "Enter password"
$UPNSuffix = '@' + ((Get-MgContext).Account -split "@")[1] # Get UPN suffix from the signed-in account (@xxx.onmicrosoft.com)
$UserCount = 5
$StartIndex = 0
$GroupName = "AdminUsers"
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