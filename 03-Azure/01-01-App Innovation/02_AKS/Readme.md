# Azure Kubernetes Service (AKS) MicroHack

- [**MicroHack Introduction**](#microhack-introduction)
- [**MicroHack Context**](#microhack-context)
- [**Objectives**](#objectives)
- [**Prerequisites**](#prerequisites)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack Introduction

This MicroHack scenario walks through the deployment and management of Azure Kubernetes Service (AKS) with a focus on best practices and design principles. You'll work hands-on with containerized applications, learning how to deploy, expose, scale, and monitor workloads on AKS while integrating with Azure services like Azure Container Registry, Azure Backup, and Azure Managed Grafana.

This lab is not a full explanation of Kubernetes or AKS as technologies. Please consider the following articles as recommended pre-reading to build foundational knowledge:

**Required reading:**
- [Azure Kubernetes Service (AKS) documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Kubernetes core concepts for AKS](https://learn.microsoft.com/en-us/azure/aks/concepts-clusters-workloads)
- [What is Azure Container Registry?](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-intro)

**Optional (read this after completing this lab to take your learning even deeper!):**
- [Best practices for AKS](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [AKS baseline architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/baseline-aks)

# MicroHack Context

This MicroHack scenario provides hands-on experience with Azure Kubernetes Service. You'll start by creating an Azure Container Registry and pushing container images, then deploy an AKS cluster and integrate it with ACR. Throughout the challenges, you'll deploy applications, expose them using load balancers, implement scaling strategies, configure persistent storage, set up backup and restore capabilities, and monitor your cluster with Azure Managed Grafana.

# Objectives

After completing this MicroHack you will:

- Know how to build and manage an Azure Container Registry (ACR)
- Understand how to create and configure an AKS cluster with ACR integration
- Deploy containerized applications to AKS using kubectl
- Expose applications internally and externally using Kubernetes Services
- Implement horizontal pod autoscaling (HPA) and cluster autoscaling
- Configure persistent storage using Azure Disks
- Protect AKS workloads with Azure Backup
- Monitor AKS clusters and applications using Azure Managed Grafana

# Prerequisites

## General Prerequisites

**IMPORTANT:** Before starting the challenges, you must complete the prerequisites setup:

📋 **[Complete Prerequisites - Setup Jumphost](prerequisites-setup-jumphost.md)** - **Start here to set up your environment**

This prerequisite guide will help you:
- Create an Azure Resource Group for the lab
- Deploy a jumphost VM with all necessary tools pre-installed
- Configure your environment variables

In order to use the MicroHack time most effectively, ensure the prerequisite setup is completed before starting Challenge 1.

### Required Resources

- **Azure Subscription** with Contributor permissions
- **Resource Group** (created during prerequisites setup)
- **Jumphost VM** (created during prerequisites setup)
- **Azure CLI** (pre-installed on jumphost)
- **kubectl** (pre-installed on jumphost)
- **Docker** (pre-installed on jumphost)

### Permissions Required

- **Contributor** role on your Resource Group
- **Owner or Contributor** role on the subscription (for Azure Backup configuration)

# MicroHack Challenges

## Challenges

* [Challenge 1 - Create Azure Container Registry and Push Images](challenges/challenge-01.md)
* [Challenge 2 - Create an AKS Cluster with ACR Integration](challenges/challenge-02.md)
* [Challenge 3 - Deploy Applications on AKS](challenges/challenge-03.md)
* [Challenge 4 - Expose Application with Load Balancer](challenges/challenge-04.md)
* [Challenge 5 - Scaling in AKS](challenges/challenge-05.md)
* [Challenge 6 - Persistent Storage in AKS](challenges/challenge-06.md)
* [Challenge 7 - Backup and Restore with Azure Backup for AKS](challenges/challenge-07.md)
* [Challenge 8 - Monitoring with Azure Managed Grafana](challenges/challenge-08.md)
* [Finish](challenges/finish.md)

## Solutions - Spoiler Warning ⚠️

The solutions for each challenge are provided below. Try to complete each challenge on your own before looking at the solutions!

* [Solution 1 - Create Azure Container Registry and Push Images](walkthrough/solution-01.md)
* [Solution 2 - Create an AKS Cluster with ACR Integration](walkthrough/solution-02.md)
* [Solution 3 - Deploy Applications on AKS](walkthrough/solution-03.md)
* [Solution 4 - Expose Application with Load Balancer](walkthrough/solution-04.md)
* [Solution 5 - Scaling in AKS](walkthrough/solution-05.md)
* [Solution 6 - Persistent Storage in AKS](walkthrough/solution-06.md)
* [Solution 7 - Backup and Restore with Azure Backup for AKS](walkthrough/solution-07.md)
* [Solution 8 - Monitoring with Azure Managed Grafana](walkthrough/solution-08.md)

## Contributors

* Jessica Tibaldi [GitHub](https://github.com/jetiba); [LinkedIn](https://www.linkedin.com/in/jetiba/)
* Fabrice Krebs [GitHub](https://github.com/fabricekrebs); [LinkedIn](https://www.linkedin.com/in/fabricekrebs/)
