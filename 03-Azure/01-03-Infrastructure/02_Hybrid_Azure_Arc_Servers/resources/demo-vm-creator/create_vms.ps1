# Virtual Machine creation (PowerShell equialent of create_vms.sh)


# Resource group creation and role assignment

$SubscriptionName = "Infra-Micro-Hack"
$Location = "Sweden Central"
$ResourceGroupPrefix = "LabUser-"
$ResourceGroupCount = 10
$StartIndex = 60

Set-AzContext -Subscription $SubscriptionName

for ($i = 1; $i -le $ResourceGroupCount; $i++) {

    $ResourceGroupNumber = $StartIndex+$i
    $ResourceGroupName = "$ResourceGroupPrefix$ResourceGroupNumber"
    $ResourceGroupName = "$ResourceGroupPrefix{0:D2}" -f $ResourceGroupNumber

    New-AzResourceGroup -Name $ResourceGroupName -Location $Location

    Write-Host "Updating role assignments for resource group $ResourceGroupName"

    $SignInName = $ResourceGroupName + $UPNSuffix
    New-AzRoleAssignment -SignInName $SignInName -ResourceGroupName $ResourceGroupName -RoleDefinitionName 'Owner'


}


$ResourceGroups = Get-AzResourceGroup -Name LabUser*

$AdminPassword = Read-Host -Prompt "Enter VM password"

foreach ($rg in $ResourceGroups) {

$Location = "Sweden Central"
$VMSize = "Standard_D2s_v6"
$AdminUsername = "mhadmin"


# Win 2025

$TemplateUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/template-win2025.json'


#$TemplateParameterFileUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/parameters-win2025.json'
$TemplateParameters = @{
    Location = $Location
    adminUsername = $AdminUsername
    adminPassword = $AdminPassword
    virtualMachineSize       = $VMSize
    networkInterfaceName = "$($rg.ResourceGroupName)-win2025-nic"
    networkSecurityGroupName = "$($rg.ResourceGroupName)-win2025-nsg"
    virtualNetworkName = "$($rg.ResourceGroupName)-VNet"
    subnetName = "default"
    virtualMachineName = "$($rg.ResourceGroupName)-win2025-vm"
    virtualMachineComputerName = "win2025"
    publicIpAddressName = "$($rg.ResourceGroupName)-win2025-pip"
    publicIpAddressType = "Static"
    publicIpAddressSku = "Standard"
    pipDeleteOption = "Delete"
    osDiskType = "StandardSSD_LRS"
    virtualMachineRG = $rg.ResourceGroupName
    osDiskDeleteOption = "Delete"
    nicDeleteOption = "Delete"
    hibernationEnabled = $false
    patchMode = "AutomaticByOS"
    enableHotpatching = $false
    addressPrefixes = @("10.0.0.0/16")
    subnets = @(
        @{
            name = "default"
            properties = @{
                addressPrefix = "10.0.0.0/24"
            }
        },
            @{
            name = "AzureBastionSubnet"
            properties = @{
                addressPrefix = "10.0.1.0/26"
            }
        }
    )
    networkSecurityGroupRules = @(
        @{
            name = "RDP"
            properties = @{
                protocol = "Tcp"
                sourcePortRange = "*"
                destinationPortRange = "3389"
                sourceAddressPrefix = "*"
                destinationAddressPrefix = "*"
                access = "Allow"
                priority = 1000
                direction = "Inbound"
            }
        }
    )
}

if (-not (Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName | Where-Object DeploymentName -eq template-win2025)) {
    New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -TemplateUri $TemplateUrl -TemplateParameterObject $TemplateParameters
}




# Win 2012 R2

$TemplateUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/template-win2012.json'
$VMSize = "Standard_D2s_v5"

#$TemplateParameterFileUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/parameters-win2025.json'
$TemplateParameters = @{
    Location = $Location
    adminUsername = $AdminUsername
    adminPassword = $AdminPassword
    virtualMachineSize       = $VMSize
    networkInterfaceName = "$($rg.ResourceGroupName)-win2012-nic"
    networkSecurityGroupName = "$($rg.ResourceGroupName)-win2012-nsg"
    virtualNetworkName = "$($rg.ResourceGroupName)-VNet"
    subnetName = "default"
    virtualMachineName = "$($rg.ResourceGroupName)-win2012-vm"
    virtualMachineComputerName = "win2012"
    publicIpAddressName = "$($rg.ResourceGroupName)-win2012-pip"
    publicIpAddressType = "Static"
    publicIpAddressSku = "Standard"
    pipDeleteOption = "Delete"
    osDiskType = "StandardSSD_LRS"
    virtualMachineRG = $rg.ResourceGroupName
    osDiskDeleteOption = "Delete"
    nicDeleteOption = "Delete"
    hibernationEnabled = $false
    patchMode = "AutomaticByOS"
    enableHotpatching = $false
    Win2012R2imageUri = "https://asdlij32.blob.core.windows.net/mh-arc/win2012r2-specialized.vhd"
    addressPrefixes = @("10.0.0.0/16")
    subnets = @(
        @{
            name = "default"
            properties = @{
                addressPrefix = "10.0.0.0/24"
            }
        },
            @{
            name = "AzureBastionSubnet"
            properties = @{
                addressPrefix = "10.0.1.0/26"
            }
        }
    )
    networkSecurityGroupRules = @(
        @{
            name = "RDP"
            properties = @{
                protocol = "Tcp"
                sourcePortRange = "*"
                destinationPortRange = "3389"
                sourceAddressPrefix = "*"
                destinationAddressPrefix = "*"
                access = "Allow"
                priority = 1000
                direction = "Inbound"
            }
        }
    )
}

if (-not (Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName | Where-Object DeploymentName -eq template-win2012)) {
    New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -TemplateUri $TemplateUrl -TemplateParameterObject $TemplateParameters
}




# Linux

$TemplateUrl = 'https://raw.githubusercontent.com/janegilring/MicroHack/refs/heads/arc_mikro_hack_norway/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/template-linux.json'
#$TemplateParameterFileUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/parameters-win2025.json'

$VMSize = "Standard_D2s_v6"

$TemplateParameters = @{
    Location = $Location
    adminUsername = $AdminUsername
    adminPassword = $AdminPassword
    virtualMachineSize       = $VMSize
    networkInterfaceName = "$($rg.ResourceGroupName)-linux-nic"
    networkSecurityGroupName = "$($rg.ResourceGroupName)-linux-nsg"
    virtualNetworkName = "$($rg.ResourceGroupName)-VNet"
    subnetName = "default"
    virtualMachineName = "$($rg.ResourceGroupName)-linux-vm"
    virtualMachineComputerName = "linux"
    publicIpAddressName = "$($rg.ResourceGroupName)-linux-pip"
    publicIpAddressType = "Static"
    publicIpAddressSku = "Standard"
    pipDeleteOption = "Delete"
    osDiskType = "StandardSSD_LRS"
    virtualMachineRG = $rg.ResourceGroupName
    osDiskDeleteOption = "Delete"
    nicDeleteOption = "Delete"
    hibernationEnabled = $false
    addressPrefixes = @("10.0.0.0/16")
    subnets = @(
        @{
            name = "default"
            properties = @{
                addressPrefix = "10.0.0.0/24"
            }
        },
            @{
            name = "AzureBastionSubnet"
            properties = @{
                addressPrefix = "10.0.1.0/26"
            }
        }
    )
    networkSecurityGroupRules = @(
        @{
            name = "SSH"
            properties = @{
                protocol = "Tcp"
                sourcePortRange = "*"
                destinationPortRange = "22"
                sourceAddressPrefix = "*"
                destinationAddressPrefix = "*"
                access = "Allow"
                priority = 1000
                direction = "Inbound"
            }
        }
    )
}

if (-not (Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName | Where-Object DeploymentName -eq template-linux)) {
    New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -TemplateUri $TemplateUrl -TemplateParameterObject $TemplateParameters
}


}



