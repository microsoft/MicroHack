# Challenge 1 - Onboarding your Kubernetes Cluster

## Goal
In challenge 1 you will connect/onboard your existing K8s cluster to Azure Arc. 

## Actions
* Verify all prerequisites are in place
  * Resource Providers
  * Azure CLI extensions
  * Resource group (Name: mh-arc-k8s-<xy>)
  * Connectivity to required Azure endpoints
* Deploy the Azure Arc agent pods to your k8s cluster
* Assign permissions to view k8s resources in the Azure portal

## Success Criteria
* Your k8s cluster appears in the Azure portal under Azure Arc > Infrastructure > Kubernetes clusters and is in status "Connected". Which arc agent version is running?
* In the Azure portal below Kubernetes resources > Workloads you can see all deployments and pods running on your cluster. What arc-specific namespaces were deployed during onboarding?

## Learning Resources
* (https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/overview)
* (https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli)
* (https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/cluster-connect)
* (https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/azure-rbac)
* (https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/kubernetes-resource-view)
* (https://learn.microsoft.com/en-us/cli/azure/connectedk8s?view=azure-cli-latest)

## Solution - Spoilerwarning
[Solution Steps](../walkthroughs/challenge-01/solution.md)

[Next challenge](challenge-02.md) | [Back](../Readme.md)