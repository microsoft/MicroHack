# Challenge 2 - Containerize the Application

[Previous Challenge Solution](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-03.md)

## Goal
Before the application can be deployed to a Container App, it needs to be containerized. As you already know, this means encapsulating the application code with all dependencies and required software into a container image. The images are typically stored ("pushed") in a container registry, from which they can loaded ("pulled") to be deployed into a container hosting service.

## Actions

* Create an Azure Container Registry
* Setup a new GitHub Actions workflow in the repository to build the application <br> While we will stick to the GitHub terminology and call it a workflow, in CI/CD and DevOps terms this is also known as a pipeline
* Create a Dockerfile and add it into the repository
* Add steps to the GitHub Actions workflow to containerize the application and push the image into the container registry

## Success criteria

* You have created the Azure Container Registry
* You created a new GitHub Actions workflow
* You created a workflow that pushes a deployable container image to the registry

## Learning resources

* [Creating an Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal?tabs=azure-cli)
* [Creating a GitHub Actions pipeline](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net)
* [Docker and .NET](https://learn.microsoft.com/en-us/dotnet/core/docker/introduction)
* [Azure Container Registry Build](https://github.com/marketplace/actions/azure-container-registry-build)