# VM configuration via Run Command

foreach ($rg in $ResourceGroups) {

    $RunCommandScriptUri = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/reconfig-win.ps1'

    if (-not (Get-AzVMRunCommand -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-win2025-vm")) {
        Write-Host "Setting Run Command for VM: $($rg.ResourceGroupName)-win2025-vm"
        Set-AzVMRunCommand -Location $Location -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-win2025-vm" -RunCommandName "LabPrep" -SourceScriptUri $RunCommandScriptUri -AsJob -AsyncExecution
    } else {
        Write-Host "Run Command already set for VM: $($rg.ResourceGroupName)-win2025-vm"
    }

    if (-not (Get-AzVMRunCommand -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-win2012-vm")) {
        Write-Host "Setting Run Command for VM: $($rg.ResourceGroupName)-win2012-vm"
        Set-AzVMRunCommand -Location $Location -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-win2012-vm" -RunCommandName "LabPrep" -SourceScriptUri $RunCommandScriptUri -AsJob -AsyncExecution
    } else {
        Write-Host "Run Command already set for VM: $($rg.ResourceGroupName)-win2012-vm"
    }

    $RunCommandScriptUri = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/02_Hybrid_Azure_Arc_Servers/resources/demo-vm-creator/reconfig-ubuntu.sh'
    if (-not (Get-AzVMRunCommand -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-linux-vm")) {
        Write-Host "Setting Run Command for VM: $($rg.ResourceGroupName)-linux-vm"
        Set-AzVMRunCommand -Location $Location -ResourceGroupName $rg.ResourceGroupName -VMName "$($rg.ResourceGroupName)-linux-vm" -RunCommandName "LabPrep" -SourceScriptUri $RunCommandScriptUri -AsJob -AsyncExecution
    } else {
        Write-Host "Run Command already set for VM: $($rg.ResourceGroupName)-linux-vm"
    }


}