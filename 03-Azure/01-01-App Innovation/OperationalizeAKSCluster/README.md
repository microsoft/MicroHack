# Operationalize your AKS Cluster

## Introduction and context

In this MicroHack we are going to cover some basic tasks you are facing when running an AKS cluster.

AKS - Azure Kubernetes Service (AKS) simplifies deploying a managed Kubernetes cluster in Azure by offloading the operational overhead to Azure.
As a hosted Kubernetes service, Azure handles critical tasks, like health monitoring and maintenance.
Since Kubernetes masters are managed by Azure, you only manage and maintain the agent nodes.
Thus, AKS is free; you only pay for the agent nodes within your clusters, not for the masters.

We will take some insights in fundamental operational tasks like scaling and learn how to observe our cluster with Azure Monitor.

## Learning Objectives

In this hack you will learn how to setup an AKS, how to handle daily business tasks, monitor operations and resources via Azure Monitor and access your deployments via an ingress controller.

## Content and Challenges

* Challenge 0: [Getting started](./Challenges/00-Getting-started.md)
* Challenge 1: [Setup the environment](./Challenges/01-Setup-Environment.md)
* Challenge 2: [Deploy and configure your first pods](./Challenges/02-Deploy-and-configure.md)
* Challenge 3: [Add Azure Monitor to your environment](./Challenges/03-Azure-Monitor.md)
* Challenge 4: [Scale up your services](./Challenges/04-Scale-up.md)
* Challenge 5: [Access your services via an ingress controller](./Challenges/05-Ingress-controller.md)

## Prerequisites

* VS Code
* Azure CLI
* kubectl
* terraform/bicep extension
* Azure Subscription

## Solution Guide
* Challenge 1: [Setup the environment](./Solutionguide/01-Setup-Environment-solution.md)
* Challenge 2: [Deploy and configure your first pods](./Solutionguide/02-Deploy-and-configure-solution.md)
* Challenge 3: [Add Azure Monitor to your environment](./Solutionguide/03-Azure-Monitor-solution.md)
* Challenge 4: [Scale up your services](./Solutionguide/04-Scale-up-solution.md)
* Challenge 5: [Access your services via an ingress controller](./Solutionguide/05-Ingress-controller-solution.md)

## Contributor
Maximilian Schaugg


