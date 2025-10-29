# 🚀 Challenge 2: Create Azure ODAA [Oracle Database@Azure] Database Resources

[Back to workspace README](../../README.md)

## 🛰️ Delegated Subnet Design (Completed Reference)

- ODAA Autonomous Database can be deployed inside Azure Virtual Networks, inside  delegated subnets, delegated to Oracle Database@Azure.
- Client subnet CIDR must be between /27 and /22.
- Valid ranges must use private IPv4 addresses and must avoid the reserved 100.106.0.0/16 and 100.107.0.0/16 blocks used for the interconnect.

A more detailed description can be found here: [Oracle Documentation Oracle’s delegated subnet guidance](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-delegated-subnet-design.htm)

NOTE: For this Microhack, we already created corresponding VNets and Subnets, so no additional action is required in this step.


## 🧭 What is an Azure Delegated Subnet?

Azure delegated subnets allow you to hand over exclusive control of a subnet inside your VNet to a specific Azure service. When you delegate, the service can deploy and manage its own network resources (NICs, endpoints, routing) inside that subnet without you provisioning each resource manually. Traffic still flows privately over your VNet, and you remain in charge of higher-level constructs like NSGs and route tables.

## 🛠️ Create an ODAA Autonomous Database Instance

Please follow the instruction mentioned on the following link to create an ODAA Autonomous Database Instance inside the pre-created delegated subnet.

Use the following parameters when creating the ODAA ADB instance:

- Azure Subscription: sub-mhodaa
- Azure Resource Group: odaa-team0 # replace with your team number
- Azure Region: France Central # replace with the region used by the Azure Resource Group
- VNet: odaa-team0 # replace with your team number
- Subnet: odaa-team0 # replace with your team number

[Oracle Documentation: Create an Autonomous Database](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-autonomous-database.html)

[Back to workspace README](../../README.md)
