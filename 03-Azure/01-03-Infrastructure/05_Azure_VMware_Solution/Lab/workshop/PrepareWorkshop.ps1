###################################################################################################################################################

# Create or Delete Group Accounts in Azure AD
#region Create/Delete Group Accounts in Azure AD
function Initialize-GroupAccounts {

    param (
        [Parameter()]
        [string]$AccountPrefix = "GPSUS-Group", #Account Prefix, default: GPSUS-Group

        [Parameter(Mandatory)]
        [ValidateRange(1, 50)]
        [Int] $NumberOfGroups, #How many Groups?

        [Parameter()]
        [string]$Operation #Create, Delete, Disable
    )

    for ($i = 1; $i -le $numberOfGroups; $i++) {
        $username = $AccountPrefix + $i
        $password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        # $password = $([guid]::NewGuid()).ToString().Substring(0,13)
        $upn = $username + "@vmwaresales101outlook.onmicrosoft.com"
    
        if ($Operation -eq "Create" ) {
            az ad user create --display-name $username --password $password --user-principal-name $upn
            Write-Host User $upn created with password $password -ForegroundColor Green
        }
        elseif ($Operation -eq "Delete" ) {
            az ad user delete --id $upn
            Write-Host User $upn deleted successfully -ForegroundColor Green
        }
        else {
            #This code will not be executed. But left for future enhancement
            az ad user update --id $upn --account-enabled $false
            Write-Host User $upn disabled successfully -ForegroundColor Green
        }
    }

}

###################################################################################################################################################
# Execution Examples:
###################################################################################################################################################

#GPSUS-Group
<#
Initialize-GroupAccounts -AccountPrefix "GPSUS-Group" -NumberOfGroups 10 -Operation "Create"
Initialize-GroupAccounts -AccountPrefix "GPSUS-Group" -NumberOfGroups 10 -Operation "Delete"
#>

#GPS-Group
<#
Initialize-GroupAccounts -AccountPrefix "GPS-Group" -NumberOfGroups 10 -Operation "Create"
Initialize-GroupAccounts -AccountPrefix "GPS-Group" -NumberOfGroups 10 -Operation "Delete"
#>

#endregion

###################################################################################################################################################
###################################################################################################################################################

# Create Group Accounts, Assign Roles Permissions for Group user accounts on Azure Resource Groups for Workshop, and Delete Group Accounts
#region Create Group Accounts, Assign Roles Permissions for Group user accounts on Azure Resource Groups for Workshop, and Delete Group Accounts

function Get-SubscriptionId {

    <#
    $subsList = az account subscription list
    $subsListString = [system.String]::Join(" ", $subsList)
    $subsListJson = ConvertFrom-Json $subsListString
    #$subsListJson[0].id
    return $subsListJson[0].id
    #>
    
    return $(az account subscription list --query "[0].id" --output tsv)
}

function Set-GroupAccountsPermissionsAndPasswords {
    param (
        [Parameter()]
        [String]$Prefix,

        [Parameter(Mandatory = $true)]
        [String]$AccountPrefix,

        [Parameter()]
        [String]$PasswordPrefix,

        [Parameter(Mandatory = $true)]
        [ValidateSet(2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40)]
        [Int]$NumberOfLabs,
   
        [Parameter()]
        [switch] $CreateAccounts = $false,

        [Parameter()]
        [switch] $ResetPasswords = $false,

        [Parameter()]
        [switch] $DeleteAccounts = $false
    )

    Write-Host "Script Started"

    #Create $AccountPrefix<x> accounts
    if ($CreateAccounts) {
        Initialize-GroupAccounts -AccountPrefix $AccountPrefix -NumberOfGroups $NumberOfLabs -Operation "Create"
    }

    #Delete $AccountPrefix<x> accounts
    if ($DeleteAccounts) {
        Initialize-GroupAccounts -AccountPrefix $AccountPrefix -NumberOfGroups $NumberOfLabs -Operation "Delete"
    }
    else {

        $ResourceGroupSuffix = "PrivateCloud", "Operational", "Network", "Jumpbox"
    
        #Check if number of labs is even. If it's odd, the logic will not proceed.
        if ($NumberOfLabs % 2 -eq 0) {

            $numbers = 1..$NumberOfLabs

            $subId = Get-SubscriptionId

            $pairs = @()
            for ($i = 0; $i -lt $numbers.Count; $i += 2) {
                if ($i + 1 -lt $numbers.Count) {
                    $pairs += , @($numbers[$i], $numbers[$i + 1])
                }
            }

            Write-Host "Number of Group Pairs:" $pairs.Count

            foreach ( $pair in $pairs ) {
                foreach ($x in $pair) {
                    Write-Host
                    Write-Host Group $x
                    $accountId = $AccountPrefix + $x + "@vmwaresales101outlook.onmicrosoft.com"
                    $accountPassword = $PasswordPrefix + $x + "-AVS!"
                    Write-Host $accountId
            
                    if ($CreateAccounts -or $ResetPasswords) {
                        #Resetting Group Accounts Passwords
                        Write-Host "Resetting account password with provided password prefix."
                        az ad user update --id $accountId --password $accountPassword --force-change-password-next-sign-in false
                    }

                    #Assiging permessions for the Group Accounts over Azure Resource Groups for each AVS Lab Environment
                    foreach ($y in $pair) {
                        #Write-Host $x $y
                        Write-Host "Assigning Contributor Role for account $accountId on Group$y's Azure Resources"
                    
                        #Start-Job -ScriptBlock {
                        foreach ($rgsfx in $ResourceGroupSuffix) {
                            $scope = $subId + "/resourceGroups/" + $Prefix + $y + "-" + $rgsfx
                            #Write-Host $scope
                            [void] (az role assignment create --assignee $accountId --role "Contributor" --scope $scope)
                        }
                        #}
                    }
            
                }

            }
        }
        else {
            Write-Host "Number of Labs is odd ( " + $pairs.Count + " ). Unable to create lab pairs!"
        }
    }
    Write-Host "Script Ended"
}

