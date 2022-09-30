# Challenge 1: Build and push Microservice Images locally

[Previous Challange Solution](./00-Getting-started-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./02-Azure-Container-Apps-solution.md)

## Task 1: Clone the FlightBooker Folder from this Repository
If you are using VS Code make sure you are connected to your gitHub account.
Then you can use the terminal to clone the folder: 

```
git init
git remote add [REMOTE_NAME] [GIT_URL]
git fetch REMOTE_NAME
git checkout REMOTE_NAME/BRANCH -- path/to/directory
```
You can check if the services run locally on you Computer. Therefor in a terminal direct to the folder of the frontend and run `npm install`. In a second terminal go to the folder of the backend and do the same. After that you should be able to run `npm run dev` on both terminals and open the application in your localhost. Ideally push the Flightbooker into a personal repository as you are going to need it for making changes and using gitHub Actions later.



## Task 2: Create Docker images of the microservices

The next step would be to add Docker files and build a Docker image for each microservice. 
You can find how to add Docker files and build images [here](https://learn.microsoft.com/en-us/azure/developer/javascript/tutorial/tutorial-vscode-docker-node/tutorial-vscode-docker-node-04).

## Task 3: Push images to your ACR

The previous [link](https://learn.microsoft.com/en-us/azure/developer/javascript/tutorial/tutorial-vscode-docker-node/tutorial-vscode-docker-node-04) also includes a tutorial on how to push the image to a registry.

Alternatively you can use this CLI command to build and push to image directly:
```
az acr build --image $PATH `
  --registry $REGISTRY_NAME `
  --file Dockerfile .
```
To check if they are running from your ACR use:

```
az acr run --registry $CONTAINER_REGISTRY `
--cmd '$REGISTRY/$PATH' /dev/null
```

