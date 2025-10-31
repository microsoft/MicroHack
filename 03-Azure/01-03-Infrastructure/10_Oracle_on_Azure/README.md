# 🚀 Microhack - Oracle Database @ Azure (ODAA)

## 📖 Introduction

This intro-level microhack (hackathon) helps you gain hands-on experience with Oracle Database@Azure (ODAA).

You will learn how to create and configure an Oracle Database@Azure service, deploy an Autonomous Database instance inside a delegated subnet, update network security group (NSG) and DNS settings to enable connectivity from a simulated on-premises environment, and measure network performance to the Oracle Autonomous Database instance.

## Learning Objectives

- Understand how to onboard securely to Azure and prepare an account for Oracle Database@Azure administration.
- Learn the sequence for purchasing and linking an Oracle Database@Azure subscription with Oracle Cloud Infrastructure.
- Deploy an Autonomous Database instance inside an Azure network architecture.
- Apply required networking and DNS configurations to enable hybrid connectivity between Azure Kubernetes Service and Oracle Database@Azure resources.
- Operate the provided tooling (Helm, GoldenGate, Data Pump, SQL*Plus) to simulate data replication scenarios and measure connectivity performance.

## 🎯 Challenges

- Challenge 0: **[Set Up Your User Account](./walkthrough/setup-user-account/setup-user-account.md)**
- Challenge 1: **[Create an Oracle Database@Azure (ODAA) Subscription](./walkthrough/create-odaa-subscription/create-odaa-subscription.md)**
- Challenge 2: **[Create an Oracle Database@Azure (ODAA) Autonomous Database (ADB) Instance](./walkthrough/create-odaa-adb/create-odaa-adb.md)**
- Challenge 3: **[Update the Oracle ADB NSG and DNS](./walkthrough/update-odaa-nsg-dns/update-odaa-nsg-dns.md)**
- Challenge 4: **[Simulate the On-Premises Environment](./walkthrough/onprem-ramp-up/onprem-ramp-up.md)**
- Challenge 5: **[Measure Network Performance to Your Oracle Database@Azure Autonomous Database](./walkthrough/perf-test-odaa/perf-test-odaa.md)**
 
### Challenge 0: Set Up Your User Account

Open a private browser session, sign in with the credentials you received, and register multi-factor authentication. The goal is to ensure your Azure account is ready for administrative work in the remaining challenges.

- **Reference reading:** [Sign in to the Azure portal](https://learn.microsoft.com/azure/azure-portal/azure-portal-sign-in), [Set up Microsoft Entra multi-factor authentication](https://learn.microsoft.com/azure/active-directory/authentication/howto-mfa-userdevicesettings)

### Challenge 1: Create an Oracle Database@Azure (ODAA) Subscription

Review the Oracle Database@Azure service offer, the required Azure resource providers, and the role of the OCI tenancy. By the end you should understand how an Azure subscription links to Oracle Cloud so database services can be created.

- **Reference reading:** [Oracle Database@Azure overview (Microsoft Learn)](https://learn.microsoft.com/azure/oracle/oracle-database-at-azure-overview), [Prerequisites and resource provider registration (Oracle Docs)](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaaprerequisites.htm), [Multicloud linking between Azure and OCI (Oracle Docs)](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/onboard-link.htm)

### Challenge 2: Create an Oracle Database@Azure (ODAA) Autonomous Database (ADB) Instance

Walk through the delegated subnet prerequisites, select the assigned resource group, and deploy the Autonomous Database instance with the standard parameters supplied in the guide. Completion is confirmed when the database instance shows a healthy state in the portal.

- **Reference reading:** [Delegated subnet design for ODAA (Oracle Docs)](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-delegated-subnet-design.htm), [Create an Autonomous Database in Oracle Database@Azure (Oracle Docs)](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-autonomous-database.htm)

### Challenge 3: Update the Oracle ADB NSG and DNS

Update the Network Security Group to allow traffic from the AKS environment and register the Oracle private endpoints in the AKS Private DNS zones. Validate connectivity from AKS after both security and DNS changes are applied.

- **Reference reading:** [Network security groups overview](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), [Private DNS zones in Azure](https://learn.microsoft.com/azure/dns/private-dns-privatednszone), [Oracle Database@Azure networking guidance](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-networking-overview.htm)

### Challenge 4: Simulate the On-Premises Environment

Deploy the pre-built Helm chart into AKS to install the sample Oracle database, Data Pump job, GoldenGate services, and Instant Client. Manage the shared secrets carefully and verify that data flows from the source schema into the Autonomous Database target schema.

- **Reference reading:** [Connect to an AKS cluster using Azure CLI](https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-cli), [Use Helm with AKS](https://learn.microsoft.com/azure/aks/kubernetes-helm), [Oracle GoldenGate Microservices overview](https://docs.oracle.com/en/middleware/goldengate/core/23.3/gghic/oracle-goldengate-microservices-overview.html), [Oracle Data Pump overview](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/introduction-to-oracle-data-pump.html)

### Challenge 5: Measure Network Performance to Your Oracle Database@Azure Autonomous Database

Use the Instant Client pod to run the scripted SQL latency test against the Autonomous Database and collect the round-trip results. Optionally supplement the findings with the lightweight TCP probe to observe connection setup timing.

- **Reference reading:** [Connect to Oracle Database@Azure using SQL*Plus](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-connect-sqlplus.htm), [Diagnose metrics and logs for Oracle Database@Azure](https://learn.microsoft.com/azure/oracle/oracle-database-at-azure-monitor)

<!-- - 🔌 Challenge 4: **[Do performance test from inside the AKS cluster against the Oracle ADB instance](./walkthrough/c3-perf-test-odaa.md)**
- 🦫 Challenge 5: **[Review data replication via Beaver](./walkthrough/c5-beaver-odaa.md)**
- 🏗️ Challenge 6: **[Setup High Availability for Oracle ADB](./walkthrough/c6-ha-oracle-adb.md)**
- 📊 Challenge 7: **[(Optional) Use Estate Explorer to visualize the Oracle ADB instance](./walkthrough/c7-estate-explorer-odaa.md)**
- 🧵 Challenge 8: **[(Optional) Use Azure Data Fabric with Oracle ADB](./walkthrough/c8-azure-data-fabric-odaa.md)** -->
 
## 📋 Prerequisites

- 🔧 install Azure CLI
- ⚓ install kubectl
- install Helm
- install git and clone the this repo



## Contributors
