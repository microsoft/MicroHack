# Walkthrough Challenge 2 - Discover the virtualized servers for the migration

[Previous Challenge Solution](../challenge-01/solution-01.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-03/solution-03.md)

Duration: 60 minutes

### **Task 1: Create an Azure Migrate project**

Open the [Azure Portal](https://portal.azure.com) and log in using a user account with at least Contributor permissions on an Azure subscription.

In the search bar, enter *Azure Migrate* and select Azure Migrate from the list of services.

![image](./img/AzMig1.png)

Select *All projects* from the navigation pane on the left and click *Create project*.

![image](./img/AzMig2.png)

> [!IMPORTANT]
> To create a business case, make sure to select **Europe** as the *Geography* for the Azure Migrate project.

Select the *destination-rg* resource group, specify a name for the Azure Migrate project, and select a geography where the data will be stored.

![image](./img/AzMig3.png)

Wait until the Azure Migrate project has been created. Select *All projects* from the navigation pane on the left.
Your previously created Azure Migrate project should be listed. Click on it to open the project.

![image](./img/AzMig4.png)

![image](./img/AzMig5.png)

### **Task 2: Install the Azure Migrate appliance software**

To start physical server discovery, you must install the Azure Migrate appliance in your on-premises environment. You can download the appliance as an OVA or VHD template, or download a ZIP file containing a PowerShell installation script. For this MicroHack, install the appliance by running the PowerShell script on the existing **MHBOX-AzMigSrv** server.

> [!IMPORTANT]
> Check the [prerequisites](https://learn.microsoft.com/en-us/azure/migrate/tutorial-discover-physical#prerequisites) for the Azure Migrate appliance.

In the Azure Portal select *Virtual machines* from the navigation pane on the left. Select the *MHBox-HV* system and log on via Azure Bastion with your credentials:

> [!NOTE]
> You can also select *Password from Azure Key Vault* under *Authentication Type* to select the secret stored in the Key Vault.

![image](./img/AzMigApp1.png)

Start the Hyper-V Manager and connect to the **MHBOX-AzMigSrv** server.

The following credentials are being used inside the nested VMs.

**Windows virtual machine credentials:**

```text
Username: Administrator
Password: JS123!!
```

**Ubuntu virtual machine credentials:**

```text
Username: jumpstart
Password: JS123!!
```

> [!IMPORTANT]
> Please make sure to run the following commands inside of the **MHBOX-AzMigSrv** virtual machine that was created for the migration appliance during the deployment.

![image](./img/AzMigApp2.png)

Open Microsoft Edge on the Windows Server 2022 system, navigate to the [Azure Portal](https://portal.azure.com), and log in.
In the search bar, enter *Azure Migrate* and select Azure Migrate from the list of services.

![image](./img/AzMigApp3.png)

Select *All projects* from the navigation pane on the left. Your previously created Azure Migrate project should be listed. Click it to open the project.
 
![image](./img/Discover1.png)

Select *Start Discovery -> Using appliance -> for Azure*.

![image](./img/Discover1-2.png)

Select *Yes, with Hyper-V* from the *Are your servers virtualized* list. Enter a name in the *Name your appliance* field and click *Generate*. Wait until the project key has been created. Copy the project key and click *Download* to download the ZIP file containing the PowerShell script that installs the Azure Migrate appliance.

![image](./img/Discover2.png)

Open the folder containing the download and extract the ZIP file.

![image](./img/Discover3.png)

![image](./img/Discover3-1.png)

Start an elevated PowerShell session and change to the folder where the contents were extracted.
Run the script named AzureMigrateInstaller.ps1 and select *R* to confirm script execution.

Select option 2 for *Hyper-V*.

![image](./img/Discover4.png)

Select option 1 for *Azure Public*.

![image](./img/Discover6.png)

Select option 1 for *public endpoint* and confirm your selection to start the installation.

![image](./img/Discover7.png)

Select *R* again and continue the installation.

![image](./img/Discover8-1.png)

Select *Y* again to uninstall IE11 and continue the installation.

![image](./img/Discover8-2.png)

The system will reboot automatically. Installation is now complete.

![image](./img/Discover8-3.png)

Wait for the reboot to complete, log in again, and proceed to Task 3.

### **Task 3: Configure the Azure Migrate appliance**

Open Azure Migrate Appliance Configuration Manager using the icon on the desktop.

![image](./img/Discover9-0.png)

Agree to the terms of use.

![image](./img/Discover9.png)

Paste the previously copied Azure Migrate project key and click *Verify*. Once the key is successfully verified, the latest appliance updates will be installed.

> [!IMPORTANT]
> If you forgot to copy the key, go back to the Azure Migrate project, select *Action center* from the left, click *Pending actions*, and then click *Register* to copy the key again.

![image](./img/Discover9-1.png)

![image](./img/Discover10.png)

Wait for the appliance to check for and install required updates. Once this process is complete, log in to Azure using the provided code.

![image](./img/Discover11.png)

![image](./img/Discover12.png)

![image](./img/Discover13.png)

After successful authentication, the appliance will be registered with the Azure Migrate project.

![image](./img/Discover14.png)

Next, specify the credentials that will be used to connect to the hypervisor to discover the guest VMs.

> [!NOTE]
> For the username and password, check the secrets in the Key Vault.

![image](./img/Discover15.png)

Next, map the credentials to the Hyper-V host. Make sure that validation is successful.

![image](./img/Discover15-1.png)

![image](./img/Discover15-2.png)

Next, provide the individual credentials that will be used to perform guest discovery on the guest VMs.

![image](./img/Discover16.png)

To start discovery, click *Start discovery*.

After discovery has been successfully initiated, go to the Azure portal to review the discovered inventory.

![image](./img/Discover18.png)

> [!NOTE]
> If no inventory data is available, click *Refresh*.

You successfully completed Challenge 2! 🚀🚀🚀

The deployed architecture now looks like the following diagram.

![image](./img/Challenge-2.jpg)
