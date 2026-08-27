#Connect-AzAccount
#Install-Module -Name AzureAD
#Set-ExecutionPolicy -ExecutionPolicy Unrestricted


$user_group="SQLHackUsers"
$HackRG ="rg-sqlhack"

$group = get-AzAdgroup -DisplayName $user_group

if(!$group)
{

$group= New-AzADGroup -DisplayName $user_group -MailNickname $user_group
}
$username="sqlhackuser"
$domain="1dayopenhack.biz"

$count=1..25

$groupid=$group.Id

foreach ($i in $count)
{
    $i_string = $i | % tostring 00
    $password="&sqlhack@demo_"+$i_string+"!"
    $securepassword= ConvertTo-SecureString $password -AsPlainText -force
    $upn=$username+$i_string +"@"+$domain
    $user = Get-AzADUser -UserPrincipalName $upn
    if(!$user)
    {
        Write-Host "Creating user $upn"
        $member=New-AzADUser -DisplayName $username$i_string  -Password $securepassword  -AccountEnabled $true -MailNickname $username$i_string  -UserPrincipalName $upn
        Add-AzADGroupMember -TargetGroupObjectId $groupid -MemberObjectId $member.Id
    }
    else
    {
        Write-Host "User $upn already exists"
    }
     
}

# Create AdminUser (RUN THIS PART IF YOU ONLY NEED AN ADDITIONAL  ADMIN USER FOR MULTIPLE COACHES)
    # $username ="adminuser"  (RUN THIS PART IF YOU ONLY NEED AN ADDITIONAL SQL MI ADMIN USER FOR MULTIPLE COACHES)
    # $password = <TYPE YOUR PASSWORD HERE BEFORE YOU RUN THE CODE IN YOUR SUBSCRIPTION >
    # $securepassword= ConvertTo-SecureString $password -AsPlainText -force
    # $upn=$username+"@"+$domain
    # $member=New-AzADUser -DisplayName $username$i_string  -Password $securepassword  -AccountEnabled $true -MailNickname $username$i_string  -UserPrincipalName $upn

#Get-AzRoleDefinition | Format-Table -Property Name, IsCustom, Id

New-AzRoleAssignment -ObjectId $groupid -RoleDefinitionName Reader -Scope (Get-AzResourceGroup -Name $HackRG).ResourceId

