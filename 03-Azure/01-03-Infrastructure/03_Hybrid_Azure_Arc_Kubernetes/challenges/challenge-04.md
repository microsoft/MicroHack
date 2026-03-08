# Challenge 4 - Deploy SQL Managed Instance to your cluster

## Goal
In challenge 4 you will deploy Azure Arc-enabled Data Services to your cluster and create a SQL Managed Instance. This enables you to run Azure SQL services on-premises or at the edge while maintaining cloud management and control through Azure Arc.

## Actions
* Register the Microsoft.AzureArcData resource provider in your subscription
* Deploy an Azure Arc Data Controller to your Arc-enabled K8s cluster
* Create a custom location that represents your on-premises K8s cluster as a deployment target in Azure
* Deploy a SQL Managed Instance to your cluster through the Arc Data Controller
* Connect to the SQL Managed Instance and query the database version

## Success Criteria
* The Azure Arc Data Controller is successfully deployed and visible in the Azure portal under your resource group
* A SQL Managed Instance resource appears in Azure portal with status "Ready"
* In your Kubernetes cluster, you can see the SQL MI pods running in the custom location namespace
* You can successfully connect to the SQL Managed Instance using the master node's public IP and the assigned NodePort
* You can execute a test query (e.g., `SELECT @@VERSION`) and see the query result

## Learning Resources
* [Deploy a SQL Managed Instance enabled by Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/data/create-sql-managed-instance)
* [Azure Arc-enabled data services overview](https://learn.microsoft.com/en-us/azure/azure-arc/data/overview)
* [What is Azure Arc-enabled SQL Managed Instance?](https://learn.microsoft.com/en-us/azure/azure-arc/data/managed-instance-overview)
* [Custom locations on Azure Arc-enabled Kubernetes](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/custom-locations)
* [Azure Arc Data Controller deployment](https://learn.microsoft.com/en-us/azure/azure-arc/data/create-data-controller)

## Solution - Spoilerwarning
[Solution Steps](../walkthroughs/challenge-04/solution.md)

[Next challenge](challenge-05.md) | [Back](../Readme.md)