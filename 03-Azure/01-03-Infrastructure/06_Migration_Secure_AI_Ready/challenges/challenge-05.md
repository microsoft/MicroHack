# Challenge 5 - Migrate Hyper-V virtual machines to Azure

[Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-06.md)

## Goal 

The goal of this exercise is to ...

* understand the native Hyper-V migration architecture in Azure Migrate.
* test and migrate the Windows and Ubuntu web VMs.
* keep planned cutover downtime as short as possible.

## Actions

* Configure and register the Hyper-V replication provider and Recovery Services agent on the Hyper-V host.
* Select the Windows and Ubuntu VMs and enable replication.
* Review the compute, network, and disk target settings.
* Run, validate, and clean up test migrations for both VMs.
* Perform the final migration with a planned shutdown.
* Directly validate both migrated web workloads in Azure.
* Complete both migrations to stop replication.

## Success criteria

* The Windows/IIS and Ubuntu/Apache VMs are successfully replicated and test-migrated.
* Both test-migrated web workloads return HTTP success with the correct hostname, platform, and web-server details.
* Test-migration resources are cleaned up.
* Both web VMs are successfully migrated, directly validated in Azure, and completed in Azure Migrate.

## Learning resources
* [Migrate Hyper-V VMs to Azure](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v?view=migrate)
* [Hyper-V migration support matrix](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v-migration?view=migrate)
* [Hyper-V migration architecture](https://learn.microsoft.com/en-us/azure/migrate/hyper-v-migration-architecture?view=migrate)
* [Run a test migration](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v?view=migrate#run-a-test-migration)
