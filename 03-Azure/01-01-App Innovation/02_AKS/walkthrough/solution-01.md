# Exercise 1: Create Azure Container Registry and Push Images

## Objective
In this exercise, you will create an Azure Container Registry (ACR) to store your Docker container images. You'll then build and push container images to this registry, which will later be deployed to your AKS cluster.

## What is Azure Container Registry?

Azure Container Registry (ACR) is a managed, private Docker registry service based on the open-source Docker Registry 2.0. It allows you to:
- Store and manage container images and artifacts
- Integrate seamlessly with Azure Kubernetes Service
- Implement security scanning and geo-replication
- Control access with Azure Active Directory

## Prerequisites
- Completed Exercise 0 (Resource Group and Jumphost created)
- Docker installed on your jumphost (not required if using ACR Tasks)
- Azure CLI authenticated

## Lab Variables

Set up your environment variables with your initials:

```bash
export YOUR_INITIALS="<yourinitials>"  # Replace with your initials (e.g., js for John Smith)
export RESOURCE_GROUP="rg-aks-lab-${YOUR_INITIALS}"
export LOCATION="francecentral"
export ACR_NAME="acrakslabACR${YOUR_INITIALS}"
```

Example for John Smith:
```bash
export YOUR_INITIALS="js"
export RESOURCE_GROUP="rg-aks-lab-js"
export LOCATION="francecentral"
export ACR_NAME="acrakslabjs"
```

## Tasks

### Task 1: Create an Azure Container Registry

1. **Define your ACR name**
   
   ACR names must be:
   - Globally unique across all of Azure
   - 5-50 characters long
   - Contain only alphanumeric characters (no hyphens or special characters)
   
   **Naming format**: `acrakslabACR<yourinitials>`
   
   Example: `acrakslabjs` (for John Smith with initials "js")

2. **Create the ACR using Azure CLI**

   ```bash
   az acr create \
     --name acrakslab<yourinitials> \
     --resource-group rg-aks-lab-<yourinitials> \
     --sku Basic \
     --location francecentral
   ```
   
   Replace `<yourinitials>` with your initials (e.g., `js` for John Smith).
   
   Example:
   ```bash
   az acr create \
     --name acrakslabjs \
     --resource-group rg-aks-lab-js \
     --sku Basic \
     --location francecentral
   ```

   **SKU Options:**
   - `Basic`: Cost-effective for development and testing
   - `Standard`: More storage and throughput
   - `Premium`: Highest storage, geo-replication, and advanced features

3. **Verify the ACR creation**
   ```bash
   az acr show --name <your-acr-name> --output table
   ```

### Task 2: Login to Azure Container Registry

1. **Authenticate Docker with ACR**
   ```bash
   az acr login --name <your-acr-name>
   ```

   You should see: `Login Succeeded`

