# Challenge 1: Build and push Microservice Images locally

Duration: 25 minutes

[Previous Challange Solution](./00-Getting-started-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./02-Azure-Container-Apps-solution.md)

## Task 1: Clone the FlightBooker Folder from this Repository

If you are using VS Code make sure you are connected to your gitHub account.
Then you can use the terminal or the command palette to clone the repository.
In order to optimize your workflow for the upcoming challenges create a new gitHub repository in your own account and copy only the ServerlessMicroservices or even only the Flightbooker folder into it. This way you can easily make changes and follow the Challenges.

You can check if the services run locally on you Computer. Therefore, navigate to the frontend folder in your terminal and execute the command `npm install`. In a second terminal navigate to the backend folder and do the same. After that you should be able to run `npm run dev` in the frontend terminal and `npm start` in the backend terminal and open the application on your localhost. If this doesn't work, check if you have installed all dependencies.

## Task 2: Create Docker images of the microservices

The next step would be to add Docker files and build a Docker image for each microservice.
You can find how to add Docker files and build images [here](https://learn.microsoft.com/en-us/azure/developer/javascript/tutorial/tutorial-vscode-docker-node/tutorial-vscode-docker-node-04) which is applied on our case below:

The general process for the frontend and backend is the same. Make sure you have docker running, for example via Docker Desktop. If you work with VS Code also make sure you have the Docker extension. In VS Code open the Command Palette and type `add docker files to workspace` then select the <b>Docker: Add Docker files to workspace </b> command. In the following chose Node.js as the application platform, the respective package.json file, port 3000 for the backend (5173 for the frontend) and no Docker Compose file.
This will create a Dockerfile and a .dockerignore. Now that you have the basic Dockerfiles you might have to make some changes so that the image created from them will be able to run. Here's how they could look like:

### Docker image backend

```
FROM node:lts-alpine
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN npm install --production --silent && mv node_modules ../
COPY . .
EXPOSE 443
RUN chown -R node /usr/src/app
USER node
CMD ["npm", "start"]
```

### Docker image frontend

```
FROM node:lts-alpine
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN npm install
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev"]
```

To build the Docker image again open the Command Palette and run `Docker Images: Build Image` and choose the right Dockerfile to build the image. This will open the Terminal with the `docker build`command. Once that's done you can go to the Docker Explorer and under Images your newly created Docker image will appear.

### include tag

To be able to push the image to the azure registry, you must tag it with the registry name. So open your VS Code's task file at `./vscode/tasks.json` and find the task with the type docker-build. Add the tag property, using your registry name (in this case flightbookeracr) in the `dockerBuild` property.

```
{
    "type": "docker-build",
    "label": "docker-build",
    "platform": "node",
    "dockerBuild": {
        "dockerfile": "${workspaceFolder}/Dockerfile",
        "context": "${workspaceFolder}",
        "pull": true,
        "tag": "YOUR-REGISTRY-NAME.azurecr.io/flightbookerbackend:latest"
    }
},
```

Since we need this for both frontend and backend we need this and all docker tasks twice (or you work in two different VS Code instances alternatively). If you only work with one this is how the tasks.json could look like:

```
{
	"version": "2.0.0",
	"tasks": [
		{
			"type": "docker-build",
			"label": "docker-build",
			"platform": "node",
			"dockerBuild": {
				"dockerfile": "${workspaceFolder}/Flightbooker/flightbooker-frontend/Dockerfile",
				"context": "${workspaceFolder}/Flightbooker/flightbooker-frontend",
				"pull": true,
				"tag": "flightbookeracr.azurecr.io/flightbookerfrontend:latest"
			},
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-frontend/package.json"
			}
		},
		{
			"type": "docker-run",
			"label": "docker-run: release",
			"dependsOn": [
				"docker-build"
			],
			"platform": "node",
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-frontend/package.json"
			}
		},
		{
			"type": "docker-run",
			"label": "docker-run: debug",
			"dependsOn": [
				"docker-build"
			],
			"dockerRun": {
				"env": {
					"DEBUG": "*",
					"NODE_ENV": "development"
				}
			},
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-frontend/package.json",
				"enableDebugging": true
			}
		},

		{
			"type": "docker-build",
			"label": "docker-build",
			"platform": "node",
			"dockerBuild": {
				"dockerfile": "${workspaceFolder}/Flightbooker/flightbooker-backend/Dockerfile",
				"context": "${workspaceFolder}/Flightbooker/flightbooker-backend",
				"pull": true,
				"tag": "flightbookeracr.azurecr.io/flightbookerbackend:latest"
			},
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-backend/package.json"
			}
		},
		{
			"type": "docker-run",
			"label": "docker-run: release",
			"dependsOn": [
				"docker-build"
			],
			"platform": "node",
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-backend/package.json"
			}
		},
		{
			"type": "docker-run",
			"label": "docker-run: debug",
			"dependsOn": [
				"docker-build"
			],
			"dockerRun": {
				"env": {
					"DEBUG": "*",
					"NODE_ENV": "development"
				}
			},
			"node": {
				"package": "${workspaceFolder}/Flightbooker/flightbooker-backend/package.json",
				"enableDebugging": true
			}
		}
	]
}
```

Now we have to build both our images again. You can do this the same way as described above.

## Task 3: Push images to your ACR

The previous [link](https://learn.microsoft.com/en-us/azure/developer/javascript/tutorial/tutorial-vscode-docker-node/tutorial-vscode-docker-node-04) also includes a tutorial on how to push the image to a registry.

In our Docker explorer there should now be two images with the registry name in front of them like `flightbookeracr.azurecr.io/flightbooker-backend`. If you expand them and right-click latest you can select <b>Push</b> and accept the tag which will push the images to your azure registry that you specified in the image name.

If the output displays "Authentication required" run az acr login --name $REGISTRY_NAME in the terminal.

Now you can check in your Azure portal if the Images got pushed to the registry by going to the registry and from there to Repositories under Services. Alternatively they should also be visible in the Docker extension explorer under the <b>Registries</b> node.