###################################################################################################################################################
# Execution Examples:
###################################################################################################################################################

#Run when workshop starts
#Set-GroupAccountsPermissionsAndPasswords -Prefix "GPSUS-TEST-" -AccountPrefix "GPSUS-Group" -PasswordPrefix "XYZ" -NumberOfLabs 4 -CreateAccounts
#or
#Set-GroupAccountsPermissionsAndPasswords -Prefix "GPSUS-TEST-" -AccountPrefix "GPS-Group" -PasswordPrefix "XYZ" -NumberOfLabs 4 -CreateAccounts

#Run after workshop ends
#Set-GroupAccountsPermissionsAndPasswords -AccountPrefix "GPSUS-Group" -NumberOfLabs 4 -DeleteAccounts
#or
#Set-GroupAccountsPermissionsAndPasswords -AccountPrefix "GPS-Group" -NumberOfLabs 4 -DeleteAccounts
#endregion

###################################################################################################################################################
###################################################################################################################################################

# Recycle one Group Account, Assign Roles for that Group user account on Azure Resource Groups for GPSUS Workshop
#region Recycle Group Account

# This helps in case a user setup MFA for the account
function Reset-GroupAccountPermissionsAndPassword {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Prefix,
     
        [Parameter(Mandatory = $true)]
        [String]$AccountPrefix,

        [Parameter(Mandatory = $true)]
        [int]$AccountNumber,

        [Parameter(Mandatory = $true)]
        [String]$Password,

        [Parameter(Mandatory = $true)]
        [Int]$FirstLab,

        [Parameter(Mandatory = $true)]
        [Int]$SecondLab
    )

    Write-Host "Script Started"

    $username = $AccountPrefix + $AccountNumber
    $upn = $username + "@vmwaresales101outlook.onmicrosoft.com"

    #deleting existing user
    az ad user delete --id $upn

    #creating new user with same upn
    az ad user create --display-name $username --password $Password --user-principal-name $upn --force-change-password-next-sign-in false

    Write-Host User $upn recycled with password $password -ForegroundColor Green

    $subId = Get-SubscriptionId

    $ResourceGroupSuffix = "PrivateCloud", "Operational", "Network", "Jumpbox"
    
    $pair = @($FirstLab, $SecondLab)

    foreach ($y in $pair) {

        #Assiging permessions for the Group Accounts over Azure Resource Groups for each AVS Lab Environment

        Write-Host "Assigning Contributor Role for Account $upn on Group$y Azure Resource"
        
        foreach ($rgsfx in $ResourceGroupSuffix) {
            $scope = $subId + "/resourceGroups/" + $Prefix + $y + "-" + $rgsfx
            #Write-Host $scope
            [void] (az role assignment create --assignee $accountId --role "Contributor" --scope $scope)
        }
    }

    Write-Host "Script Ended"
}

###################################################################################################################################################
# Execution Examples:
###################################################################################################################################################

# Reset-GroupAccountPermissionsAndPassword -Prefix "<Resources-Prefix>" -AccountPrefix "<Group-Account-Number>" -AccountNumber <Group-Number> -Password "<Password-Value>" -FirstLab <lab1> -SecondLab <lab2>

# Reset-GroupAccountPermissionsAndPassword -Prefix "GPSUS-XYZ-" -AccountPrefix "GPSUS-Group" -AccountNumber 3 -Password "TYICsdY@#$%gghhhj24545" -FirstLab 3 -SecondLab 4

#endregion

###################################################################################################################################################
###################################################################################################################################################

# Delete Azure Resource Groups and their Resources
#region Delete Azure Resource Groups and their Resources

function Remove-WorkshopLabAzureResources {
    param (
        [Parameter()]
        [String]$Prefix,

        [Parameter()]
        [ValidateRange(1,[int]::MaxValue)]
        [Int]$FirstLabNumber = 1,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1,[int]::MaxValue)]
        [Int]$NumberOfLabs
    )
    
    for ($i = $FirstLabNumber; $i -le $NumberOfLabs; $i++) {
        az group delete --no-wait --yes --name $Prefix$i-PrivateCloud
        az group delete --no-wait --yes --name $Prefix$i-Operational
        az group delete --no-wait --yes --name $Prefix$i-Network
        az group delete --no-wait --yes --name $Prefix$i-Jumpbox --force-deletion-types Microsoft.Compute/virtualMachines

        Write-Host "Resources for $Prefix$i deleted successfully"  -ForegroundColor Green
    }
}


###################################################################################################################################################
# Execution Examples:
###################################################################################################################################################

#Remove-WorkshopLabAzureResources -Prefix "GPSUS-XYZ-" -FirstLabNumber 1 -NumberOfLabs 6

###################################################################################################################################################

#endregion

###################################################################################################################################################
###################################################################################################################################################