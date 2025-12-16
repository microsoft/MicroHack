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
 
- [Challenge 1 - Create an Oracle Database@Azure (ODAA) Subscription](challenges/challenge-01.md)
- [Challenge 2 - Create Azure ODAA [Oracle Database@Azure] Database Resources](challenges/challenge-02.md)
- [Challenge 3 - Update the Oracle ADB NSG and DNS](challenges/challenge-03.md)
- [Challenge 4 - Simulate the On-Premises Environment](challenges/challenge-04.md)
- [Challenge 5 - Measure Network Performance to Your Oracle Database@Azure Autonomous Database](challenges/challenge-05.md)
- [Challenge 6 - Setup High Availability for Oracle ADB](challenges/challenge-06.md)
- [Challenge 7 - (Optional) Use Estate Explorer to visualize the Oracle ADB instance](challenges/challenge-07.md)
- [Challenge 8 -  (Optional) Integration of Azure Data Fabric with Oracle ADB](challenges/challenge-08.md)
- [Challenge 9 - (Optional) Enable Microsoft Entra ID Authentication on Autonomous AI Database](challenges/challenge-09.md)


## Solutions - Spoiler Warning
- [Solution 1 - Create an Oracle Database@Azure (ODAA) Subscription](walkthrough/challenge-01/solution-01.md)
- [Solution 2 - Create Azure ODAA [Oracle Database@Azure] Database Resources](walkthrough/challenge-02/solution-02.md)
- [Solution 3 - Update the Oracle ADB NSG and DNS](walkthrough/challenge-03/solution-03.md)
- [Solution 4 - Simulate the On-Premises Environment](walkthrough/challenge-04/solution-04.md)
- [Solution 5 - Measure Network Performance to Your Oracle Database@Azure Autonomous Database](walkthrough/challenge-05/solution-05.md)
- [Solution 6 - Setup High Availability for Oracle ADB](walkthrough/challenge-06/solution-06.md)
- [Solution 7 - (Optional) Use Estate Explorer to visualize the Oracle ADB instance](walkthrough/challenge-07/solution-07.md)
- [Solution 8 -  (Optional) Integration of Azure Data Fabric with Oracle ADB](walkthrough/challenge-08/solution-08.md)
- [Solution 9 - (Optional) Enable Microsoft Entra ID Authentication on Autonomous AI Database](walkthrough/challenge-09/solution-09.md)

 
## Contributors

<to-be-added>

