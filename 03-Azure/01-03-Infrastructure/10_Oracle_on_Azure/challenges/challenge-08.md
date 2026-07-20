# Challenge 8 -  (Optional) Integration of Azure Data Fabric with Oracle ADB

[Previous Challenge Solution](challenge-07.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-09.md)

## Goal 

The goal of this exercise is to integrate Oracle Autonomous Database (ADB) with Azure Data Fabric to create comprehensive data solutions that leverage both Oracle's database capabilities and Azure's data platform services. You will deploy Oracle GoldenGate for Big Data on your AKS cluster to enable data replication and integration with Azure Data Fabric.

## Actions

* Switch to the subscription where your AKS cluster is deployed and connect to the cluster
* Generate the default Helm values for the GoldenGate Big Data deployment
* Retrieve the external IP address of your nginx ingress controller
* Configure the GoldenGate Big Data Helm values file with the correct ingress hostname using the external IP address
* Deploy Oracle GoldenGate for Big Data to your AKS cluster using Helm
* Verify the deployment was successful

## Success criteria

* You have successfully connected to your AKS cluster
* You have generated and customized the GoldenGate Big Data Helm values file with the correct ingress configuration
* You have successfully deployed Oracle GoldenGate for Big Data using Helm
* The deployment status shows as "deployed" in the microhacks namespace
* You can access the GoldenGate interface through the configured ingress endpoint

## Learning resources
* [Azure Data Fabric Documentation](https://docs.microsoft.com/en-us/azure/data-factory/)
* [Oracle ADB Integration Guides](https://docs.oracle.com/en/cloud/paas/autonomous-database/)
* [Oracle GoldenGate for Big Data](https://docs.oracle.com/en/middleware/goldengate/big-data/)
* [Hybrid Data Integration Patterns](https://docs.microsoft.com/en-us/azure/architecture/)
