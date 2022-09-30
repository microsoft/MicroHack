# Challenge 0: Getting started

**[Home](../README.md)** - [Challenge One](./01-Setup-Environment.md)

## Introduction

Kubernetes is the de facto standard for big, scalable containerized platforms today and AKS is the solution on Azure. So in this challenge we will take a look into some basic concepts of AKS and K8s in general and what can happen during daily business operating an AKS. 

## Architecture

To have a relateable scenario, we will create a basic AKS cluster setup and use some common service. They will all be pulled directly from upstream sources.

## Components

* Azure resource groups are logical containers for Azure resources. You use a single resource group to structure everything related to this solution in the Azure portal.
* Azure Key Vault is a secret store used in Azure to securly manage your keys, certificates and secrets.
* Azure Kubernetes Service is the native approach from Azure for a kubernetes PaaS solution.
* Azure Container Insights is a feature from Azure monitor to simplify monitoring and logging of AKS resources via the Azure Portal.

### Learning resources

* [AKS documentation](https://learn.microsoft.com/en-us/azure/aks/)
* [AKS best practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
