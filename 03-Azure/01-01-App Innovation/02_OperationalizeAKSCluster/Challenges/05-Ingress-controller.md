# Challenge 5: Access your services via an ingress controller

[Previous Challenge](./04-Scale-up.md) - **[Home](../README.md)**

## Introduction

To now access our services from outside the cluster, we will deploy and configure an ingress controller. One of the core concepts for AKS workloads and use cases.

## Challenges

- Connect to your cluster via CLI
- Create a manifest for your ingress controller with image from NginX
- Apply your ingress manifest to your cluster
- Set up the configuration for both your ingress and WordPress container to enable access to the initial configuration screen of WordPress. Ensure that traffic is directed through the ingress controller
- Check Azure Monitor, if everthing works as expected

## Success Criteria

- Ingress Controller is deployed to cluster
- Wordpress can be configured via browser call
- All traffic between internet and cluster is routed via the ingress controller

## Learning resources

- [Ingress controller upstream source](https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-manifests/)
- [Ingress controller documentation](https://docs.nginx.com/nginx-ingress-controller/)
- [Ingress in AKS documentation](https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli)

## Solution - Spoilerwarning

Challenge 5: [Access your services via an ingress controller](../Solutionguide/05-Ingress-controller-solution.md)

# Finish

Congratulations! You finished the MicroHack Operationalize AKS Cluster. We hope you had the chance to learn about Kubernetes Clusters and how to implement them using Azure. If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!
