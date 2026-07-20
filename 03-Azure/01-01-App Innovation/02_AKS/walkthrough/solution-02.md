# Exercise 2: Create an AKS Cluster with ACR Integration

## Objective
In this exercise, you will create an Azure Kubernetes Service (AKS) cluster with specific configurations and integrate it with your Azure Container Registry (ACR) to enable seamless image pulling.

## What is Azure Kubernetes Service (AKS)?

Azure Kubernetes Service (AKS) is a managed Kubernetes service that simplifies deploying and managing containerized applications. AKS reduces the complexity of Kubernetes by:
- Managing the control plane (master nodes) for you
- Providing automatic upgrades and patching
- Integrating with other Azure services
- Offering built-in monitoring and security features

## Prerequisites
- Completed Exercise 1 (ACR created with images)
- Resource Group created
- Azure CLI authenticated

## Lab Variables

Set up your environment variables:

```bash
export YOUR_INITIALS="<yourinitials>"  # Replace with your initials (e.g., js for John Smith)
export RESOURCE_GROUP="rg-aks-lab-${YOUR_INITIALS}"
export AKS_CLUSTER_NAME="aks-lab-${YOUR_INITIALS}"
export ACR_NAME="acrakslabACR${YOUR_INITIALS}"
export LOCATION="francecentral"
```

Example for John Smith:
```bash
export YOUR_INITIALS="js"
export RESOURCE_GROUP="rg-aks-lab-js"
export AKS_CLUSTER_NAME="aks-lab-js"
export ACR_NAME="acrakslabjs"
export LOCATION="francecentral"
```

## Tasks

### Task 1: Plan Your AKS Cluster Configuration

Before creating the cluster, consider these key configuration options:

**Cluster Name**: `aks-lab-<yourinitials>` (e.g., `aks-lab-js` for John Smith)

**Node Configuration**:
- **VM Size**: `Standard_B2s` (for lab) or `Standard_DS2_v2` (recommended)
- **Node Count**: Start with 2 nodes
- **Node Pool Name**: `nodepool1` (default system node pool)

**Networking**:
- **Network Plugin**: `azure` (Azure CNI) - Provides better integration with Azure networking
- **Load Balancer**: Standard SKU

**Authentication**:
- **Identity**: System-assigned managed identity (recommended)

### Task 2: Create AKS Cluster with ACR Integration

#### Method 1: Create AKS and Attach ACR (Recommended)

```bash
# Set variables for easier reuse (use your initials, e.g., js for John Smith)
export RESOURCE_GROUP="rg-aks-lab-<yourinitials>"
export AKS_CLUSTER_NAME="aks-lab-<yourinitials>"
export ACR_NAME="acrakslabACR<yourinitials>"
export LOCATION="francecentral"

# Create AKS cluster with ACR integration
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys \
  --location $LOCATION \
  --network-plugin azure \
  --load-balancer-sku standard
```

**Key Parameters Explained**:
- `--node-count 2`: Creates 2 worker nodes
- `--node-vm-size`: Specifies the size of each node VM
- `--enable-managed-identity`: Uses managed identity for authentication
- `--attach-acr`: Automatically configures ACR pull permissions
- `--generate-ssh-keys`: Creates SSH keys for node access
- `--network-plugin azure`: Uses Azure CNI for advanced networking features and better Azure integration
- `--load-balancer-sku standard`: Uses Standard Load Balancer

**Note**: This process takes 5-10 minutes. The output will show cluster creation progress.

#### Method 2: Create AKS First, Then Attach ACR

If you already have an AKS cluster without ACR integration:

```bash
# Attach ACR to existing AKS cluster
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --attach-acr $ACR_NAME
```

### Task 3: Understanding ACR Integration

The `--attach-acr` flag automatically:
1. Creates a role assignment for the AKS managed identity
2. Grants `AcrPull` permission on the specified ACR
3. Allows AKS nodes to pull images without explicit credentials

**Verify the integration**:
```bash
# Check the role assignment
az role assignment list \
  --scope $(az acr show --name $ACR_NAME --query id --output tsv) \
  --output table
```

You should see a role assignment with `AcrPull` role for your AKS managed identity.

### Task 4: Get AKS Credentials and Connect

#### Understanding AKS Credentials

When you run `az aks get-credentials`, several important things happen:

1. **What are Kubernetes credentials?**
   - Kubernetes uses a kubeconfig file (usually at `~/.kube/config`) to store cluster connection information
   - This file contains:
     - **Cluster information**: API server endpoint, certificate authority data
     - **User credentials**: Authentication tokens or certificates
     - **Context**: Links a cluster with a user and optional namespace

2. **What does get-credentials do?**
   - Downloads the cluster's API server address
   - Retrieves authentication credentials (using your Azure identity)
   - Merges this information into your local kubeconfig file
   - Sets the current context to point to your AKS cluster
   - Allows `kubectl` to authenticate to the cluster using Azure AD

3. **How authentication works:**
   - AKS uses Azure Active Directory (Azure AD) for authentication
   - When you use `kubectl`, it calls Azure AD to get a token
   - This token is sent to the AKS API server to authenticate your requests
   - Your Azure RBAC permissions determine what you can do in the cluster

