# Challenge 2: Deploy Microservices to Azure Container App

[Previous Challenge Solution](01-Build-and-push-locally-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](03-GitHub-Actions-solution.md)

## Task 1: Create Container Apps for each microservice with the images from the ACR


You can create a container app with the Azure portal or with the Azure CLI.

For the backend your CLI code should look something like this: 
```
az containerapp create `
  --name flightbooker-backend `
  --resource-group $RESOURCE_GROUP `
  --environment $CONTAINERAPPS_ENVIRONMENT `
  --image "$ACR_NAME.azurecr.io/Flightbooker/flightbooker-backend"`
  --target-port 3000`
  --ingress 'internal' `
  --query properties.configruation.ingress.fqdn
```
The frontend deployment would look like this:
```
az containerapp create `
  --name flightbooker-frontend `
  --resource-group $RESOURCE_GROUP`
  --environment $CONTAINERAPPS_ENVIRONMENT`
  --image "$ACR_NAME.azurecr.io/Flightbooker/flightbooker-frontend"`
  -- registry-server "$ACR_NAME.azurecr.io"`
  --env-vars BackendEnvVar=backendURL`
  --target-port 5173`
  --ingress 'external' `
  --query properties.configruation.ingress.fqdn
```

To deploy the apps with the portal, take a look [here](https://learn.microsoft.com/en-us/azure/container-apps/get-started-existing-container-image-portal?pivots=container-apps-private-registry).

For a method using a service principal and key vault, you can find a solution [here](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-using-azure-container-registry).

After deployment you can copy the Application URL (FQDN) of the frontend container app and open it in your browser and you should be able to browse the frontend web app.

## Task 3: Setup basic Security

If you set up the backend ingress to "internal", it won't be reachable from the public internet but only from applications deployed within your Azure Container Environment.

## Task 4: Try dapr locally

Dapr is already integrated in the FLightbooker App. To see if it runs on your local machine you first need to install the Dapr CLI. <br>
Open the PowerShell console as an administrator and run the following command: <br>
`powershell -Command "iwr -useb https://raw.githubusercontent.com/dapr/cli/master/install/install.ps1 | iex"`
<br>
Verify that the dapr CLI is installed by restarting the PowerShell console and run the following command:<br> `dapr` <br>
To initialize dapr run <br>
`dapr init` <br>
on the PowerShell console as administrator.
After that you can use the start_frontend and start_backend script in the repository to start your back- and frontend with dapr. 

## Task 5: Activate dapr in your Container Apps
Now back to azure: <br>
So far dapr was not enabled on the Azure Container Apps we provisioned. You can check this in the Portal and it should look something like this: 
![dapr-disabled](../Images/dapr-disabled.png)
<br>
To enable dapr for both Apps, run the following commands:

```
az containerapp dapr enable --name "flightbooker-backend" `
  --resource-group $RESOURCE_GROUP`
  --dapr-app-id "flightbooker-backend"`
  --dapr-app-port 3501

az containerapp dapr enable --name "flightbooker-frontend" `
  --resource-group $RESOURCE_GROUP`
  --dapr-app-id "flightbooker-frontend" `
  --dapr-app-port 3501
```
For more dapr configurations look [here](https://learn.microsoft.com/en-us/azure/container-apps/dapr-overview?tabs=bicep1%2Cyaml).
With this you should be able to access the Frontend Web App and call the backend API app using dapr.
