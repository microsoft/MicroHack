# Exercise 0: Set up the Environment

**[Home](../README.md)** - [Next Challenge Solution](01-Build-and-push-locally-solution.md)

## Task 1: Set up an Azure Container Registry with admin account

First, you have to create a [Resource Group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-cli)

The second step is to create a Container Registry. There are multiple options to achieve this, e.g. via the Azure portal or using the Azure CLI. In this challenge will use the Azure CLI:

```
az acr create `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME `
  --sku Basic `
  --admin-enabled true
```

The Resource Group and Container Registry names are global variables, you should set them in advance and replace them with the actual names.
With the
`--sku Basic`
you are setting the basic permission concept.

If you'd like to do it with the Azure Portal (or any other way) you can find a tutorial [here](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal?tabs=azure-cli).

## Task 2: Create a Container App environment for multiple container apps in West Europe Region

A Container App Environment like the Container Registry can be setup in several ways. Using the azure CLI it would be:

```
az containerapp env create `
  --name $ENVIRONMENT `
  --resource-group $RESOURCE_GROUP`
  --location "westeurope"
```

In this example we used $ACR_NAME=flightbookeracr,$RESOURCE_GROUP=ServerlessMicroservices and $ENVIRONMENT=Flightbooker-env but you are free to choose your own names.
