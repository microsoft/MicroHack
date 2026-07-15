# Walkthrough Challenge 5 - Migrate machines to Azure

[Previous Challenge Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-06/solution-06.md)

Duration: 90 minutes

## Prerequisites

Please make sure that you successfully completed [Challenge 4](../challenge-04/solution-04.md) before continuing with this challenge.

> [!IMPORTANT]
> For migrating Hyper-V VMs, the Migration and modernization tool installs software providers (Azure Site Recovery provider and Recovery Services agent) on Hyper-V hosts or cluster nodes. The Azure Migrate appliance isn't used for Hyper-V migration.

### **Task 1: Set up the software providers**

In the Azure Portal, select *Virtual machines* from the navigation pane on the left. Select the **MHBox-HV** system and log on via Azure Bastion with your credentials:

> [!NOTE]
> You can also select *Password from Azure Key Vault* under *Authentication Type* to select the secret stored in the Key Vault.

![image](./img/HVConnect.png)

Open Microsoft Edge on the Hyper-V host, navigate to the [Azure Portal](https://portal.azure.com), and log in.
In the search bar, enter *Azure Migrate* and select Azure Migrate from the list of services.

![image](./img/PrepRep1.png)

Select *All projects* from the navigation pane on the left. Your previously created Azure Migrate project should be listed. Click it to open the project.
 
![image](./img/PrepRep2.png)

Select *Migrations* from the navigation pane on the left and click *Start execution*.

![image](./img/PrepRep3.png)

Select *Azure VM* as the migration destination and *Yes, with Hyper-V* as the virtualization type. An error will indicate that no Hyper-V host has been registered yet. Click *Click here to set up* to start the registration process.

![image](./img/PrepRep3-1.png)

> [!IMPORTANT]
> **Make sure to select the correct target region. Double-check it against the destination resource group location. This can't be changed afterward.**

Click *Create resources*.

![image](./img/PrepRep4.png)

Next, download the binaries and the registration file.

![image](./img/PrepRep5.png)

Execute the *AzureSiteRecoveryProvider.exe* file to start the installation.

![image](./img/PrepRep6.png)

![image](./img/PrepRep7.png)

![image](./img/PrepRep8.png)

![image](./img/PrepRep9.png)

Register the provider with the previously downloaded registration file.

![image](./img/PrepRep10.png)

Complete the wizard and wait for the provider to be successfully registered.

![image](./img/PrepRep11.png)

Go back to the Azure Portal and finalize the registration.

> [!NOTE]
> *You might need to refresh the page.*

![image](./img/PrepRep12.png)

> [!NOTE]
> *This process might take up to 15 minutes to complete. Afterward, VM replication can be started.*

### **Task 2: Enable replication**

Once registration is complete, return to the Azure Migrate project in the Azure portal, select *Migrations* from the navigation pane on the left, and click *Start execution*.

![image](./img/Rep1.png) 

Specify the intent as shown on the diagram below:

![image](./img/Rep2.png)

Next, select the Windows and Linux systems that host the web servers with the MicroHack demo page.

> [!NOTE]
> *If the Linux server is greyed out, this is due to a compatibility issue with the latest Ubuntu image and the new Azure Migrate experience. To migrate the Ubuntu VM, change to the classic migration experience.*

![image](./img/Rep3.png)

Next, select the destination resource group, virtual network, and subnet.

![image](./img/Rep4.png)

In the *Compute* section, you can adjust target settings such as the VM size.

![image](./img/Rep5.png)

In the *Disk* section, you can adjust target settings such as the disk type.

![image](./img/Rep6.png)

Proceed to the final summary and enable replication.

![image](./img/Rep7.png)

Wait until the *Execution* stage shows *Testing*.

![image](./img/Rep8.png)

### **Task 3: Perform a test migration**

When delta replication begins, you can run a test migration for the VMs before running a full migration to Azure. We highly recommend doing this at least once for each machine before migrating it.

+ Running a test migration checks that migration will work as expected without affecting the on-premises machines, which remain operational and continue replicating.
+ A test migration simulates migration by creating an Azure VM from replicated data, usually in a nonproduction virtual network in your Azure subscription.
+ You can use the replicated test Azure VM to validate the migration, test the application, and address any issues before full migration.

Open the Azure Portal and navigate to the previously created Azure Migrate project. Select *Migrations*, and then click *Action pending* to initiate the test migration.

![image](./img/TestMig1.png)

On the new page, make sure that *Preparation* is *Completed*. Open the menu next to *Testing*, and then click *Start test migration*.

![image](./img/TestMig2.png)

Select the destination network and click *Test migration*.

![image](./img/TestMig3.png)

> [!NOTE]
> **Repeat the preceding steps for the other VM.**

From the Azure Portal, navigate to the Azure Migrate project. Select *Migrations*, and then click *In progress* under *Execution status* to follow the test migration.

![image](./img/TestMig3-1.png)

Wait until all steps are completed.

![image](./img/TestMig3-2.png)

To validate that the test migration was successful, open the Azure Portal and select *Virtual machines* from the navigation pane on the left. Additional VMs ending with *-test* were created during the test migration.

![image](./img/TestMig4.png)

Connect to the Windows VM via Azure Bastion.

![image](./img/TestMig5.png)

On the VM, open a browser and navigate to *http://localhost*. Make sure that the MicroHack Demo Web App is running as expected.

![image](./img/TestMig6.png)

After confirming that the systems work as expected, you can clean up the test migration and proceed with the final migration.

Go back to the *Migrations* section in the Azure Migrate project in the Azure Portal and click *Action pending* for the VMs on which the test migration was performed.

![image](./img/TestMig7.png)

From the *Testing* menu, select *Cleanup test migration*.

![image](./img/TestMig8.png)

Provide a comment, select *Testing is complete....*, and click *Cleanup Test* to remove all resources.

![image](./img/TestMig9.png)

> [!NOTE]
> **Repeat the preceding steps for the other VM.**

### **Task 4: Prepare the final migration**

Currently, the two servers are not published or directly accessible. After migration, the source servers will be turned off, so access to the systems must be updated. Perform the following premigration steps to keep downtime as short as possible.

#### **Task 4.1: Create a new Azure public load balancer in the destination environment**

From the Azure Portal, open the Load Balancing page, select *Load Balancer* from the navigation pane on the left, and click *Create*.

![image](./img/LB1.png)

Under *Basics*, select the *destination-rg* resource group and provide a name for the new load balancer.

![image](./img/LB2.png)

Under *Frontend IP configuration*, click *Add a frontend IP configuration* and create a new public IP address.

![image](./img/LB3.png)

Under *Backend Pools*, select *Add a backend Pool*. Provide a name and select *destination-vnet* as the virtual network.
Add *10.2.1.4* and *10.2.1.5* as the IP addresses.

> [!NOTE]
> Azure reserves the first four addresses (0-3) in each subnet address range and doesn't assign them. Azure assigns the next available address to a resource from the subnet address range. Therefore, the IP addresses assigned to the destination VMs after migration are predictable in this lab.

![image](./img/LB4.png)

Under *Inbound rules*, click *Add a load balancing rule* and create the rule as illustrated in the following diagram.

![image](./img/LB5.png)

We are already using a NAT gateway to provide outbound internet access. We don't need an outbound rule and can skip this part.

Proceed to the *Review + create* section, review your configuration, and click *Create*.

![image](./img/LB6.png)

After the load balancer has been created, return to the *Load balancing* section and select the load balancer. From the *Overview* pane, copy the *Frontend IP address*. Record the load balancer's public IP address because you will need it after migration.

![image](./img/LB7.png)

### **Task 5: Perform the final migration**

Open the [Azure Portal](https://portal.azure.com), return to the *Migrations* section in the Azure Migrate project, and click *Action pending* for the VMs to be migrated.

![image](./img/Mig1.png)

Open the *Completion* menu and select *Migrate*.

![image](./img/Mig1-1.png)


Select *Yes* to shut down the VMs on the Hyper-V host, and then click *Migrate*.

![image](./img/Mig3.png)

In the *Migrations* section of the Azure Migrate project, click *In progress* to follow the migration steps.

![image](./img/Mig4.png)

You can also click on each job to review the current status of the migration. 

![image](./img/mig5.png)

After a few minutes, the migration should complete successfully.

![image](./img/mig7.png)

On the Hyper-V host, the VMs should also be turned off.

![image](./img/mig6.png)

In the *Virtual machines* section of the Azure Portal, you should now see two additional servers in the *destination-rg* resource group.

![image](./img/mig8.png)

You should now also be able to access the web server via the previously created load balancer frontend IP.

![image](./img/mig9.png)

🚀🚀🚀🚀🚀🚀 Congratulations, you've successfully migrated the frontend application to Azure. 🚀🚀🚀🚀🚀🚀

### **Task 6: Cleanup**

After the successful migration, you can stop replicating the source virtual machines. Open the [Azure Portal](https://portal.azure.com), navigate to the previously created Azure Migrate project, select *Migrations*, and click *Completion*.

![image](./img/Clean1.png)

Select *Stop replication* from the dropdown list to remove the replication settings.

![image](./img/Clean2.png)

> [!NOTE]
> Repeat this step for the remaining server.

You successfully completed Challenge 5.

The deployed architecture now looks like the following diagram.

![image](./img/Challenge-5.jpg)

Continue to Challenge 6 to secure the migrated environment. Do not remove `destination-rg` because Challenges 6 through 8 use the migrated workload.
