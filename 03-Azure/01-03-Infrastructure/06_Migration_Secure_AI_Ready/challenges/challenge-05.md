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
* Run and clean up test migrations.
* Prepare destination load balancing and cutover.
* Perform the final migration with a planned shutdown.
* Validate the migrated workloads and complete the migration to stop replication.

## Success criteria

* The Windows and Ubuntu web VMs are successfully migrated to and running in Azure.
* Both web workloads are accessible through the dedicated public load balancer.
* Test-migration resources are cleaned up, and the final migrations are completed.

## Learning resources
* [Migrate Hyper-V VMs to Azure](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v?view=migrate)
* [Hyper-V migration support matrix](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v-migration?view=migrate)
* [Hyper-V migration architecture](https://learn.microsoft.com/en-us/azure/migrate/hyper-v-migration-architecture?view=migrate)
* [Run a test migration](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v?view=migrate#run-a-test-migration)
