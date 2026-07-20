# Exercise 4: Expose Application with Load Balancer

## Objective
In this exercise, you will expose your deployed applications to the internet using Kubernetes Services and Azure Load Balancer. You'll learn different service types and how to make your applications accessible from outside the cluster.

## What is a Kubernetes Service?

A Kubernetes Service is an abstraction that defines a logical set of Pods and a policy to access them. Services provide:
- Stable IP addresses and DNS names
- Load balancing across pods
- Service discovery within the cluster
- External access to applications

### Service Types

- **ClusterIP** (Default): Exposes service only within the cluster
- **NodePort**: Exposes service on each node's IP at a static port
- **LoadBalancer**: Exposes service externally using a cloud provider's load balancer
- **ExternalName**: Maps service to a DNS name

## Prerequisites
- Completed Exercise 3 (Applications deployed)
- Running deployments in your AKS cluster
- kubectl configured

## Tasks

Find and review the service manifests in the [`resources/exercise-04`](../resources/exercise-04/k8s-manifest/) directory of the lab repository.

### Task 1: Expose the Backend internally through ClusterIP 

This service will expose the backend application internally within the cluster using ClusterIP.

1. **Apply the service configuration for the backend**

   ```bash
   kubectl apply -f backend-svc.yaml
   ```

2. **Verify the service**
   ```bash
   kubectl get services
   kubectl describe service backend
   ```

   Note the ClusterIP assigned. This IP is only accessible within the cluster.

### Task 2: Expose Frontend externally with LoadBalancer

Now, let's expose an application to the internet using Azure Load Balancer.

1. **Apply the service configuration for the frontend**

   ```bash
   kubectl apply -f frontend-svc.yaml
   ```

2. **Watch the service creation**
   ```bash
   kubectl get service frontend-svc --watch
   ```

   Wait for the `EXTERNAL-IP` to change from `<pending>` to an actual IP address. This can take 2-3 minutes.
   Press `Ctrl+C` when the IP appears.

4. **Get the external IP**
   ```bash
   kubectl get service frontend-svc
   ```

   Note the EXTERNAL-IP address.
   
### Task 3: Access Your Application

1. **Get the external IP address**
   ```bash
   export EXTERNAL_IP=$(kubectl get service frontend-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo $EXTERNAL_IP
   ```

2. **Test the application**
   ```bash
   curl http://$EXTERNAL_IP
   ```

3. **Access from browser**
   - Open your web browser
   - Navigate to `http://<EXTERNAL-IP>`
   - You should see your application

### Task 4: View Load Balancer in Azure Portal

1. **Navigate to your Resource Group**
   - Go to Azure Portal
   - Open the MC_<your-aks-resource-group-name>_<your-aks-cluster-name>_<region> resource group
   - You'll see a new Load Balancer resource called `kubernetes` created automatically

2. **Examine the Load Balancer**
   - Click on the Load Balancer
   - View **Frontend IP configuration**: Shows the public IP
   - View **Backend pools**: Shows your AKS nodes
   - View **Health probes**: Shows health check configuration
   - View **Load balancing rules**: Shows traffic distribution rules

3. **View the Public IP Address**
   - Click on the Public IP address associated with the load balancer
   - Note the IP address and DNS name (if configured)

### Task 5: Expose Application from Azure Portal


> [!WARNING]  
> The following tasks are optional. You can skip them if you only want to learn about simple Load Balancer configuration. If instead you want to learn more, continue with the next task, but notice that the commands are just examples for reference, not directly aligned with the sample application and the manifests provided.

You can also create services using the Azure Portal.

1. **Navigate to your AKS cluster**
   - Go to "Kubernetes services"
   - Click on your cluster

2. **Access Services and ingresses**
   - In the left menu, click "Services and ingresses"
   - Click "+ Create"

3. **Create a LoadBalancer service**
   - Select "Service"
      - Compile the form with the value you have in the manifest file
      - Click "Create"
   - **OR** Select "Apply a YAML"
      - Paste your service YAML definition
      - Click "Apply"

4. **Monitor the service creation**
   - View the service in the "Services and ingresses" list
   - Wait for the external IP to be assigned
   - Click on the service to view details

### Task 6: Create a LoadBalancer with Specific Configuration

For more control over the load balancer, you can add annotations:

```bash
cat > frontend-service-lb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-resource-group: "rg-aks-lab-<yourname>"
  labels:
    app: frontend-app
spec:
  type: LoadBalancer
  selector:
    app: frontend-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  sessionAffinity: ClientIP
EOF
```