2. **Get the ACR login server** (you'll need this later)
   ```bash
   az acr show --name <your-acr-name> --query loginServer --output tsv
   ```

   This will return something like: `<your-acr-name>.azurecr.io`

3. **Save the login server as a variable**
   ```bash
   export ACR_LOGIN_SERVER=$(az acr show --name <your-acr-name> --query loginServer --output tsv)
   echo $ACR_LOGIN_SERVER
   ```

### Task 3: Build and Push the provided Sample Application Images

#### Option A: Build images locally with Docker

You can find the source code for the sample application in the [`resources/exercise-01/sample-app`](../resources/exercise-01/sample-app) directory.
The application consists of a simple backend API and a frontend UI.
You can build and push the images manually using Docker, following these steps:

1. **Navigate to the sample application directory**
   ```bash
   cd ../resources/exercise-01/sample-app/backend
   ```

2. **Review the Dockerfile**
   ```bash
   cat Dockerfile
   ```

3. **Build the Docker image**
   ```bash
   docker build -t $ACR_LOGIN_SERVER/sample-app/backend:v1 .
   ```

4. **Push the image to ACR**
   ```bash
   docker push $ACR_LOGIN_SERVER/sample-app/backend:v1
   ```

5. **Repeat for the frontend application**
   ```bash
   cd ../frontend
   cat Dockerfile
   docker build -t $ACR_LOGIN_SERVER/sample-app/frontend:v1 .
   docker push $ACR_LOGIN_SERVER/sample-app/frontend:v1
   ```

#### Option B: Use ACR Build (Recommended)

ACR can build images directly without local Docker:

1. **Build a backend application**
   ```bash
   az acr build \
     --registry <your-acr-name> \
     --image sample-app/backend:v1 \
     ~/MicroHack/walkthrough/resources/exercise-01/sample-app/backend
   ```

2. **Build a frontend application**
   ```bash
   az acr build \
     --registry <your-acr-name> \
     --image sample-app/frontend:v1 \
     ~/MicroHack/walkthrough/resources/exercise-01/sample-app/frontend
   ```

   This builds the image in Azure and pushes it to your registry automatically.

#### Option C: Import a Public Image

For testing, you can import a public image from Docker Hub:

```bash
az acr import \
  --name <your-acr-name> \
  --source docker.io/library/nginx:latest \
  --image nginx:latest
```

### Task 4: List and Verify Images in ACR

1. **List all repositories in your ACR**
   ```bash
   az acr repository list --name <your-acr-name> --output table
   ```

2. **List tags for a specific repository**
   ```bash
   az acr repository show-tags \
     --name <your-acr-name> \
     --repository sample-app/backend \
     --output table
   ```

3. **View detailed information about an image**
   ```bash
   az acr repository show \
     --name <your-acr-name> \
     --repository sample-app/backend
   ```
4. **You can do the same for the frontend image:**
   ```bash
   az acr repository show-tags \
     --name <your-acr-name> \
     --repository sample-app/frontend \
     --output table

   az acr repository show \
   --name <your-acr-name> \
   --repository sample-app/frontend
   ```

## Verification Checklist

Before moving to the next exercise, ensure:
- [ ] Azure Container Registry is created successfully
- [ ] You can login to ACR with `az acr login`
- [ ] At least one container image is pushed to ACR
- [ ] You can list repositories and tags
- [ ] You have noted your ACR login server name

## Expected Output

When listing repositories, you should see output like:

```
Result
-----------
sample-app
nginx
backend-app
frontend-app
```

## Best Practices

- **Naming**: Use consistent naming for your images (e.g., `appname:version`)
- **Tagging**: Use semantic versioning tags (v1, v1.0.0, latest)
- **Security**: Avoid enabling admin access in production; use managed identities instead
- **Image Scanning**: Consider enabling Azure Defender for container registries
- **Retention Policies**: Set up retention policies to automatically clean up old images

## Troubleshooting

- **"unauthorized: authentication required" error**: Run `az acr login` again
- **Name not available**: ACR names must be globally unique; try a different name
- **Docker daemon not running**: Start Docker with `sudo systemctl start docker`
- **Build fails**: Check your Dockerfile syntax and ensure all required files are present
- **Push denied**: Verify you have the correct permissions on the ACR

## Useful Commands

```bash
# Check ACR quotas and usage
az acr show-usage --name <your-acr-name>

# Delete a repository
az acr repository delete --name <your-acr-name> --repository sample-app --yes

# Delete a specific image tag
az acr repository delete --name <your-acr-name> --image sample-app:v1 --yes

# Show ACR credentials (if admin enabled)
az acr credential show --name <your-acr-name>
```

## Additional Resources

- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [ACR Best Practices](https://docs.microsoft.com/azure/container-registry/container-registry-best-practices)
- [ACR Tasks](https://docs.microsoft.com/azure/container-registry/container-registry-tasks-overview)

## Next Steps

Once your images are stored in ACR, proceed to [Exercise 2: Create AKS Cluster with ACR Integration](02-create-aks-cluster.md)
