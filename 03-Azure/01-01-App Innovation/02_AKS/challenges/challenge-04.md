# Challenge 4 - Expose Application with Load Balancer

[Previous Challenge](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-05.md)

## Goal 

The goal of this exercise is to expose your deployed applications to the internet using Kubernetes Services and Azure Load Balancer. You'll learn about different service types and how to make your applications accessible.

## Actions

* Create a ClusterIP service to expose the backend application internally
* Create a LoadBalancer service to expose the frontend application externally
* Apply the service configurations to your cluster
* Obtain the external IP address assigned by Azure Load Balancer
* Test application accessibility from the internet

## Success criteria

* You have created a ClusterIP service for the backend application
* You have created a LoadBalancer service for the frontend application
* You can successfully access the frontend application via the external IP
* The backend service is accessible internally within the cluster
* You can verify the Azure Load Balancer created in your resource group

## Learning resources
* [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
* [Use a public load balancer in AKS](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
* [Service types in Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
