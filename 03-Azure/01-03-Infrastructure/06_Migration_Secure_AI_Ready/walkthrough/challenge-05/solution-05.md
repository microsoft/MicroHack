# Walkthrough Challenge 5 - Migrate Hyper-V virtual machines to Azure

[Previous Challenge Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-06/solution-06.md)

Duration: 90 minutes

## Prerequisites

Please make sure that you successfully completed [Challenge 4](../challenge-04/solution-04.md) before continuing with this challenge.

> [!IMPORTANT]
> Native Hyper-V migration uses host-installed replication components: the Azure Site Recovery provider and Recovery Services agent. Install them on the Hyper-V host or cluster nodes. Nothing is installed in the guest VMs, and the Azure Migrate appliance isn't used for migration.

### **Task 1: Configure and register the Hyper-V replication providers**

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

On *Specify intent*, select *Servers or virtual machines (VMs)* as the workload and *Azure VM* as the destination. Under *How will you select workloads*, select *From replication provider (Hyper-V)*, and then use the link provided to start the replication-provider setup.

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

Next, select both web VMs: **MHBox-Win2K22** and **MHBox-Ubuntu-01**. Enable replication for both so that either workload can be selected in Challenges 7 and 8.

> [!NOTE]
> *If either VM isn't available for selection, verify the Hyper-V provider registration, confirm the VM appears in inventory, and review the current [Hyper-V migration support matrix](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v-migration?view=migrate) before continuing.*

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

Connect to each test VM via Azure Bastion.

![image](./img/TestMig5.png)

On the Windows VM, open a browser and navigate to *http://localhost*. Confirm that the dashboard shows the VM hostname, `Windows Server 2022`, and `IIS`.

On the Ubuntu VM, run the following commands:

```bash
curl --fail --silent --show-error --head http://localhost
curl --fail --silent --show-error http://localhost | grep -E 'mhbox-ubuntu-01|Ubuntu Linux|Apache'
```

The first command must return HTTP success. The second command must show the Ubuntu hostname, `Ubuntu Linux`, and `Apache`.

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

### **Task 4: Perform the final migration**

After validating and cleaning up both test migrations, proceed with the planned cutover. The source VMs will be shut down during migration to keep the final replicated state consistent.

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

Connect to both migrated VMs through Azure Bastion and validate each workload directly.

On **MHBox-Win2K22**, open a browser and navigate to *http://localhost*. Confirm that the dashboard returns HTTP success, its hostname matches the migrated Windows VM, and it shows `Windows Server 2022` and `IIS`.

On **MHBox-Ubuntu-01**, run the following commands:

```bash
curl --fail --silent --show-error --head http://localhost
curl --fail --silent --show-error http://localhost | grep -E 'mhbox-ubuntu-01|Ubuntu Linux|Apache'
```

The first command must return HTTP success. The second command must show the Ubuntu hostname, `Ubuntu Linux`, and `Apache`. Validating the VMs separately confirms that both migrated workloads are healthy.

🚀🚀🚀🚀🚀🚀 Congratulations, you've successfully migrated both web workloads to Azure. 🚀🚀🚀🚀🚀🚀

### **Task 5: Complete the migration**

After validating both migrated web VMs, complete the migration to stop replication and clean up each VM's replication state. Open the [Azure Portal](https://portal.azure.com), navigate to the Azure Migrate project, select *Migrations*, and open each migrated VM from the *Completion* stage.

![image](./img/Clean1.png)

Under *Completion*, select *Complete migration*. Repeat this action for both **MHBox-Win2K22** and **MHBox-Ubuntu-01**.

> [!NOTE]
> In some Azure Migrate portal views, the equivalent action is labeled *Stop replication*.

![image](./img/Clean2.png)

> [!NOTE]
> Completing migration stops replication for the source VM and removes its replication-state information. Confirm that the migrated Azure VM is healthy before completing this action.

You successfully completed Challenge 5.

Continue to Challenge 6 to secure the migrated environment. Do not remove `destination-rg` because Challenges 6 through 8 use the migrated workload.