#### Download Cluster Credentials

1. **Get credentials and merge into kubeconfig**
   ```bash
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $AKS_CLUSTER_NAME
   ```

   Expected output:
   ```
   Merged "aks-lab-js" as current context in /home/azureuser/.kube/config
   ```

2. **Understanding the command options:**
   
   Additional useful flags:
   ```bash
   # Overwrite existing credentials (useful if you need to refresh)
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $AKS_CLUSTER_NAME \
     --overwrite-existing
   
   # Get admin credentials (bypasses Azure AD, not recommended for production)
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $AKS_CLUSTER_NAME \
     --admin
   
   # Save to a specific kubeconfig file
   az aks get-credentials \
     --resource-group $RESOURCE_GROUP \
     --name $AKS_CLUSTER_NAME \
     --file ./my-cluster-config
   ```

3. **View your kubeconfig file**
   ```bash
   # View the entire kubeconfig
   cat ~/.kube/config
   
   # View current context
   kubectl config current-context
   
   # List all contexts
   kubectl config get-contexts
   ```

4. **Verify the connection**
   ```bash
   kubectl cluster-info
   ```
   
   This shows the Kubernetes control plane and CoreDNS endpoints.

5. **View cluster nodes**
   ```bash
   kubectl get nodes
   ```

   You should see 2 nodes in `Ready` status.

6. **Check node details**
   ```bash
   kubectl get nodes -o wide
   ```
   
   This shows additional information like internal/external IPs, OS, and kernel version.

### Task 5: Explore Your AKS Cluster

1. **View namespaces**
   ```bash
   kubectl get namespaces
   ```

2. **View system pods**
   ```bash
   kubectl get pods --all-namespaces
   ```

3. **Check cluster version**
   ```bash
   kubectl version
   ```

4. **View cluster configuration**
   ```bash
   kubectl config view
   ```

### Task 6: View Cluster in Azure Portal

1. **Navigate to your AKS cluster**
   - Go to Azure Portal
   - Search for "Kubernetes services"
   - Click on your cluster name

2. **Explore the portal features**
   - **Overview**: View cluster status, version, location
   - **Node pools**: See your node configuration
   - **Networking**: Review network settings
   - **Insights**: View monitoring data (if enabled)
   - **Workloads**: View deployments (will be used in next exercise)

### Task 7: Test ACR Integration

Create a simple pod using an image from your ACR:

```bash
# Replace with your ACR login server and image name
export ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# Create a test pod
kubectl run test-acr-pod \
  --image=$ACR_LOGIN_SERVER/sample-app/backend:v1 \
  --restart=Never

# Check pod status (should pull image successfully)
kubectl get pod test-acr-pod

# View pod details
kubectl describe pod test-acr-pod

# Clean up test pod
kubectl delete pod test-acr-pod
```

If the image pulls successfully, your ACR integration is working correctly!

## Configuration Best Practices

### Recommended Configurations

**For Development/Lab**:
```bash
--node-vm-size Standard_B2s
--node-count 1-2
--network-plugin azure
```

**For Production**:
```bash
--node-vm-size Standard_DS2_v2 or higher
--node-count 3+ (for high availability)
--network-plugin azure
--enable-private-cluster
--enable-cluster-autoscaler
--network-policy azure (or calico)
```

### Security Configurations

```bash
# Enable Azure Policy
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --addons azure-policy

# Enable Azure Key Vault Provider for Secrets Store CSI Driver
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider
```

## Verification Checklist

Before moving to the next exercise, ensure:
- [ ] AKS cluster is created and shows "Succeeded" provisioning state
- [ ] You can connect to the cluster with kubectl
- [ ] All nodes are in "Ready" status
- [ ] ACR is attached and role assignment exists
- [ ] Test pod can pull images from ACR
- [ ] You can view the cluster in Azure Portal

## Expected Output

**kubectl get nodes** should show:
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-12345678-vmss000000   Ready    agent   5m    v1.27.x
aks-nodepool1-12345678-vmss000001   Ready    agent   5m    v1.27.x
```

## Troubleshooting

- **Cluster creation fails**: Check subscription quota for VM cores
- **Cannot connect with kubectl**: Re-run `az aks get-credentials`
- **Nodes not ready**: Wait a few minutes; check with `kubectl describe node <node-name>`
- **Image pull fails**: Verify ACR attachment with `az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query identityProfile`
- **Permission issues**: Ensure your Azure account has proper RBAC roles

## Useful Commands

```bash
# Show AKS cluster details
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# List available Kubernetes versions
az aks get-versions --location $LOCATION --output table

# Scale the node pool
az aks scale --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --node-count 3

# Upgrade AKS cluster
az aks upgrade --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --kubernetes-version <version>

# Stop AKS cluster (to save costs)
az aks stop --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Start AKS cluster
az aks start --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

## Additional Resources

- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Authenticate with ACR from AKS](https://docs.microsoft.com/azure/aks/cluster-container-registry-integration)
- [AKS Networking Concepts](https://docs.microsoft.com/azure/aks/concepts-network)

## Next Steps

Now that your AKS cluster is ready and integrated with ACR, proceed to [Exercise 3: Deploy Applications on AKS](03-deploy-applications.md)
