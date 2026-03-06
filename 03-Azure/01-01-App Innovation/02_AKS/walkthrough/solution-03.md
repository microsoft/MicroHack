# Exercise 3: Deploy Applications on AKS

## Objective
In this exercise, you will deploy containerized applications to your AKS cluster using images from your Azure Container Registry. You'll learn to deploy applications using both kubectl commands and the Azure Portal.

## What is a Kubernetes Deployment?

A Deployment in Kubernetes is a resource that manages a replicated application. It provides:
- Declarative updates for Pods and ReplicaSets
- Rollback capability
- Scaling functionality
- Self-healing (automatically replaces failed pods)

## Prerequisites
- Completed Exercise 2 (AKS cluster with ACR integration)
- kubectl configured to connect to your cluster
- Images available in your ACR

## Tasks

### Task 1: Prepare Your Deployment Configuration

First, verify your ACR image details:

```bash
# Set variables
export ACR_NAME="<your-acr-name>"
export ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# List available images
az acr repository list --name $ACR_NAME --output table

# Check specific image tags
az acr repository show-tags --name $ACR_NAME --repository sample-app/backend --output table
az acr repository show-tags --name $ACR_NAME --repository sample-app/frontend --output table
```

### Task 2: Deploy Application Using kubectl

#### Method A: Deploy Using Kubectl Run (Quick Test)

```bash
# Deploy a simple pod
kubectl run backend \
  --image=$ACR_LOGIN_SERVER/sample-app/backend:v1 \
  --port=3001

# Check the pod status
kubectl get pods

# View pod details
kubectl describe pod backend
```
Please note the `--port` flag: it should be set to the port your application listens on inside the container.

#### Method B: Deploy Using a Deployment (Recommended)

1. **Find and review the deployments manifest**
   You can find pre-build deployment manifests in the [`resources/exercise-03`](../resources/exercise-03/k8s-manifests) directory of the lab repository.

   **Important**: Replace the ACR Server name, image name and tag with your actual values.

2. **Apply the deployment**
   ```bash
   kubectl apply -f backend.yaml
   kubectl apply -f frontend.yaml
   ```

3. **Verify the deployment**
   ```bash
   # Check deployment status
   kubectl get deployments
   
   # Check pods created by the deployment
   kubectl get pods
   
   # Watch pods being created
   kubectl get pods --watch
   ```
   
   Press `Ctrl+C` to stop watching.

4. **View detailed deployment information**
   ```bash
   kubectl describe deployment backend
   kubectl describe deployment frontend
   ```

### Task 3: Deploy Application Using Azure Portal

The Azure Portal provides a visual interface for deploying applications to AKS.

#### Deploy from Azure Container Registry via Portal

1. **Navigate to your AKS cluster in Azure Portal**
   - Go to "Kubernetes services"
   - Click on your cluster name

2. **Access the Workloads section**
   - In the left menu, click on "Workloads"
   - Click "+ Create"

3. **Deploy using YAML Editor**

   - Select "Apply a YAML"
   - Paste your deployment YAML
   - Click "Apply"

4. **Monitor the deployment**
   - View the deployment in the "Workloads" section
   - Click on the deployment to see details
   - Check the "Pods" tab to see running pods

#### Deploy a Sample Image Directly

