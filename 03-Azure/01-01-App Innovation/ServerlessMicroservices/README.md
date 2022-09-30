# Build a serverless microservices architecture

## Introduction and context

In this MicroHack we are going to cover the construction of a serverless microservices architecture.

Microservices are independent modules that take care of a single service, and can be independently built, verified, deployed, scaled and monitored. 
A serverless architecture is a model within cloud computing where the service provider handles the infrastructre management, so developers don't have to deal with providing servers and can focus on the code itself.
Serverless microservices combine the two concepts above. So they are independent modules deployed within a serverless  infrastructure and only run when they are needed by the application thus minimizing the cost to only what is actually used.


## Learning Objectives

In this hack you will learn how to set up a whole microservice architecture in a small scenario in your own environment. Once we deployed the basic application, we will take a look at Azure Frontdoor and more insights, on how to monitor and manage your new setup.

## Content and Challenges

* Challenge 0: [Getting started and setting up the environment](./Challenges/00-Getting-started.md)
* Challenge 1: [Build and push Microservice Images locally](./Challenges/01-Build-and-push-locally.md)
* Challenge 2: [Deploy Microservices to Azure Container App](./Challenges/02-Azure-Container-Apps.md)
* Challenge 3: [Deploy Microservices to Azure Container App via GitHub Actions](./Challenges/03-GitHub-Actions.md)
* Challenge 4: [Integrate Azure Front Door](./Challenges/04-FrontDoor.md)

## Prerequisites

* VS Code
* Azure Subscription
* Azure CLI
* Resource Group with contributor rights
* GitHub with GitHub Actions
* Docker [(with WSL2 backend)](https://docs.docker.com/desktop/windows/wsl/)

## Solution Guide

* Challenge 0: [Getting started and setting up the environment](./Solutionguide/00-Getting-started-solution.md)
* Challenge 1: [Build and push Microservice Images locally](./Solutionguide/01-Build-and-push-locally-solution.md)
* Challenge 2: [Deploy Microservices to Azure Container App](./Solutionguide/02-Azure-Container-Apps-solution.md)
* Challenge 3: [Deploy Microservices to Azure Container App via GitHub Actions](./Solutionguide/03-GitHub-Actions-solution.md)
* Challenge 4: [Integrate Azure Front Door](./Solutionguide/04-FrontDoor-solution.md)

## Contributor

Denis Kurkov <br>
Leonie Möller <br>
Maximilian Schaugg <br>

