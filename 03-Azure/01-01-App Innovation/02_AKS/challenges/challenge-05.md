# Challenge 5 - Scaling in AKS

[Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-06.md)

## Goal 

The goal of this exercise is to learn about scaling in Kubernetes and AKS, including pod autoscaling (HPA) and cluster autoscaling. You'll understand how to handle varying workloads by adjusting the number of pod replicas or cluster nodes.

## Actions

* Manually scale your deployment to a specific number of replicas
* Configure Horizontal Pod Autoscaler (HPA) based on CPU metrics
* Test autoscaling by generating load on your application
* Enable cluster autoscaler on your AKS cluster
* Observe pod and node scaling behavior

## Success criteria

* You have successfully scaled a deployment manually
* You have configured and deployed a Horizontal Pod Autoscaler
* You can observe HPA scaling pods based on CPU utilization
* You have enabled cluster autoscaler on your node pool
* You can verify that nodes scale up/down based on resource demands

## Learning resources
* [Scale applications in AKS](https://learn.microsoft.com/en-us/azure/aks/tutorial-kubernetes-scale)
* [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
* [Cluster autoscaler in AKS](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler)
