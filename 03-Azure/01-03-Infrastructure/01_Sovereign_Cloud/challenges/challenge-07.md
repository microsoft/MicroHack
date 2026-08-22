# Challenge 7 - Adaptive Apps Across Sovereign Environments

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Finish](finish.md)

## Goal

Deploy one unchanged application model to two sovereign execution environments: Azure Kubernetes Service (AKS) and a private, self-managed K3s cluster representing an on-premises or edge location. Use independent [Radius](https://radapp.io/) control planes so either site can continue operating when the other site or its network connection is unavailable.

## Scenario

A trading organization operates workloads in Azure and at intermittently connected sovereign sites. Rebuilding deployment definitions for every site creates drift and makes governance difficult. The platform team wants application developers to declare the application once, while each environment retains control of its runtime, configuration, and future capability implementations.

The lab platform has already provisioned:

| Environment | Platform | Access model |
| --- | --- | --- |
| Azure | Two-node AKS with OIDC issuer, workload identity, and managed Istio | Azure-managed Kubernetes API |
| Local/edge | Single-node K3s on a private Azure VM | Kubernetes API through an Azure Bastion localhost tunnel |

> [!IMPORTANT]
> K3s runs on Azure for workshop convenience. It remains a self-managed Kubernetes distribution and represents a sovereign private-cloud or edge platform. The VM has no public IP, and no application port is opened to the internet.

## Actions

* Validate AKS and K3s, including the private Bastion access path
* Compare centralized and federated Radius control-plane models
* Install one independent Radius control plane on each Kubernetes platform
* Create a separate Radius workspace, group, and environment for each site
* Deploy the same unchanged container application model to both environments
* Inspect each independent application graph and runtime resources
* Demonstrate that K3s remains manageable without a dependency on the AKS Radius control plane

## Success criteria

* Both Kubernetes APIs return `ok`, and every node reports `Ready`
* The K3s VM has no public IP and is reached through a localhost Azure Bastion tunnel
* Radius deployments in `radius-system` are healthy on both clusters
* `ws-azure-prod` targets AKS and contains `env-azure-prod`
* `ws-local-prod` targets K3s and contains `env-local-prod`
* The same application Bicep file is deployed without modification to both environments
* Both control planes show an independent `sovereign-web` application graph
* The application is reachable through local port forwarding on each platform, one at a time
* You can explain how federated control planes support disconnected operations and how Radius recipes can later provide different implementations behind one capability contract

## Learning resources

* [What is Radius?](https://docs.radapp.io/concepts/overview/)
* [Radius application model](https://docs.radapp.io/guides/author-apps/application/overview/)
* [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
* [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
* [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/)
* [Microsoft Entra Workload ID on AKS](https://learn.microsoft.com/azure/aks/workload-identity-overview)
* [Azure Bastion native client connections](https://learn.microsoft.com/azure/bastion/connect-vm-native-client-windows)
* [Azure Arc-enabled Kubernetes overview](https://learn.microsoft.com/azure/azure-arc/kubernetes/overview)
* [Full Adaptive Apps MicroHack source](https://github.com/djong1/MicroHack/tree/djong1-adaptive-apps-microhack/03-Azure/01-01-App%20Innovation/04-adaptive-apps)

## Solution

> [!TIP]
> Attempt the challenge before opening the worked solution. Use the success criteria to decide when you are finished.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 7](../walkthrough/challenge-07/solution-07.md)

</details>