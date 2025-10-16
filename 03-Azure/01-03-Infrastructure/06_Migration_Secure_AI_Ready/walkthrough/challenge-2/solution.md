# Walkthrough Challenge 2 - Discover physical servers for the migration

Duration: 60 minutes

## Prerequisites

Please make sure thet you successfully completed [Challenge 1](../challenge-1/solution.md) before continuing with this challenge.

### **Task 1: Create a Azure Migrate Project**

Open the [Azure Portal](https://portal.azure.com) and login using a user account with at least Contributor permissions on a Azure Subscription.

In the search bar enter *Azure Migrate* and select Azure Migrate from the list of services

![image](./img/AzMig1.png)

Select *All projects* from the navigation pane on the left and click on *Create project*

![image](./img/AzMig2.png)

> [!IMPORTANT]
> To be able to create a Business Case, make sure to select **Europe** as the Geography for the Azure Migrate Project

Select the *destination-rg* Resource Group, specify a name for the Azure Migrate Project and also select a geography where the data will be stored.

![image](./img/AzMig3.png)

Wait until the Azure Migrate Project has been created. Select *All projects* from the navigation pane on the left.
Your previousley created Azure Migrate project should be listed. Click on it to open the project.

![image](./img/AzMig4.png)

![image](./img/AzMig5.png)


### **Task 2: Create and prepare Windows Server 2022 for the Azure Migrate Appliance**

To start physical server discovery you must install the Azure Migrate Appliance on your on-premises. The Azure Migrate Appliance can be downloaded as a OVA or VHD template or you can download a ZIP file containing a PowerShell script to install it on an already existing server. For the purpose of this MicroHack we will install the Azure Migrate Appliance via the PowerShell script on a Windows Server 2022 system.

> [!IMPORTANT]
> Please make sure to check the [prerequisites](https://learn.microsoft.com/en-us/azure/migrate/tutorial-discover-physical#prerequisites) of the Azure Migrate Appliance.

In the Azure Portal select *Virtual machines* from the navigation pane on the left. Select *Create -> Virtual machine*

![image](./img/AzMigApp1.png)

Under Basics select the *source-rg* Resource Group and provide a name for the server. Select *Windows Server 2022 Datacenter - x64 Gen2* for the image and select *Standard_B4as_v2* as the VM size.

![image](./img/AzMigApp2.png)

![image](./img/AzMigApp2-1.png)

> [!NOTE]
> For the Username and Password you can either select a combination of your choice or check the secrets within the KeyVault to copy the same credentials that have been used during the deployment of the source VMs which will be migrated later.

Accept the default disk settings and click next to select the *Networking* tab. Select the *source-vnet* Virtual Network, select the *source-subnet* Subnet and make sure to select *None* for the Public IP and NIC network security group.

![image](./img/AzMigApp3.png)

Accept the default settings for the remaining tabs, select *Review + create* and click *Create*.

![image](./img/AzMigApp4.png)

Wait until the deployment has been successfully completed and select *Go to resource*

![image](./img/AzMigApp5.png)

Select *Bastion* from the navigation pane on the left, provide the credentials to login to the Azure Migrate Appliance VM and select *Connect*. A new browser tab should open with a remote session to the Windows Server 2022 system.

> [!NOTE]
> You can also select *Password from Azure KeyVault* under *Authentication Type* if you set the password during VM creation to match the secret stored in the KeyVault.

![image](./img/AzMigApp6.png)

### **Task 3: Install the Azure Migrate Appliance software**

> [!IMPORTANT]
> Please make sure to run the following commands inside of the virtual machine you created for the mirgration appliance

Open Microsoft Edge on the Windows Server 2022 system and navigate and login to the [Azure Portal](https://portal.azure.com).

![image](./img/AzMigApp7.png)

In the search bar enter *Azure Migrate* and select Azure Migrate from the list of services

![image](./img/AzMig1.png)

 Select *All projects* from the navigation pane on the left. Your previousley created Azure Migrate project should be listed. Click on it to open the project.
 
![image](./img/Discover1.png)

Select *Start Discovery -> Using appliance -> for Azure*.

![image](./img/Discover1-2.png)

Select *Physical or other (AWS, GCP, Xen, etc.)* from the *Are your servers virtualized* drop down. Enter a name into the *Name your appliance* field and clicke *Generate*. Wait until the Project key has been created. Copy the Project key and click *Download*, to download the ZIP file containing the PowerShell script to install the Azure Migrate Appliance.

![image](./img/Discover2.png)

Open the folder containing the download and extract the ZIP file.

![image](./img/Discover3.png)

![image](./img/Discover3-1.png)

Start an evelvated PowerShell session and change the PowerShell directory to the folder where the contents have been extraceted.
Run the script named AzureMigrateInstaller.ps1 and select *R* to confirm script execution.

![image](./img/Discover4.png)

Select Option 3 for *Physical or other (AWS, GCP, Xen, etc.)*

![image](./img/Discover5.png)

Select Option 1 for *Azure Public*

![image](./img/Discover6.png)

Select Option 1 for *public endpoint* and confirm your selection to start the installation.

![image](./img/Discover7.png)

Select *R* again and continue the installation.

![image](./img/Discover8-1.png)

Select *Y* again to uninstall IE11 and continue the installation.

![image](./img/Discover8-2.png)

The system will reboot automatically. Installation is now complete.

![image](./img/Discover8-3.png)

Wait for the reboot to complete, log-in again and proceed to Task 4.

### **Task 4: Configure the Azure Migrate Appliance**

Open Azure Migrate Appliance Configuration Manager using the icon on the Desktop.

![image](./img/Discover9-0.png)

Agree the terms of use.

![image](./img/Discover9.png)

Paste the previously copied Azure Migrate project key and click *Verify*. Once successfully verified the latest appliance updates will be installed.

> [!IMPORTANT]
> If you forgott to copy the key, go back to the Azure Migrate Project, Select *Action center* from the left, klick on *Pending actions* and then on *Register* to copy the key again

![image](./img/Discover9-1.png)

![image](./img/Discover10.png)

Wait for the Appliance to check and install required updates. Once completed log in to Azure using the provieded code.

![image](./img/Discover11.png)

![image](./img/Discover12.png)

![image](./img/Discover13.png)

After successfull authentication, the appliance will be registered with the Azure Migrate project.

![image](./img/Discover14.png)

Next you need to specify the credentials that will be used to connect to the source server for discovery.
Add one entry for Windows and for Linux devices. The friendly name will be used later on when specifiying the individual systems.

> [!NOTE]
> For the Username and Password check the secrets within the KeyVault.

![image](./img/Discover15.png)

Next you need to provide the individual source server details and map them to a specific set of credentials. Make sure that validation is successfull.

![image](./img/Discover16.png)

![image](./img/Discover16-1.png)

The last step is to provide additional credentials if you want to perform software inventory to additionaly collect information about installed web server or SQL server. To start discovery click *Start discovery*.

![image](./img/Discover17.png)

![image](./img/Discover17-1.png)

After discovery has been successfully initiated, go to the Azure portal to review the discovered inventory.

![image](./img/Discover18.png)

> [!NOTE]
> If no inventory data is available, click Refresh to refresh inventory data.

You successfully completed challenge 2! 🚀🚀🚀

The deployed architecture now looks like the following diagram.

![image](./img/Challenge-2.jpg)

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-3/solution.md)
