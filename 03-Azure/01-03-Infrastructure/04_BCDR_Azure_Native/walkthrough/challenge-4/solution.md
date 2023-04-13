# Walkthrough Challenge 4 - Protect to Azure with Azure Backup & Restore

Duration: 90 minutes (without setting up Nested Virtualization)

[Previous Challenge Solution](../challenge-3/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-5/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 3](../../Readme.md#challenge-3) before continuing with this challenge.

This challenge is kind of special because it is not in the flow of the other challenges because you are not looking anymore to the cloud native and "protect in Azure" perspective. It is more the view from an existing on-prem environment and you are trying to protect you resources with the perspective "protect to Azure". 

- If you want to setup your own environment with Nested Virtualization you can use the following link: 
    - [Template virtual machine in Azure Lab Services](https://learn.microsoft.com/en-us/azure/lab-services/how-to-enable-nested-virtualization-template-vm-using-script) 
- If you are intersted in a more detailed scenario and you want to learn more about Migration in general you can also use the official openhack environment. But this is not part of this MicroHack: 
    - [Official OpenHack Migration environment](https://github.com/microsoft/OpenHack/blob/main/byos/migration/deployment.md)


💡 If there is no time or knowledge to setup Nested Virtualization during this setup of the MicroHack you can also move on to the next challenge and jump back to this challenge after the MicroHack. 

## Goal

* In this challenge you will learn how to protect your on-premise Hyper-V virtual machines with Microsoft Azure Backup Server (MABS). 
* Understand and leverage the proven tools like Azure Backup Server in you own environment or in a Hyper-V environment that you can create yourself before the MicroHack. For detailed information how to set up Nested Virtualization see [Prerequisites](../challenge-4/solution.md#prerequisites). 

Actions:

* Install the Microsoft Azure Backup Server (MABS) in the on-premise infrastructure
* Add a Backup Storage to the MABS disk storage
* Register an on-premise Windows server (Windows server 2016) and the on-premise Hyper-V host to the MABS
* Protect the registered VM with MABS
* Recover a Virtual Machine using MABS backup

### Task 1: Install the Microsoft Azure Backup Server (MABS)

### Download the MABS

As a first step, we will download the Microsoft Azure Backup Server (MABS) from the Azure Recovery Services Vault that we created in [challenge 1](../../Readme.md#challenge-1). 

**Note:** to protect on-premises workloads, the MABS server **must be located on-premises**, and **connected to a domain**. You can run the MABS server on a Hyper-V VM, a VMware VM, or a physical host. The recommended minimum requirements for the server hardware are two cores and 8-GB RAM. The supported operating systems are:

* Windows Server 2019 (Standard, Datacenter, Essentials) - 64 bit
* Windows Server 2016 and latest SPs (Standard, Datacenter, Essentials) - 64 bit

In this challenge, we will download and install the MABS in a Windows Server 2016 located on the Hyper-v server that is joined to "contosomortgage.local" domain. 

* From the server 2016 navigate to **Recovery Services Vault** in the West Europe (mh-rsv-weu) which we created in the first Challenge. Under **Backup**, select **On-Premises** and **Hyper-V Virtual Machine** and **Prepare Infrastructure**. 

![image](./img/mh-ch4-screenshot-01.png)

* In the **Prepare infrastructure** pane, select the **Download links for Install Azure Backup Server** and **Download vault credentials** (You will use the vault credentials during registration of Azure Backup Server to the Recovery Services vault).

![image](./img/mh-ch4-screenshot-02.png)

![image](./img/mh-ch4-screenshot-03.png)

* **Download** the Microsoft Azure Backup Server (MABS), select all the files and **Download all the files** coming in from the Microsoft Azure Backup download page, and place all the files in the same folder.

![image](./img/mh-ch4-screenshot-04.png)

![image](./img/mh-ch4-screenshot-05.png)

### Install the Microsoft Azure Backup Server

**Note:** The MABS server must be domain joined and have .NET 3.51 installed. The installer will add .NET 4 during the installation if it’s not present. 

* After you've downloaded all the files, run **System_Center_Microsoft_Azure_Backup_Server_v3.exe**. Select the **Extract** button and then select **Microsoft Azure Backup** to launch the setup wizard.

![image](./img/mh-ch4-screenshot-06.png)

* Once the extraction process complete, check the box to launch the freshly extracted setup.exe to begin installing Microsoft Azure Backup Server and select the finish button.

![image](./img/mh-ch4-screenshot-07.png)

* Check the Prerequisites to determine if the hardware and software prerequisites for Azure Backup Server have been met.

![image](./img/mh-ch4-screenshot-08.png)

![image](./img/mh-ch4-screenshot-09.png)

* The Azure Backup Server installation package comes bundled with the appropriate SQL Server binaries needed. Select the option **Install new Instance of SQL Server with this Setup** and select the Check and Install button. 

**Note:** If you wish to use your own SQL server, the supported SQL Server versions are SQL Server 2014 SP1 or higher, 2016 and 2017. All SQL Server versions should be Standard or Enterprise 64-bit. Azure Backup Server won't work with a remote SQL Server instance. The instance being used by Azure Backup Server needs to be local. If you're using an existing SQL server for MABS, the MABS setup only supports the use of named instances of SQL server.

![image](./img/mh-ch4-screenshot-10.png)

![image](./img/mh-ch4-screenshot-11.png)

* Provide a strong password for restricted local user accounts and select Next.

![image](./img/mh-ch4-screenshot-12.png)

![image](./img/mh-ch4-screenshot-13.png)

**Note:** The installation happens in 3 **phases** as follow:

* #### First Phase

The Microsoft Azure Recovery Services Agent is installed on the server. The wizard also checks for Internet connectivity. If Internet connectivity is available, you can continue with the installation. If not, you need to provide proxy details to connect to the Internet.

![image](./img/mh-ch4-screenshot-14.png)

![image](./img/mh-ch4-screenshot-15.png)

* #### Second Phase

The next step is to configure the Microsoft Azure Recovery Services Agent. As a part of the configuration, you'll have to provide your vault credentials to register the machine to the Recovery Services vault. You'll also provide a passphrase to encrypt/decrypt the data sent between Azure and your premises. You can automatically generate a passphrase or provide your own minimum 16-character passphrase. Continue with the wizard until the agent has been configured.

![image](./img/mh-ch4-screenshot-16.png)

![image](./img/mh-ch4-screenshot-17.png)

* #### Last Phase

Once registration of the Microsoft Azure Backup server successfully completes, the overall setup wizard proceeds to the installation and configuration of SQL Server and the Azure Backup Server components. Once the SQL Server component installation completes, the Azure Backup Server components are installed. Lastly, you will need to restart the server.

![image](./img/mh-ch4-screenshot-18.png)

![image](./img/mh-ch4-screenshot-19.png)

### Task 2: Add a Backup Storage to the Microsoft Azure Backup Server disk storage

The first backup copy is kept on storage attached to the Azure Backup Server machine. You need to add backup storage even if you plan to send data to Azure. In the current architecture of Azure Backup Server, the Azure Backup vault holds the second copy of the data while the local storage holds the first (and mandatory) backup copy.

### Create an NTFS volume(s) in the MABS server

![image](./img/mh-ch4-screenshot-20.png)

![image](./img/mh-ch4-screenshot-21.png)

![image](./img/mh-ch4-screenshot-22.png)

![image](./img/mh-ch4-screenshot-23.png)

![image](./img/mh-ch4-screenshot-24.png)

![image](./img/mh-ch4-screenshot-25.png)

### Add volume(s) to Backup Server disk storage

To add a volume to Backup Server, in the **Management pane** of MABS select **Disk Storage** then rescan the storage. After rescanning the disk storage, select **Add**. A list of all the volume(s) available to be added for Backup Server Storage appears. After available volume(s) are added to the list of selected volume(s), you can give them a friendly name to help you manage them. MABS will format the volume(s) to ReFS so Backup Server can use the benefits of Modern Backup Storage, select OK.

![image](./img/mh-ch4-screenshot-26.png)

![image](./img/mh-ch4-screenshot-27.png)

![image](./img/mh-ch4-screenshot-28.png)

![image](./img/mh-ch4-screenshot-29.png)

### Set up workload-aware storage (Optional)

With workload-aware storage, you can select the volume(s) that preferentially store certain kinds of workloads.

You can set up workload-aware storage by using the PowerShell cmdlet Update-DPMDiskStorage, which updates the properties of a volume in the storage pool on an Azure Backup Server.

* The following screenshot shows the Update-DPMDiskStorage cmdlet in the PowerShell window. The changes you make by using PowerShell are reflected in the Backup Server Administrator Console.

![image](./img/mh-ch4-screenshot-30.png)

### Task 3: Register the Hyper-v host and a VM to MABS

**Note:** Each server that you want to protect also needs the MABS agent installed. You can either push this out from the console or install it manually on the workload server from the MABS installation file and then register it with MABS. 

### Set up the MABS protection agent on the Hyper-V server

* we will Push the installation from console (Install agents) for the Hyper-v server.

![image](./img/mh-ch4-screenshot-36.png)

![image](./img/mh-ch4-screenshot-37.png)

![image](./img/mh-ch4-screenshot-38.png)

![image](./img/mh-ch4-screenshot-39.png)

![image](./img/mh-ch4-screenshot-40.png)

![image](./img/mh-ch4-screenshot-41.png)

### Install the MABS protection agent on a Windows Server

For Installing the agent manually (Attach the agents), you will need to first install the agent. 

* You can find the MABS protection agents in the following path if you used the default path during the instalation of MABS:

![image](./img/mh-ch4-screenshot-43.png)

* When the protection agent is installed use the following commands to add the server to the MABS: 

cd "Specify the location of the Microsoft Protection Manager" 

SetDpmServer.exe -add -dpmservername "FQDN of the MABS server"

![image](./img/mh-ch4-screenshot-42.png)
  
![image](./img/mh-ch4-screenshot-44.png)
 
![image](./img/mh-ch4-screenshot-45.png)
  
![image](./img/mh-ch4-screenshot-46.png)

### Task 4: Protect a Hyper-V's virtual machine with MABS

### Create a new protection group

![image](./img/mh-ch4-screenshot-47.png)

![image](./img/mh-ch4-screenshot-48.png)

Now that the MABS protection agent is installed both in the Hyper-v host and a windows server, you can protect the VMs located in the Hyper-v host or the server on which you installed the protection agent independently.

![image](./img/mh-ch4-screenshot-49.png)

![image](./img/mh-ch4-screenshot-50.png)

![image](./img/mh-ch4-screenshot-51.png)

![image](./img/mh-ch4-screenshot-52.png)

![image](./img/mh-ch4-screenshot-53.png)

![image](./img/mh-ch4-screenshot-54.png)

![image](./img/mh-ch4-screenshot-55.png)

![image](./img/mh-ch4-screenshot-56.png)

![image](./img/mh-ch4-screenshot-57.png)

You will be able to check the online protection data inside the Azure Recovery Services Vault.

![image](./img/mh-ch4-screenshot-58.png)

### Task 5: Recover a Virtual Machine using MABS backup

MABS supports three recovery options for a VM backups:
* Recover to original instance
* Recover as virtual machine to any host
* Copy to a network folder

Given that we are using a test environment and there is just one host, we are using the first option.

![image](./img/mh-ch4-screenshot-59.png)

![image](./img/mh-ch4-screenshot-60.png)

![image](./img/mh-ch4-screenshot-61.png)

![image](./img/mh-ch4-screenshot-62.png)

![image](./img/mh-ch4-screenshot-63.png)

The server is now recovered to its original location.

Congratulations! You successfully completed challenge 4! 🚀🚀🚀