1. **Using a public image for testing**
   
   In the YAML editor, you can deploy a sample nginx application:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx-demo
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: nginx-demo
     template:
       metadata:
         labels:
           app: nginx-demo
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           ports:
           - containerPort: 80
   ```

### Task 4: Manage Your Deployments

1. **View deployment status**
   ```bash
   kubectl rollout status deployment/backend
   kubectl rollout status deployment/frontend
   ```

2. **View deployment history**
   ```bash
   kubectl rollout history deployment/backend
    kubectl rollout history deployment/frontend
   ```

> [!WARNING]  
> Don't execute the following commands. They are for learning purposes only.

3. **Scale a deployment**
   ```bash
   kubectl scale deployment backend --replicas=5
   kubectl get pods
   ```

4. **Update deployment image**
   ```bash
   kubectl set image deployment/backend \
     backend=$ACR_LOGIN_SERVER/sample-app/backend:v2
   ```

5. **Check rollout status**
   ```bash
   kubectl rollout status deployment/backend
   ```

6. **Rollback if needed**
   ```bash
   kubectl rollout undo deployment/backend
   ```

### Task 5: View Application Logs

1. **Get logs from a specific pod**
   ```bash
   # List pods
   kubectl get pods
   
   # Get logs (replace <pod-name> with actual pod name)
   kubectl logs <pod-name>
   
   # Follow logs in real-time
   kubectl logs -f <pod-name>
   ```

2. **Get logs from all pods in a deployment**
   ```bash
   kubectl logs -l app=sample-app --all-containers=true
   ```

### Task 6: Access Backend locally for testing

1. **Port forwarding to test application**
   ```bash
   # Forward local port to pod port
   kubectl port-forward deployment/backend 5678:3001
   ```

   Open a new terminal and test:
   ```bash
   curl http://localhost:5678/api/health
   ```

2. **Execute commands inside a pod**
   ```bash
   kubectl exec -it <pod-name> -- /bin/bash
   # Or for alpine-based images:
   kubectl exec -it <pod-name> -- /bin/sh
   ```

## Verification Checklist

Before moving to the next exercise, ensure:
- [ ] At least one application is deployed successfully
- [ ] Pods are running (status: Running)
- [ ] You can view deployments in both kubectl and Azure Portal
- [ ] Images are pulled successfully from ACR
- [ ] You can access application logs
- [ ] You understand how to scale deployments

## Expected Output

**kubectl get deployments** should show:
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
sample-app    3/3     3            3           5m
backend-app   2/2     2            2           3m
frontend-app  3/3     3            3           3m
```

**kubectl get pods** should show:
```
NAME                           READY   STATUS    RESTARTS   AGE
sample-app-5d4f8c7b9d-abcde    1/1     Running   0          5m
sample-app-5d4f8c7b9d-fghij    1/1     Running   0          5m
sample-app-5d4f8c7b9d-klmno    1/1     Running   0          5m
...
```

## Troubleshooting

- **ImagePullBackOff error**: Check ACR integration and image name
  ```bash
  kubectl describe pod <pod-name>
  ```
- **CrashLoopBackOff**: Check application logs for errors
  ```bash
  kubectl logs <pod-name>
  ```
- **Pods not starting**: Check resource constraints and node capacity
  ```bash
  kubectl describe nodes
  kubectl top nodes
  ```
- **Cannot find image**: Verify image exists in ACR
  ```bash
  az acr repository list --name $ACR_NAME
  ```

## Best Practices

- **Use Deployments**: Instead of creating pods directly, use Deployments for better management
- **Set Resource Limits**: Always define resource requests and limits
- **Use Labels**: Apply meaningful labels for organization and selection
- **Health Checks**: Add liveness and readiness probes (covered in advanced topics)
- **ConfigMaps and Secrets**: Store configuration separately from container images
- **Version Tags**: Use specific version tags instead of `latest`

## Useful Commands

```bash
# Get all resources
kubectl get all

# Delete a deployment
kubectl delete deployment sample-app

# Edit a deployment
kubectl edit deployment sample-app

# Get deployment YAML
kubectl get deployment sample-app -o yaml

# Apply multiple files
kubectl apply -f ./deployments/

# Delete resources from file
kubectl delete -f deployment.yaml

# Get events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Additional Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Deploy to AKS from ACR](https://docs.microsoft.com/azure/aks/tutorial-kubernetes-deploy-application)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Next Steps

Your applications are now running in the cluster, but they're not accessible from outside. Proceed to [Exercise 4: Expose Application with Load Balancer](04-expose-application.md) to make your applications accessible.
