# Challenge 2: Deploy and configure your first pod

[Previous Challenge](./01-Setup-Environment.md) - **[Home](../README.md)** - [Next Challenge](./03-Azure-Monitor.md)

## Introduction

Now it is time to deploy some pods in our newly deployed cluster. Therefor you will need to apply some yaml-templates to the AKS, after you connected to it. We will use some upstream containers for that!

## Challenges

* Connect to your AKS cluster via Azure CLI
* Deploy a BusyBox Container from upstream sources by creating your own manifest
* Access your BusyBox Container via kubectl

## Success Criteria

* Config for AKS merged in local kubeconfig
* BusyBox container running and viewable via kubectl
* Container was accessed via kubectl

## Learning resources

* [Connect to AKS via CLI](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli)
* [Kubernetes Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
* [Busybox upstream source](https://hub.docker.com/_/busybox)
