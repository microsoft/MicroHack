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

As a first step, we will Download the Microsoft Azure Backup Server (MABS) from the Azure Recovery Services Vault that we created in [challenge 1](../../Readme.md#challenge-1). 

To protect on-premises workloads, the MABS server **must be located on-premises**, and **connected to a domain**. You can run the server on a Hyper-V VM, a VMware VM, or a physical host. The recommended minimum requirements for the server hardware are two cores and 8-GB RAM. The supported operating systems are:

* Windows Server 2019 (Standard, Datacenter, Essentials) - 64 bit
* Windows Server 2016 and latest SPs (Standard, Datacenter, Essentials) - 64 bit

We will download and install the MABS in a Windows Server 2016 located in the Hyper-v server (cmhost) and joined to "contosomortgage.local" domain (cmMABS). 

* Form the server 2016 navigate to **Recovery Services Vault** in the West Europe (mh-rsv-weu) which we created in the first Challenge. Under **Backup**, select **On-Premises** and **Hyper-V Virtual Machine** and **Prepare Infrastructure**. 

![image](./img/1.png)

* In the Prepare infrastructure pane that opens, select the **Download links for Install Azure Backup Server** and **Download vault credentials** (You will use the vault credentials during registration of Azure Backup Server to the Recovery Services vault).

* **Download** the Microsoft Azure Backup Server (MABS), select all the files and **Download all the files** coming in from the Microsoft Azure Backup download page, and place all the files in the same folder.



### Task 3: Check that the server is visible in the inventory with all checks green.



Congratulations! You secured any server which is outside of Azure and onboarded via Azure Arc.

You successfully completed challenge 4! 🚀🚀🚀

