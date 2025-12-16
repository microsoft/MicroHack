# Challenge 3 - Deploy Applications on AKS

[Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-04.md)

## Goal 

The goal of this exercise is to deploy containerized applications to your AKS cluster using images from your Azure Container Registry. You'll learn to deploy applications using kubectl commands and understand Kubernetes deployments.

## Actions

* Verify that your ACR images are available and accessible
* Create Kubernetes deployment manifests for your applications
* Deploy backend and frontend applications to your AKS cluster
* Verify that pods are running successfully
* Check application logs and troubleshoot any deployment issues

## Success criteria

* You have deployed backend application from your ACR to AKS
* You have deployed frontend application from your ACR to AKS
* All pods are running successfully (verify with kubectl get pods)
* You can view and inspect the deployments and their status
* You can access pod logs to verify application behavior

## Learning resources
* [Deploy an application to AKS](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#deploy-the-application)
* [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
* [kubectl cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
