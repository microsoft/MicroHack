# Challenge 2 - Create an AKS Cluster with ACR Integration

[Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-03.md)

## Goal 

The goal of this exercise is to create an Azure Kubernetes Service (AKS) cluster with specific configurations and integrate it with your Azure Container Registry (ACR) to enable seamless image pulling.

## Actions

* Plan your AKS cluster configuration (name, node size, node count, location)
* Create an AKS cluster using Azure CLI or Azure Portal
* Integrate the AKS cluster with your existing Azure Container Registry
* Configure kubectl to connect to your AKS cluster
* Verify cluster connectivity and node status

## Success criteria

* You have created an AKS cluster in your resource group
* You successfully integrated ACR with AKS for pulling images
* You have configured kubectl and can connect to your cluster
* You can view cluster nodes and their status using kubectl commands

## Learning resources
* [Azure Kubernetes Service documentation](https://learn.microsoft.com/en-us/azure/aks/)
* [Create an AKS cluster](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli)
* [Authenticate with Azure Container Registry from AKS](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration)
