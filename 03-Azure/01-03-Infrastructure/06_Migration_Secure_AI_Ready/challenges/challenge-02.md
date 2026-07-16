# Challenge 2 - Discover Hyper-V virtual machines for migration

[Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-03.md)

## Goal 

The goal of this exercise is to...

* Set up an Azure Migrate project for Hyper-V discovery.
* Deploy and register the Azure Migrate appliance.
* Continuously discover the Hyper-V host, its VMs, and their inventory.

## Actions

* Create an Azure Migrate project.
> [!IMPORTANT]
> To create a business case, make sure to select Europe as the *Geography* for the Azure Migrate project.
* Install and register the Azure Migrate appliance on **MHBOX-AzMigSrv**.
* Connect the appliance to the Hyper-V host.
* Start continuous discovery and review the VM inventory.

## Success criteria

* You have created an Azure Migrate project.
* You have successfully deployed the Azure Migrate appliance.
* You successfully registered the Azure Migrate appliance with the Azure Migrate project.
* You have successfully configured continuous discovery for the Hyper-V host.
* You have successfully verified the discovered Windows and Ubuntu VMs and their inventory in the portal.

## Learning resources
* [Create and manage Azure Migrate projects](https://learn.microsoft.com/en-us/azure/migrate/create-manage-projects)
* [Discover Hyper-V VMs with Azure Migrate](https://learn.microsoft.com/en-us/azure/migrate/tutorial-discover-hyper-v?view=migrate)
* [Hyper-V discovery support matrix](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v?view=migrate)
