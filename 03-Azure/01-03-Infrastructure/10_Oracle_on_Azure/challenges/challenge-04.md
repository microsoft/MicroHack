# Challenge 4 - Simulate the On-Premises Environment

[Previous Challenge Solution](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-05.md)

Deploy the pre-built Helm chart into AKS to install the sample Oracle database, Data Pump job, GoldenGate services, and Instant Client. Manage the shared secrets carefully and verify that data flows from the source schema into the Autonomous Database target schema.

## Actions
* Deploy of the AKS cluster with the responsible Pods, juypter notebook with CPAT, Oracle instant client and Goldengate
* Verify AKS cluster deployment 
* Check the connectivity from instant client on the ADB database and check if the SH schema from the 23 ai free edition is migrated to the SH2 schema in the ADB
* Schema the Goldengate configuration

## Sucess criteria
* Successful AKS deployment with Pods
* Successful connection from the instant client to the ADB and source database
* Successful login to Goldengate

## Learning Resources
* [Connect to an AKS cluster using Azure CLI](https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-cli),
*  [Use Helm with AKS](https://learn.microsoft.com/azure/aks/kubernetes-helm), 
*  [Oracle GoldenGate Microservices overview](https://docs.oracle.com/en/middleware/goldengate/core/23.3/gghic/oracle-goldengate-microservices-overview.html), 
*  [Oracle Data Pump overview](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/introduction-to-oracle-data-pump.html)

