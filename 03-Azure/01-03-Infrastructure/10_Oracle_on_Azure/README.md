![ODAA microhack logo](media/logo_ODAA_microhack_1900x300.jpg)

# 🚀 Microhack - Oracle Database @ Azure (ODAA)

## 📖 Introduction

This intro-level microhack (hackathon) helps you gain hands-on experience with Oracle Database@Azure (ODAA).

### What is Oracle Database at Azure
Oracle Database@Azure (ODAA) is the joint Oracle–Microsoft managed service that delivers different Database services - see [ODAA deployed Azure regions](https://apexadb.oracle.com/ords/r/dbexpert/multicloud-capabilities/multicloud-regions?session=412943632928469) running on Oracle infrastructure colocated in Azure regions while exposing native Azure management, networking, billing, integration with Azure Key Vault, Entra ID or Azure Sentinel. This microhack targets the first-tier partner solution play focussed on Autononmous database because Microsoft designates ODAA as a strategic, co-sell priority workload; the exercises give partner architects the end-to-end skills—subscription linking, delegated networking, hybrid connectivity, and performance validation—needed to confidently deliver that priority scenario for customers with Oracle related workloads in Azure.

### What You Will Learn in the MicroHack
You will learn how to create and configure an Autonomous Database shared of the offered Oracle Database@Azure services, how to deploy an Autonomous Database instance inside an Azure delegated subnet, update network security group (NSG) and DNS settings to enable connectivity from a simulated on-premises environment, and measure network performance to the Oracle Autonomous Database instance. To make the microhack more realistic we will deploy the Application layer (AKS) and the Data layer (ODAA) in 2 different subscription to simulate a hub & spoke architecture. The following picture shows highlevel the architecture of the microhack.

![ODAA microhack architecture](media/overivew%20deployment.png)

Furthermore we will address the integration of ODAA into the existing Azure native services and howto use Goldengate for migrations to ODAA and integration into Azure Fabric. 

## Learning Objectives

- Understand how to onboard securely to Azure and prepare an account for Oracle Database@Azure administration.
- Learn the sequence for purchasing and linking an Oracle Database@Azure subscription with Oracle Cloud Infrastructure.
- Deploy an Autonomous Database instance inside an Azure network architecture and the required preparations.
- Apply required networking and DNS configurations to enable hybrid connectivity between Azure Kubernetes Service and Oracle Database@Azure resources.
- Operate the provided tooling (Helm, GoldenGate, Data Pump, SQL*Plus) to simulate data replication scenarios and measure connectivity performance.
<br>
<br>
- <b>Optional</b> available session is the integration of Oracle Database at Azure databases into the Azure Fabric to have a holistic view on business data including the realization of a central data governance. 
- <b>Optional</b> available session is the integration of the deployed ADB via OAuth v2 tokens with the Azure Entra ID

## 📋 Prerequisites

- Powershell Terminal
- 🔧 install Azure CLI
- ⚓ install kubectl
- install Helm
- install git and clone the this repo

## 🎯 Challenges
 
### Challenge 0: Set Up Your User Account

Before we start with the Microhack you should have 3 passwords:
1. You User with the initial password for the registration, which you have to change during the registration
   
2. The password you need to use for admin user of the ADB deployment - <font color=red>Don't use different passwords</font>
3. The password you need to use for the AKS cluster deployment  - <font color=red>Don't use different passwords</font>


Open a private browser session or create an own browser profile to sign in with the credentials you received, and register multi-factor authentication. In a first check you have to verify if the two resource groups for the hackathon are created.
<br>
The goal is to ensure your Azure account is ready for administrative work in the remaining challenges.

#### Actions
* Enable the multi factor authentication (MFA)
* Login into the Azure portal with the assigned User
* Verify if the ODAA and AKS resource group including resources are available
* Verfity the users roles
  

#### Sucess criteria
* Download the Microsoft authenticator app on your mobile phone
* Enable MFA for a successful Login
* Check if the resource groups for the aks and ODAA are available and contains the resources. 
* Check if the assigned user have the required roles in both resource groups.

#### Learning Resources
* [Sign in to the Azure portal](https://learn.microsoft.com/azure/azure-portal/azure-portal-sign-in), 
* [Set up Microsoft Entra multi-factor authentication](https://learn.microsoft.com/azure/active-directory/authentication/howto-mfa-userdevicesettings)
* [Groups and roles in Azure](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/oaagroupsroles.htm)

#### Solution
* Challenge 0: [Set Up Your User Account](./walkthrough/setup-user-account/setup-user-account.md)

<br>
<hr>

### Challenge 1: Create an Oracle Database@Azure (ODAA) Subscription

Review the Oracle Database@Azure service offer, the required Azure resource providers, and the role of the OCI tenancy. By the end you should understand how an Azure subscription links to Oracle Cloud so database services can be created.

#### Actions
* Move to the ODAA marketplace side. The purchasing is already done, but checkout the implementation of ODAA on the Azure side.
* Access the OCI console via the pre defined federation implementation
* Check if the required Azure resource providers are enabled
  

#### Sucess criteria
* Search for the Oracle Database at Azure 
* Make yourself familar with the available services of ODAA and how to purchase ODAA

#### Learning Resources
* [ODAA in Azure an overview](https://www.oracle.com/cloud/azure/oracle-database-at-azure/)
* [Enhanced Networking for ODAA](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan)

#### Solution
* Challenge 1: [Create an Oracle Database@Azure (ODAA) Subscription](./walkthrough/create-odaa-subscription/create-odaa-subscription.md)


<br>
<hr>



### Challenge 2: Create an Oracle Database@Azure (ODAA) Autonomous Database (ADB) Instance

Walk through the delegated subnet prerequisites, select the assigned resource group, and deploy the Autonomous Database instance with the standard parameters supplied in the guide. Completion is confirmed when the database instance shows a healthy state in the portal.

#### Actions
* Verify that a delegated subnet of the upcoming ADB deployment is available
* Deploy the ADB in the previous created subnet 
  

#### Sucess criteria
* Delegated Subnet is available
* ADB shared is successfully deployed

#### Learning Resources
* [How to provision an Oracle ADB in Azure](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-provision-autonomous-database)
* [Deploy an ADB in Azure](https://docs.oracle.com/en/solutions/deploy-autonomous-database-db-at-azure/index.html)

#### Solution
* Challenge 2: [Create an Oracle Database@Azure (ODAA) Autonomous Database (ADB) Instance](./walkthrough/create-odaa-adb/create-odaa-adb.md)

### Challenge 3: Update the Oracle ADB NSG and DNS

Update the Network Security Group to allow traffic from the AKS environment and register the Oracle private endpoints in the AKS Private DNS zones. Validate connectivity from AKS after both security and DNS changes are applied.

#### Actions
* Set the NSG of the CIDR on the OCI side, to allow Ingress from the AKS on the ADB
* Extract the ODAA FQDN and IP Address and assign them to the Azure Private DNS Zones linked to the AKS VNet.  

#### Sucess criteria
* Set the NSG of the CIDR on the OCI side, to allow Ingress from the AKS on the ADB
* DNS is setup correctly. <font color=red><b>Important:</b> Without a working DNS the next Challenge will failed.</font>

#### Learning Resources
* [Network security groups overview](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview),
* [Private DNS zones in Azure](https://learn.microsoft.com/azure/dns/private-dns-privatednszone), 
* [Oracle Database@Azure networking guidance](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-networking-overview.htm)

#### Solution
* Challenge 3: [Update the Oracle ADB NSG and DNS](./walkthrough/update-odaa-nsg-dns/update-odaa-nsg-dns.md)

### Challenge 4: Simulate the On-Premises Environment

Deploy the pre-built Helm chart into AKS to install the sample Oracle database, Data Pump job, GoldenGate services, and Instant Client. Manage the shared secrets carefully and verify that data flows from the source schema into the Autonomous Database target schema.

#### Actions
* Deploy of the AKS cluster with the responsible Pods, juypter notebook with CPAT, Oracle instant client and Goldengate
* Verify AKS cluster deployment 
* Check the connectivity from instant client on the ADB database and check if the SH schema from the 23 ai free edition is migrated to the SH2 schema in the ADB
* Schema the Goldengate configuration

#### Sucess criteria
* Successful AKS deployment with Pods
* Successful connection from the instant client to the ADB and source database
* Successful login to Goldengate

#### Learning Resources
* [Connect to an AKS cluster using Azure CLI](https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-cli),
*  [Use Helm with AKS](https://learn.microsoft.com/azure/aks/kubernetes-helm), 
*  [Oracle GoldenGate Microservices overview](https://docs.oracle.com/en/middleware/goldengate/core/23.3/gghic/oracle-goldengate-microservices-overview.html), 
*  [Oracle Data Pump overview](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/introduction-to-oracle-data-pump.html)

#### Solution
* Challenge 4: [Simulate the On-Premises Environment](./walkthrough/onprem-ramp-up/onprem-ramp-up.md)

<br>
<hr>


### Challenge 5: Measure Network Performance to Your Oracle Database@Azure Autonomous Database

Use the Instant Client pod to run the scripted SQL latency test against the Autonomous Database and collect the round-trip results. Optionally supplement the findings with the lightweight TCP probe to observe connection setup timing.

#### Actions
* Login to the instant client and execute a first performance test from the aks cluster against the deployed ADB

#### Sucess criteria
* Successful login on the ADB via the instant client
* Sucdessful execution of the available performance scripts

#### Learning Resources
* [Connect to Oracle Database@Azure using SQL*Plus](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-connect-sqlplus.htm), 
* [Diagnose metrics and logs for Oracle Database@Azure](https://learn.microsoft.com/azure/oracle/oracle-database-at-azure-monitor)

#### Solution
* Challenge 5: [Measure Network Performance to Your Oracle Database@Azure Autonomous Database](./walkthrough/perf-test-odaa/perf-test-odaa.md)

<!-- - 🔌 Challenge 4: **[Do performance test from inside the AKS cluster against the Oracle ADB instance](./walkthrough/c3-perf-test-odaa.md)**
- 🦫 Challenge 5: **[Review data replication via Beaver](./walkthrough/c5-beaver-odaa.md)**
- 🏗️ Challenge 6: **[Setup High Availability for Oracle ADB](./walkthrough/c6-ha-oracle-adb.md)**
- 📊 Challenge 7: **[(Optional) Use Estate Explorer to visualize the Oracle ADB instance](./walkthrough/c7-estate-explorer-odaa.md)**
- 🧵 Challenge 8: **[(Optional) Use Azure Data Fabric with Oracle ADB](./walkthrough/c8-azure-data-fabric-odaa.md)** -->
 
## Contributors

<to-be-added>

