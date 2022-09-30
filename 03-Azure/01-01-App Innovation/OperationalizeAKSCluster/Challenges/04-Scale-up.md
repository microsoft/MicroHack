# Challenge 4: Scale up your services

[Previous Challenge](./03-Azure-Monitor.md) - **[Home](../README.md)** - [Next Challenge](./05-Ingress-controller.md)

## Introduction

Since kubernetes is a hyperscaler, we need to use it as such and deploy more services. Therefor we will add some common containers from upstream to our cluster and see what happens.

## Challenges

* Connect to your cluster via CLI
* Create a manifest for a basic redis container
* Create a manifest for a basic wordpress container
* Apply your manifests to your cluster
* Scale your redis deployment up and down and try to scale up your whole cluster via your changes
* Check Azure Monitor for some insights on your infrastructure

## Success Criteria

* New containers are running smoothly in your cluster
* Note down your observations from Azure Monitor, what can you observe here and was it expected?

## Learning resources

* [Azure Scalesets](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview)
* [Kubernetes Daemonsets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
* [Redis upstream source](https://hub.docker.com/_/redis)
* [Wordpress upstream source](https://hub.docker.com/_/wordpress)