Apply the service:
```bash
kubectl apply -f frontend-service-lb.yaml
```

### Task 7: Test Load Balancing

Let's verify that traffic is being distributed across pods:

1. **Scale up the deployment**
   ```bash
   kubectl scale deployment frontend --replicas=5
   ```

2. **Make multiple requests**
   ```bash
   for i in {1..10}; do
     curl http://$EXTERNAL_IP
     echo "Request $i completed"
   done
   ```

3. **Check logs from different pods**
   ```bash
   kubectl logs -l app=frontend-app --tail=5
   ```

   You should see logs from multiple pods, indicating traffic distribution.

### Task 8: Configure NodePort Service (Alternative)

NodePort can be used when LoadBalancer is not available or for testing:

```bash
cat > sample-app-nodeport.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: sample-app-nodeport
spec:
  type: NodePort
  selector:
    app: sample-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

Apply and access:
```bash
kubectl apply -f sample-app-nodeport.yaml

# Get node external IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Access via NodePort
curl http://$NODE_IP:30080
```

## Verification Checklist

Before moving to the next exercise, ensure:
- [ ] At least one LoadBalancer service is created
- [ ] External IP is assigned to the service
- [ ] You can access the application from your browser
- [ ] Load balancer appears in Azure Portal
- [ ] Traffic is distributed across multiple pods
- [ ] Internal services can communicate via ClusterIP

## Expected Output

**kubectl get services** should show:
```
NAME                  TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
kubernetes            ClusterIP      10.0.0.1       <none>           443/TCP        1h
backend-service       ClusterIP      10.0.45.23     <none>           8080/TCP       10m
sample-app-service    LoadBalancer   10.0.132.45    20.123.45.67     80:31234/TCP   5m
frontend-service      LoadBalancer   10.0.198.12    20.234.56.78     80:32456/TCP   3m
```

## Troubleshooting

- **External IP stuck at `<pending>`**: 
  ```bash
  kubectl describe service sample-app-service
  kubectl get events --sort-by=.metadata.creationTimestamp
  ```
  Check for quota issues or Azure subscription limits

- **Cannot access application**: 
  - Verify pods are running: `kubectl get pods`
  - Check service selector matches pod labels: `kubectl get pods --show-labels`
  - Verify Network Security Group (NSG) rules in Azure Portal

- **Connection timeout**:
  - Check if pods are ready: `kubectl get pods`
  - Verify pod logs: `kubectl logs <pod-name>`
  - Test from within cluster first: `kubectl run test --rm -it --image=busybox -- wget -O- http://sample-app-service`

- **503 Service Unavailable**:
  - Check pod health: `kubectl describe pod <pod-name>`
  - Verify container port matches service targetPort

## Understanding Azure Load Balancer with AKS

When you create a LoadBalancer service in AKS:

1. **Azure Resources Created**:
   - Public IP Address
   - Load Balancer with frontend IP configuration
   - Backend pool (AKS nodes)
   - Health probe
   - Load balancing rule

2. **Traffic Flow**:
   - External traffic → Public IP → Load Balancer → Node → kube-proxy → Pod

3. **High Availability**:
   - Traffic is distributed across healthy pods
   - If a pod fails, traffic is redirected automatically
   - Health probes ensure only healthy pods receive traffic

## Best Practices

- **Use LoadBalancer for production**: Provides HA and automatic failover
- **ClusterIP for internal services**: Backend services don't need external access
- **Set resource limits**: Ensure pods can handle incoming traffic
- **Use health probes**: Add liveness and readiness probes to deployments
- **Consider Ingress**: For HTTP/HTTPS routing to multiple services (advanced topic)
- **Monitor costs**: Each LoadBalancer service creates a billable Azure Load Balancer

## Useful Commands

```bash
# List all services
kubectl get svc

# Describe a service
kubectl describe svc sample-app-service

# Get service endpoints (pods behind the service)
kubectl get endpoints sample-app-service

# Edit a service
kubectl edit svc sample-app-service

# Delete a service
kubectl delete svc sample-app-service

# Port forward for testing
kubectl port-forward svc/sample-app-service 8080:80

# Get service YAML
kubectl get svc sample-app-service -o yaml
```

## Additional Resources

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [AKS Load Balancer](https://docs.microsoft.com/azure/aks/load-balancer-standard)
- [Service Types in Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
- [Azure Load Balancer Documentation](https://docs.microsoft.com/azure/load-balancer/)

## Next Steps

Your applications are now accessible from the internet! Proceed to [Exercise 5: Scaling in AKS](05-scaling.md) to learn about autoscaling.
