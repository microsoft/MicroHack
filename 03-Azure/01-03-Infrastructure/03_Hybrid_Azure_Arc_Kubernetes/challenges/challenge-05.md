# Challenge 5 - Configure GitOps for cluster management

## Goal
Configure GitOps with Flux for cluster management. In this microhack we chose to manage Kubernetes namespaces from a Git repository as an example how GitOps can be used to centralize configuration of multiple clusters from a single source of truth.

## Actions
1. Ensure the Flux extension is installed on your Arc-enabled Kubernetes cluster.
2. Fork the MicroHack repository (public for ease of use) and clone only the required `namespaces` folder via sparse checkout.
3. Create a Flux configuration that points to the `namespaces` folder in your fork.
4. Verify the initial namespace from the repo is created automatically.
5. Add a new namespace manifest (team1) and push it to your fork.

## Success Criteria
* A Flux configuration exists and is in a healthy state for your Arc-enabled cluster.
* The initial namespace from the repository is created in the cluster.
* A second namespace (team1) appears after you push the new manifest.

## Learning Resources
* [GitOps for Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gitops-aks/gitops-blueprint-aks)
* [GitOps with Flux on Azure Arc-enabled Kubernetes clusters](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2)
* [Flux documentation - Get started](https://fluxcd.io/docs/get-started/)

## Solution - Spoilerwarning
[Solution Steps](../walkthroughs/challenge-05/solution.md)

[Next challenge](challenge-06.md) | [Back](../Readme.md)
