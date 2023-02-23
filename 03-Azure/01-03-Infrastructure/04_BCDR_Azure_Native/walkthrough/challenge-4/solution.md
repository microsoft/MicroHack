# Walkthrough Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc

Duration: 30 minutes

[Previous Challenge Solution](../challenge-3/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-5/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 3](../../Readme.md#challenge-3) before continuing with this challenge.

In this challenge you will learn how to protect your on-premise Hyper-V virtual machines with Microsoft Azure Backup Server (MABS). For this MicroHack, we are using Nested Virtualization (Windows server with Hyper-V role) in Azure as an emulation of the on-Premise environment (server Name: cmhost).

Actions:

* Install the Microsoft Azure Backup Server (MABS) in the on-premise infrastructure
* Add a Backup Storage to the MABS disk storage
* Register an on-premise Windows server (Windows server 2016) to the MABS
* Protect the registered VM with MABS
* Register the on-premise Hyper-V host to the MABS
* Protect two Hyper-V's VMs with MABS
* Recover a VM using the recovered vhdx from MABS

### Task 1: Install the Microsoft Azure Backup Server (MABS)

### Download the MABS

As a first step, we will download the Microsoft Azure Backup Server (MABS) from the Azure Recovery Services Vault that we created in [challenge 1](../../Readme.md#challenge-1). 

Note, to protect on-premises workloads, the MABS server **must be located on-premises**, and **connected to a domain**. You can run the server on a Hyper-V VM, a VMware VM, or a physical host. The recommended minimum requirements for the server hardware are two cores and 8-GB RAM. The supported operating systems are:

* Windows Server 2019 (Standard, Datacenter, Essentials) - 64 bit
* Windows Server 2016 and latest SPs (Standard, Datacenter, Essentials) - 64 bit

In this challenge, we will download and install the MABS in a Windows Server 2016 located in the Hyper-v server and joined to "contosomortgage.local" domain (cmMABS). 

* Form the server 2016 navigate to **Recovery Services Vault** in the West Europe (mh-rsv-weu) which we created in the first Challenge. Under **Backup**, select **On-Premises** and **Hyper-V Virtual Machine** and **Prepare Infrastructure**. 

![image](./img/mh-ch4-screenshot-01.png)

* In the **Prepare infrastructure** pane, select the **Download links for Install Azure Backup Server** and **Download vault credentials** (You will use the vault credentials during registration of Azure Backup Server to the Recovery Services vault).

![image](./img/mh-ch4-screenshot-02.png)

![image](./img/mh-ch4-screenshot-03.png)

* **Download** the Microsoft Azure Backup Server (MABS), select all the files and **Download all the files** coming in from the Microsoft Azure Backup download page, and place all the files in the same folder.

![image](./img/mh-ch4-screenshot-04.png)

![image](./img/mh-ch4-screenshot-05.png)

### Install the Azure Backup Server

* The MABS server must be domain joined and have .NET 3.51 installed. The installer will add .NET 4 during the installation if it’s not present. After you've downloaded all the files, run **System_Center_Microsoft_Azure_Backup_Server_v3.exe**. Select the **Extract** button and then select **Microsoft Azure Backup** to launch the setup wizard.

![image](./img/mh-ch4-screenshot-06.png)

* Once the extraction process complete, check the box to launch the freshly extracted setup.exe to begin installing Microsoft Azure Backup Server and select the Finish button.

![image](./img/mh-ch4-screenshot-07.png)

Check the Prerequisites to determine if the hardware and software prerequisites for Azure Backup Server have been met.

![image](./img/mh-ch4-screenshot-08.png)

![image](./img/mh-ch4-screenshot-09.png)

* The Azure Backup Server installation package comes bundled with the appropriate SQL Server binaries needed. Select the option **Install new Instance of SQL Server with this Setup** and select the Check and Install button. 

If you wish to use your own SQL server, the supported SQL Server versions are SQL Server 2014 SP1 or higher, 2016 and 2017. All SQL Server versions should be Standard or Enterprise 64-bit. Azure Backup Server won't work with a remote SQL Server instance. The instance being used by Azure Backup Server needs to be local. If you're using an existing SQL server for MABS, the MABS setup only supports the use of named instances of SQL server.

![image](./img/mh-ch4-screenshot-10.png)

![image](./img/mh-ch4-screenshot-11.png)

Provide a strong password for restricted local user accounts and select Next.

![image](./img/mh-ch4-screenshot-12.png)

![image](./img/mh-ch4-screenshot-13.png)

Then the installation happens in **phases**:

#### First Phase

The Microsoft Azure Recovery Services Agent is installed on the server. The wizard also checks for Internet connectivity. If Internet connectivity is available, you can continue with the installation. If not, you need to provide proxy details to connect to the Internet.

![image](./img/mh-ch4-screenshot-14.png)

![image](./img/mh-ch4-screenshot-15.png)

#### Second Phase

The next step is to configure the Microsoft Azure Recovery Services Agent. As a part of the configuration, you'll have to provide your vault credentials to register the machine to the Recovery Services vault. You'll also provide a passphrase to encrypt/decrypt the data sent between Azure and your premises. You can automatically generate a passphrase or provide your own minimum 16-character passphrase. Continue with the wizard until the agent has been configured.

![image](./img/mh-ch4-screenshot-16.png)

![image](./img/mh-ch4-screenshot-17.png)

#### Last Phase

Once registration of the Microsoft Azure Backup server successfully completes, the overall setup wizard proceeds to the installation and configuration of SQL Server and the Azure Backup Server components. Once the SQL Server component installation completes, the Azure Backup Server components are installed. Lastly, you will need to restart the server.

![image](./img/mh-ch4-screenshot-18.png)

![image](./img/mh-ch4-screenshot-19.png)

### Task 2: Add a Backup Storage to the Microsoft Azure Backup Server disk storage

The first backup copy is kept on storage attached to the Azure Backup Server machine. You need to add backup storage even if you plan to send data to Azure. In the current architecture of Azure Backup Server, the Azure Backup vault holds the second copy of the data while the local storage holds the first (and mandatory) backup copy.

### Create a volume on a virtual disk in a storage pool

* Add a new disk to the Azure Backup Server VM using Hyper-V manager and then select **Server Manager** of the MABS server, select **File and Storage Services** from left side panel, and select Storage Pools. Create a new **Storage Pool**. 

![image](./img/mh-ch4-screenshot-20.png)

![image](./img/mh-ch4-screenshot-21.png)

![image](./img/mh-ch4-screenshot-22.png)

![image](./img/mh-ch4-screenshot-23.png)

![image](./img/mh-ch4-screenshot-24.png)

* Create a virtual disk with simple layout, and lastly create volume in the virtual disk.

![image](./img/mh-ch4-screenshot-25.png)

![image](./img/mh-ch4-screenshot-26.png)

![image](./img/mh-ch4-screenshot-27.png)

![image](./img/mh-ch4-screenshot-28.png)

![image](./img/mh-ch4-screenshot-29.png)

![image](./img/mh-ch4-screenshot-30.png)

![image](./img/mh-ch4-screenshot-31.png)

![image](./img/mh-ch4-screenshot-32.png)

### Add volumes to Backup Server disk storage

To add a volume to Backup Server, in the **Management pane** of MABS select **Disk Storage** then rescan the storage. After rescanning the disk storage select **Add**. A list of all the volumes available to be added for Backup Server Storage appears. After available volumes are added to the list of selected volumes, you can give them a friendly name to help you manage them. To format these volumes to ReFS so Backup Server can use the benefits of Modern Backup Storage, select OK.

![image](./img/mh-ch4-screenshot-33.png)

![image](./img/mh-ch4-screenshot-34.png)

### Set up workload-aware storage (Optional)

With workload-aware storage, you can select the volumes that preferentially store certain kinds of workloads. 
You can set up workload-aware storage by using the PowerShell cmdlet Update-DPMDiskStorage, which updates the properties of a volume in the storage pool on an Azure Backup Server.

* The following screenshot shows the Update-DPMDiskStorage cmdlet in the PowerShell window. The changes you make by using PowerShell are reflected in the Backup Server Administrator Console.

![image](./img/mh-ch4-screenshot-35.png)

### Task 3: Register the Hyper-v host and a VM to MABS

### Set up the MABS protection agent on the Hyper-V server

Each server that you want to protect also needs the MABS agent installed. You can either push this out from the console or install it manually on the workload server from the MABS installation file and then register it with MABS. 

* Push the installation from console (Install agent):

![image](./img/mh-ch4-screenshot-36.png)

![image](./img/mh-ch4-screenshot-37.png)

![image](./img/mh-ch4-screenshot-38.png)

![image](./img/mh-ch4-screenshot-39.png)

![image](./img/mh-ch4-screenshot-40.png)

![image](./img/mh-ch4-screenshot-41.png)

* For the manual installation (Attach the agent), you will need to first install the agent and using the following command to add the server to the MABS: 

cd "Specify the location of the Microsoft Protection Manager"

cd "C:\Program Files\Microsoft Data Protection Manager\DPM\bin"
SetDpmServer.exe -add -dpmservername "FQDN of the MABS server"

![image](./img/mh-ch4-screenshot-42.png)

You can find the MABS protection agents in the following path if you used the default path during the instalation of MABS.

![image](./img/mh-ch4-screenshot-43.png)
  
![image](./img/mh-ch4-screenshot-44.png)
 
![image](./img/mh-ch4-screenshot-45.png)
  
![image](./img/mh-ch4-screenshot-46.png)

### Task 4: Protect a Hyper-V's virtual machine with MABS

### Create a new protection group

![image](./img/mh-ch4-screenshot-47.png)

![image](./img/mh-ch4-screenshot-48.png)

Now you are able to add a VM using the MABS protection agent which you installed in the Hyper-v host or add a server that you have already installed the MABS protection agent for it.

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

### Task 5: Recover a Virtual Machine

You can recover a VM by downloading the .vhdx file and create a new VM from it.

![image](./img/mh-ch4-screenshot-59.png)

![image](./img/mh-ch4-screenshot-60.png)

![image](./img/mh-ch4-screenshot-61.png)

![image](./img/mh-ch4-screenshot-62.png)

![image](./img/mh-ch4-screenshot-63.png)

![image](./img/mh-ch4-screenshot-64.png)

After the .vhdx file is downloaded, you can create a VM using that. It is essential to choose the same generation for the new VM as the original VM.

![image](./img/mh-ch4-screenshot-65.png)

Congratulations! You successfully completed challenge 4! 🚀🚀🚀

