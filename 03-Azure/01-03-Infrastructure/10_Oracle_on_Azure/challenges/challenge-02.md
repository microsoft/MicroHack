# Challenge 2 - Harden Oracle ADB Connectivity

[Previous Challenge Solution](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-03.md)

## Goal

The goal of this exercise is to secure connectivity between your Azure Kubernetes Service (AKS) workloads and the Oracle Database@Azure (ODAA) Autonomous Database by refining network access controls and DNS integration.

## Actions

* Map the current network flow between AKS and Oracle ADB, identifying required CIDR ranges and subscriptions involved.
* Update the Network Security Group (NSG) associated with Oracle ADB to permit traffic from the AKS virtual network without overexposing ingress.
* Review existing private DNS zones and adjust records so AKS workloads can resolve the Oracle ADB endpoints through Azure Private DNS.

## Success criteria

* You have documented the AKS virtual network CIDR and validated it against the Oracle ADB NSG rules.
* You successfully enabled secure access for AKS workloads to reach Oracle ADB using the updated NSG configuration.
* You have successfully aligned private DNS records so AKS resolves the Oracle ADB fully qualified domain names.
* You have successfully verified connectivity from an AKS workload pod without relying on public endpoints.

## Learning resources
* [Network access guidance for Oracle Database@Azure](https://learn.microsoft.com/en-us/azure/oracle/oracle-database-at-azure-networking)
* [Network DNS configuration for Oracle Database@Azure](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-dns.htm)
