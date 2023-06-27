# Walkthrough Challenge 5 - Migrate machines to Azure

Duration: 90 minutes

## Prerequisites

Please make sure thet you successfully completed [Challenge 4](../challenge-4/solution.md) before continuing with this challenge.

### **Task 1: Create and prepare Windows Server 2019 for the Azure Replication Appliance**

To start physical server migration you must install the Azure Replication Appliance on your on-premises. The Azure Replication Appliance can be downloaded as a OVA template or you can download the appliance installer to install it on a already existing server. For the purpose of this MicroHack we will install the Azure Replication Appliance via the installer on a new Windows Server 2019 system.

💡 Please make sure to check the [prerequisites](https://learn.microsoft.com/en-us/azure/migrate/migrate-replication-appliance) of the Azure 
Replication Appliance.

💡 Please note that it is currently [not supported](https://learn.microsoft.com/en-us/azure/migrate/common-questions-appliance#can-the-azure-migrate-appliancereplication-appliance-connect-to-the-same-vcenter) to install the Azure Migrate Replication Appliance on the same system as the Azure Migrate Appliance.

In the Azure Portal select *Virtual machines* from the navigation pane on the left. Select *Create -> Azure virtual machine*

![image](./img/azreplapl1.png)

Under Basics select the *source-rg* Resource Group and provide a name for the server. Select *Windows Server 2019 Datacenter - x64 Gen2* for the Image.

![image](./img/azreplapl2.png)

💡 For the Username and Password you can either select a combination of your choice or check the secrets within the KeyVault.

Add an additional 1024GiB Standard HDD LRS data disk to the Virtual Machine and click *Next*

![image](./img/azreplapl2-1.png)

![image](./img/azreplapl2-2.png)

In the *Networking* tab, select the *source-vnet* Virtual Network and the *source-subnet* Subnet and make sure to select *None* for the Public IP and NIC network security group.

![image](./img/azreplapl3.png)

Accept the default settings for the remaining tabs, select *Review + create* and click *Create*.

![image](./img/azreplapl4.png)

Wait until the deployment has been successfully completed and select *Go to resource*

![image](./img/azreplapl5.png)

Select *Bastion* from the navigation pane on the left, provide the credentials to login to the Azure Migrate Replication VM and select *Connect*. A new browser tab should open with a remote session to the Windows Server 2019 system.

![image](./img/azreplapl6.png)

💡 You can also select *Password from Azure KeyVault* under *Authentication Type* if you set the password during VM creation to match the secret stored in the KeyVault.


### **Task 2: Setup the Azure Replication Appliance**

To prepare for physical server migration, you need to verify the physical server settings, and prepare to deploy a replication appliance.

Open the [Azure Portal](https://portal.azure.com) on the Azure Replication Appliance using the Microsoft Edge browser and navigate to the previousley created Azure Migrate project. Select *Servers, databases and web apps*, make sure that the right Azure Migrate Project is selected and click *Discover* in the *Migration tools* box.

![image](./img/mig1.png)

Select *Physical or other...* in the *Are your machines virtualized* drop down and select *West Europe* as the *Target Region*.
Make sure to check the confirmation checkbox and click *Create resources*. 

![image](./img/mig2.png)

Wait until the deployment has been successfully completed. Next under *1. Download and install the repliaction appliance software* click *Download* to download the Azure Migrate Repplication Appliance installer. 
You also need to download the registration key that is required to register the replication appliance under *2. Configure the replication appliance and register it to the project*.

![image](./img/mig3.png)

Next start the installation of the Azure Migrate Replication Appliance by double cklicking the *MicrosoftAzureSiteRecoveryUnifiedSetup.exe*

![image](./img/mig4.png)

Select *Install the configuration server and process server* and click *Next*

![image](./img/mig5.png)

Check the *I acceppt...* checkbox and click *Next*

![image](./img/mig6.png)

Browse and select the previousley downloaded registration key and click *Next*

![image](./img/mig7.png)

Accept the default *Internet connection* configuration

![image](./img/mig8.png)

Review the prerequisites check of the installer. Note that you can safely ignore the static IP warning.

![image](./img/mig9.png)

Specify the required passwords and note the password requirements. 

💡 For the Passwords you can either select your choice or check the secrets within the KeyVault to reuse the password.

![image](./img/mig10.png)

Select *No* for *Do you want to protect VMware virtual machines* and click *Next*

![image](./img/mig11.png)

Verify the *Install location*. The installer should automatically pre-select the largest disk, in our case the 1024 GiB data disk that was created during VM creation.

![image](./img/mig12.png)

Select the appropriate NICs (We only have 1 in our case).

![image](./img/mig13.png)

Verify the installation summary and click *Install* to start the installation.

![image](./img/mig14.png)

Wait until the installation progress is finished.

![image](./img/mig15.png)

After the successfull installation a configuration server connection passphrase will be displayed. Copy the passphrase and save it as a new secret in the source-rg Resource Group KeyVault.

![image](./img/mig17.png)

After the installation completes, the Appliance configuration wizard will be launched automatically.
You can add the local administrator account credentials of the source servers (stored secrets in the source KeyVault).

![image](./img/mig17-1.png)

The last step is to finalize the registration. Refresh the Azure Portal page where you've downloaded the installer and registration keys and select the *azreplappliance* from the drop down list and click on *Finalize registration*.

![image](./img/mig18.png)

### **Task 3: Install the Mobility service on the source server**

On machines you want to migrate, you need to install the Mobility service agent. The agent installers are available on the replication appliance in the *%ProgramData%\ASR\home\svsystems\pushinstallsvc\repository* directory.
To install the Mobility service agent on the Windows machines follow the following steps

1. Sign in to the replication appliance.
2. Navigate to %ProgramData%\ASR\home\svsystems\pushinstallsvc\repository.
3. Find the installer for the machine operating system and version. Review [supported operating systems](https://learn.microsoft.com/en-us/azure/site-recovery/vmware-physical-azure-support-matrix#replicated-machines).
4. Copy the installer file to the machine you want to migrate.

**Windows**

![image](./img/maw1.png)


5. Make sure that you have the passphrase that was generated when you deployed the appliance (You should have saved it as a KeyVault secret).
  * Store the key in a temporary text file and copy the file into the same direcotry on the source machines.
  * You can obtain the passphrase on the replication appliance. From the command line, run the following command to view the passphrase
     C:\ProgramData\ASR\home\svsystems\bin\genpassphrase.exe -v

![image](./img/maw2.png)

  * 💥 Don't regenerate the passphrase. This will break connectivity and you will have to reregister the replication appliance.

#### **Task 3.1: Install the Mobility service on the Windows VMs**

1. Extract the contents of installer file to a local folder (for example C:\Temp) on the machine, as follows:

     ren Microsoft-ASR_UA\*Windows\*release.exe MobilityServiceInstaller.exe
     
     MobilityServiceInstaller.exe /q /x:C:\Temp\Extracted

     cd C:\Temp\Extracted

2. Run the Mobility Service Installer:

     UnifiedAgent.exe /Role "MS" /Platform "VmWare" /Silent

💡 You need to specify *VmWare* for the *Platform* parameter also for physical servers.

3. Register the agent with the replication appliance:

     cd C:\Program Files (x86)\Microsoft Azure Site Recovery\agent

     UnifiedAgentConfigurator.exe /CSEndPoint \<replication appliance IP address\> /PassphraseFilePath \<Passphrase File Path\>

![image](./img/maw3.png)     

**💥 Repeat the above steps for the second Windows Server**

### **Task 4: Enable Replication**

Open the [Azure Portal](https://portal.azure.com) and navigate to the previousley created Azure Migrate project. Select *Servers, databases and web apps*, make sure that the right Azure Migrate Project is selected and click *Replicate* under *Migration Tools*.

![image](./img/repl1.png) 

Select *Servers or virtual machines (VM)* and *Azure VM* and click *Continue*.

![image](./img/repl2.png) 

In the *Basics* page select the previousley created Azure Migrate Replication appliance and specify the Guest Credentials and click next:

![image](./img/repl3.png)

Under *Virtual Machines* select *No I'll specify the migration settings manually* and select the *frontend1* and *frontend2* server from the list.

![image](./img/repl4.png)

Under *Traget Settings* select the *destination-rg* Resource Group and the *destination-vnet* vNet and select next.

![image](./img/repl5.png)

Under *Compute* acceppt the defaults and click next.

![image](./img/repl6.png)

Under *Disks* change the Disk Type to *Standard SSD* and click next.

![image](./img/repl7.png)

Acceppt the defaults for *Tags* and proceed to *Review + Start Replication*. Click *Replicate* to start the replication.

![image](./img/repl8.png)

Wait until the replication has been successfully initiated.

![image](./img/repl9.png)

Under *Migration Tools* you should know see that 2 Server are beeing repölicated. Click on *Overview* to see more details.

![image](./img/repl10.png)

Select *Replicating Machines* from the navigation pane on the left. You should now see the 2 servers and their status.

![image](./img/repl11.png)

### **Task 4: Perform Test Migration**

When delta replication begins, you can run a test migration for the VMs, before running a full migration to Azure. We highly recommend that you do this at least once for each machine, before you migrate it.

* Running a test migration checks that migration will work as expected, without impacting the on-premises machines, which remain operational, and continue replicating.
* Test migration simulates the migration by creating an Azure VM using replicated data (usually migrating to a non-production VNet in your Azure subscription).
* You can use the replicated test Azure VM to validate the migration, perform app testing, and address any issues before full migration.

Open the [Azure Portal](https://portal.azure.com) and navigate to the previousley created Azure Migrate project. Select *Servers, databases and web apps*, make sure that the right Azure Migrate Project is selected and click *Overview* in the *Migration tools* box.

![image](./img/test1.png)

Select *Perform more test migrations* under *Step 2: Test migration*.

![image](./img/test2.png)

Click on the 3 dots on the right corner of each server and select *Test migration* from the drop down.

![image](./img/test3.png)

Select the *destination-vnet* and click on *Test migration*.

![image](./img/test4.png)

Repeat the above steps for the remaining server and wait until the test migration has been successfully finished.

![image](./img/test5.png)

Switch back to the *Overview* section of the *Azure Migrate: Migration and modernization* page. The Cleanup should be pending for the 2 servers.

![image](./img/test6.png)

Select *Virtual machines* from the navigation pane on the left. There will be 2 additional servers *frontend1-test* and *frontend2-test*. Those servers were created during test migration.

![image](./img/test7.png)

Click on the *frontend1-test* server, select *Bastion* and provide the login credentials for the server. Select *Connect* to initiate the connection.

![image](./img/test8.png)

Open the Microsoft Edge browser on the server, enter *localhost* in the address bar and make sure that the web server is running.

![image](./img/test9.png)

Repeat the above steps for the *frontend2-test* system. Once you've confirmed that the applications on the systems are running as expected you can perfom a cleanup for the test migration. Change back to the *Azure Migrate: Migration and modernization* overview page, click on the 3 dots on the end of each row of the replicating servers and select *Clean up test migration*.

![image](./img/test10.png)

Select *Testing complete. Delete test virtual machine* and select *Cleanup Test*. Reapeat the step for the remainig server and wait until the cleanup has been successfully processed.

![image](./img/test11.png)

### **Task 4: Prepare Final Migration**

Currently the two frontend servers are published via an Azure Public Load Balancer. After the migration, the original server will be turned off. Therefore the access to the system via the Azure Public Load Balancer will be broken. To prepare for the migration and to keep downtime as short as possible some pre-migration steps should be performed.

#### **Task 4.1: Create a new Azure Public Load Balancer in the destination environment**

From the Azure Portal open the Load Balancing blade, select Load Balancer on the Navigation pane on the left and click *Create*.

![image](./img/prep1.png)

Under *Basics* select the *destination-rg* Resource Group and provide a name for the new Load Balancer.

![image](./img/prep2.png)

Under *Frontend IP configuration*, click *Add a frontend IP configuration* and create a new Public IP address.

![image](./img/prep3.png)

Under *Backend Pools*, select *Add a backend Pool*. Provide a name and select the *destination-vnet* as the Virtual Network.
Add *10.2.1.4* and *10.2.1.5* as the IP addresses.

💡 Please note: Azure reserves the first four addresses (0-3) in each subnet address range, and doesn't assign the addresses. Azure assigns the next available address to a resource from the subnet address range. So it is predictable which IP addresses will be assigned to the destination VMs after the migration.

![image](./img/prep4.png)

Under *Inbound rules* click on *Add a load balancing rule* and create the load balancing rule as illustrated on the following diagram.

![image](./img/prep5.png)

Under *Outbound rules* click *Add an outbound rule* and create the outbound rule as illustrated on the following diagram.

![image](./img/prep6.png)

Proceed to the *Review + create* section, review your configuration and click *Create*

![image](./img/prep7.png)

Wait until the load balancer has been created, cahnge back to the *Load balancing* section, select the *plb-frontend* Load Balancer and click *Frontend IP configuration* from the navigation pane on the left. Note down the Public IP of the *LoadBalancerFrontEnd* configuration. Repeat the step for the *plb-frontend-dest* Load Balancer.

![image](./img/prep8.png)

#### **Task 4.2: Create a new Azure Traffic Manager Profile**

Azure Traffic Manager is a DNS-based traffic load balancer. It allows us to distribute traffic to public facing endpoints like our two Public Load Balancer. Traffic Manager can be created in advance to distribute traffic among the old and new load balancer. The DNS conbfiguration of the application can be changed in advance to point to the Traffic Manager Profile instead to the Public IP of the Load Balancer. Using this approach makes sure that Traffic Manager automatically removes the old Load Balancer after the frontend servers were migrated.

From the Azure Portal open the Load Balancing blade, select Traffic Manager on the Navigation pane on the left and click *Create*.

![image](./img/prep9.png)

Select a name for the Traffic Manager profile and select the *destination-rg* as the Resourec Group.

![image](./img/prep10.png)

From the Load Balancing overview page select *Traffic Manager* and select the previously created Traffic Manager profile. 
Select *Endpoints* and click *Add*. Add each public IP of the source and destination Load Balancer as separate endpoints.

![image](./img/prep11.png)

💡 Please note: To be able to add the public IP addresses they need to be configured with an [DNS name lable](https://learn.microsoft.com/en-us/azure/dns/dns-custom-domain?toc=%2Fazure%2Fvirtual-network%2Ftoc.json#public-ip-address).

Check the Overview section under the navigation pane and note that the source load balancer is shown as *online* whereas the 
destination load balancer is shown as *degraded*. If you copy the DNS name of the Traffic Manager profile and paste it into your browser, you should be able to browse the source web servers through the Traffic Manager Profile.

![image](./img/prep12.png)

![image](./img/prep13.png)

### **Task 5: Perform Final Migration**

Open the [Azure Portal](https://portal.azure.com) and navigate to the previousley created Azure Migrate project. Select *Servers, databases and web apps*, make sure that the right Azure Migrate Project is selected and click *Overview* in the *Migration tools* box. From the Overview section click in *Migrate* under *Step 3: Migrate*.

![image](./img/finalmig1.png)

Select *Yes* to shutdown the source machines, select the two servers and click *Migrate*.

![image](./img/finalmig2.png)

You can check the progress of the migration under the *Jobs* section within the navigation pane.

![image](./img/finalmig3.png)

After a few minutes the migration should be successfully completed.

![image](./img/finalmig4.png)

When you change to the *Virtual machine* section within the Azure Portal you should now see 2 additional serves in the *destination-rg* Resource Group.

![image](./img/finalmig5.png)

Change to the Azure Traffic Manager profile you've created previousley and look at the endpoints. Please note that the *fe-source* endpoint is now shown as degraded and that the *fe-dest* endpoint is shown as online.

![image](./img/finalmig6.png)

From a user perspective nothing changed. You're still able to browse the Traffic Manager profile DNS name and you will be transparently redirected to the web servers that are know running in Azure.

![image](./img/finalmig7.png)

🚀🚀🚀🚀🚀🚀 Congratulations, you've successfully migrated the frontend application to Azure.🚀🚀🚀🚀🚀🚀

### **Task 6: Cleanup**

After the successfull migration you can now stop replicating the source virtual machines. Open the [Azure Portal](https://portal.azure.com) and navigate to the previousley created Azure Migrate project. Select *Servers, databases and web apps*, make sure that the right Azure Migrate Project is selected and click *Overview* in the *Migration tools* box. In the *Azure Migrate: Migration and modernization* pane, select *Replicating machines* from the navigation pane on the left, click on the 3 dots on the end of each row of the replicating servers and select *Stop replicating*.

![image](./img/finalmig8.png)

Select *Stop replication and remove replication settings* from the drop down list and click *OK*. Repeat this step for the remaining Server.

![image](./img/finalmig9.png)

From the Traffic Manager Profile you can now also safley remove the endpoint for the source load balancer.

![image](./img/finalmig10.png)

💡 **Please note: Normaly it would be safe now to completley remove the *source-rg* Resource Group. However, we will reuse the source environment in [Challenge 6](https://github.com/microsoft/MicroHack/tree/MigrationModernizationMicroHack/03-Azure/01-03-Infrastructure/06_Migration_Datacentre_Modernization#challenge-6---modernize-with-azure) to see how Azure Migrate will help to modernize our infrastructure.**

You successfully completed challenge 5! 🚀🚀🚀

The deployed architecture now looks like the following diagram.

![image](./img/Challenge-5.jpg)

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-6/solution.md)
