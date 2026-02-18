# Challenge 1 - Create Azure Container Registry and Push Images

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

## Goal 

The goal of this exercise is to create an Azure Container Registry (ACR) to store your Docker container images, then build and push container images to this registry, which will later be deployed to your AKS cluster.

## Actions

* Create an Azure Container Registry with a globally unique name
* Configure ACR to allow access and authentication
* Build Docker container images for the sample application
* Push the built images to your Azure Container Registry
* Verify that images are successfully stored in ACR

## Success criteria

* You have created an Azure Container Registry in your resource group
* You successfully authenticated to your ACR
* You have built and pushed backend and frontend container images to ACR
* You can list and view the images stored in your container registry

## Learning resources
* [Azure Container Registry documentation](https://learn.microsoft.com/en-us/azure/container-registry/)
* [Push your first image to your Azure container registry](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli)
* [ACR Tasks overview](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tasks-overview)

