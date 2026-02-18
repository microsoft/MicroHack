# Exercise 5: Scaling in AKS

## Objective
In this exercise, you will learn about scaling in Kubernetes and AKS, including pod autoscaling (HPA/VPA) and node pool autoscaling. You'll understand how to handle varying workloads by adjusting the number of pod replicas or cluster nodes.

## What is Scaling in Kubernetes?

Scaling allows your applications to handle varying workloads by adjusting the number of pod replicas or cluster nodes.

**Types of Scaling**:
- **Horizontal Pod Autoscaler (HPA)**: Scales the number of pod replicas based on metrics
- **Vertical Pod Autoscaler (VPA)**: Adjusts CPU and memory requests/limits for pods
- **Cluster Autoscaler**: Scales the number of nodes in your cluster

## Prerequisites
- Completed Exercise 4 (Applications exposed)
- Running AKS cluster with deployed applications
- kubectl configured

## Tasks

### Task 1: Manual Scaling

Let's start with manual scaling to understand the basics.
Let's use the deployment for the backend application we created in Exercise 3.

1. **Scale pods manually using kubectl**
   ```bash
   # Scale up to 3 replicas
   kubectl scale deployment backend --replicas=3
   
   # Verify the scaling
   kubectl get pods -l app=backend
   ```

2. **Watch pods being created**
   ```bash
   kubectl get pods --watch
   ```
   Press `Ctrl+C` to stop watching.

3. **Scale down**
   ```bash
   kubectl scale deployment backend --replicas=2
   kubectl get pods -l app=backend
   ```

### Task 2: Horizontal Pod Autoscaler (HPA)

HPA automatically scales the number of pods based on observed CPU utilization or custom metrics.

#### Prerequisites for HPA

1. **Verify Metrics Server is installed** (usually pre-installed in AKS)
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

   You should see the metrics-server deployment with READY status (e.g., `2/2`).
   This kind of system components are always deployed in the `kube-system` namespace, as DaemonSets, deployments that are spread across all nodes.

2. **Only if not installed, enable it**
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

   Wait for the Metrics Server to be ready:
   ```bash
   kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
   ```

3. **Verify metrics are available**
   ```bash
   kubectl top nodes
   kubectl top pods
   ```

   If you see CPU and memory usage (not errors), the Metrics Server is working correctly.

   **Note**: It may take 60-90 seconds after cluster creation for metrics to become available.

#### Create HPA

1. **Ensure your deployment has resource requests** (required for HPA)

   Check the backend deployment file [`../resources/exercise-03/k8s-manifests/backend.yaml`](../resources/exercise-03/k8s-manifests/backend.yaml) to confirm it has resource requests defined. 
   If not, add the following configuration under container specs (be sure to follow YAML indentation):
   ```yaml
           resources:
             requests:
               cpu: 100m
               memory: 128Mi
             limits:
               cpu: 500m
               memory: 256Mi
   ```
   You can also find the corrected file version in [`../resources/exercise-05/k8s-manifests/`](../resources/exercise-05/k8s-manifests/). 

   Apply the deployment:
   ```bash
   kubectl apply -f sample-app-with-resources.yaml
   ```

   **Wait for pods to be ready and metrics to be collected** (important!):
   ```bash
   kubectl wait --for=condition=ready pod -l app=backend --timeout=120s
   ```

   Wait an additional 60 seconds for the Metrics Server to collect initial metrics.

   Verify metrics are available for the new pods:
   ```bash
   kubectl top pods -l app=backend
   ```

2. **Create a Horizontal Pod Autoscaler**

   Find and review the HPA manifest in [`../resources/exercise-05/k8s-manifests/backend-hpa.yaml`](../resources/exercise-05/k8s-manifests/backend-hpa.yaml).

   Apply the HPA:
   ```bash
   kubectl apply -f backend-hpa.yaml
   ```

3. **Alternatively, create HPA using kubectl command**
   ```bash
   kubectl autoscale deployment backend \
     --cpu-percent=50 \
     --min=1 \
     --max=5
   ```

4. **Verify HPA**
   ```bash
   kubectl get hpa
   kubectl describe hpa backend-hpa
   ```

   You should see CPU metrics like `cpu: 1%/50%` (current/target).

   **If you see warnings about "no metrics returned"**: This is normal for the first 1-2 minutes after creating the HPA. Wait a bit and check again.

   > [!TIP]
   > HPA uses a stabilization window to avoid rapid scaling up and down. The default is 300 seconds (5 minutes). This means HPA will wait for 5 minutes of stable metrics before scaling down. 
   If you have scaled up manually in the task 1.1 you have 3 replicas when you configured the HPA. It will be scaled down automatically to 1 after 5 minutes.
   See [Horizontal Pod Autoscaler Concepts](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) for more details.

5. **Monitor HPA in action**
   ```bash
   kubectl get hpa sample-app-hpa --watch
   ```

#### Test HPA

1. **Generate load** 
   ```bash
   # Generate load using a load generator pod
   kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://backend:3001/api/load-test?iterations=50000; done"
   ```

3. **Watch the pods scale**
   ```bash
   kubectl get hpa backend-hpa --watch
   kubectl get pods -l app=backend-hpa --watch
   ```

   After a few minutes, you should see the number of pods increase.

   The result should look similar to this:

   ```
   NAME          REFERENCE            TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
   backend-hpa   Deployment/backend   cpu: 1%/50%          1         5         1          87m
   backend-hpa   Deployment/backend   cpu: <unknown>/50%   1         5         4          87m
   backend-hpa   Deployment/backend   cpu: <unknown>/50%   1         5         4          88m
   backend-hpa   Deployment/backend   cpu: 237%/50%        1         5         4          89m
   ```

4. **Stop the load generator** (press `Ctrl+C`)

5. **Watch pods scale down** (this takes several minutes)
   ```bash
   kubectl get hpa backend-hpa --watch
   ```

   > [!TIP]
   > Remember the stabilization window: HPA will wait for 5 minutes of stable metrics before scaling down.

### Task 3: Vertical Pod Autoscaler (VPA)

VPA automatically adjusts CPU and memory requests/limits based on usage.

**Note**: VPA is not installed by default in AKS and requires manual installation. It's an advanced topic.

#### Understanding VPA

**VPA Modes**:
- **Auto**: VPA assigns resource requests on pod creation and updates them during pod lifecycle
- **Initial**: VPA assigns resource requests only on pod creation
- **Off**: VPA only provides recommendations without applying them
- **Recreate**: VPA assigns resource requests on pod creation and updates them by recreating pods

#### View VPA Recommendations (Informational)

```bash
# VPA installation steps (informational only)
# 1. Clone VPA repo
# git clone https://github.com/kubernetes/autoscaler.git
# cd autoscaler/vertical-pod-autoscaler
# ./hack/vpa-up.sh

# Create VPA in "Off" mode to get recommendations
cat > vpa-recommender.yaml <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: sample-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sample-app
  updatePolicy:
    updateMode: "Off"
EOF
```

**Key Differences: HPA vs VPA**

| Feature | HPA | VPA |
|---------|-----|-----|
| What it scales | Number of pod replicas | CPU/Memory requests |
| When to use | Handle more requests | Optimize resource allocation |
| Metrics | CPU, Memory, Custom | Historical usage |
| Can be combined | Yes (with caution) | Yes (with caution) |

### Task 4: Node Pool Autoscaling

Cluster Autoscaler automatically adjusts the number of nodes in your cluster based on pending pods.

1. **Check current node pools**
   ```bash
   az aks nodepool list \
     --resource-group rg-aks-lab-<yourinitials> \
     --cluster-name aks-lab-<yourinitials> \
     --output table
   ```

2. **Enable cluster autoscaler on existing node pool**
   ```bash
   az aks nodepool update \
     --resource-group rg-aks-lab-<yourinitials> \
     --cluster-name aks-lab-<yourinitials> \
     --name nodepool1 \
     --enable-cluster-autoscaler \
     --min-count 1 \
     --max-count 5
   ```

3. **Verify autoscaler is enabled**
   ```bash
   az aks nodepool show \
     --resource-group rg-aks-lab-<yourinitials> \
     --cluster-name aks-lab-<yourinitials> \
     --name nodepool1 \
     --query 'enableAutoScaling'
   ```

4. **View current nodes**
   ```bash
   kubectl get nodes
   ```

5. **Test node autoscaling by creating many pods**
   ```bash
   # Create a deployment with many replicas
   kubectl create deployment autoscale-test --image=nginx --replicas=30
   
   # Watch nodes being added
   kubectl get nodes --watch
   ```

6. **Monitor cluster autoscaler logs**
   ```bash
   kubectl logs -n kube-system -l app=cluster-autoscaler
   ```

7. **Clean up test deployment**
   ```bash
   kubectl delete deployment autoscale-test
   ```

   Watch nodes scale down (this takes 10-15 minutes):
   ```bash
   kubectl get nodes --watch
   ```

8. **Configure autoscaler via Azure Portal**
   - Navigate to your AKS cluster
   - Go to "Node pools"
   - Select your node pool
   - Click "Scale"
   - Enable "Autoscale" toggle
   - Set minimum and maximum node count
   - Click "Save"

### Task 5: Manual Node Pool Scaling

You can also manually scale node pools:

```bash
# Scale node pool to 3 nodes
az aks nodepool scale \
  --resource-group rg-aks-lab-<yourinitials> \
  --cluster-name aks-lab-<yourinitials> \
  --name nodepool1 \
  --node-count 3

# Verify
kubectl get nodes
```

## Verification Checklist

Ensure you have successfully:
- [ ] Manually scaled deployments up and down
- [ ] Created and tested Horizontal Pod Autoscaler
- [ ] Enabled cluster autoscaler on node pool
- [ ] Tested node autoscaling with high pod count
- [ ] Monitored autoscaler behavior

## Summary of Scaling Concepts

### Horizontal Pod Autoscaler (HPA)
- **Purpose**: Scale pod replicas based on metrics
- **Use case**: Handle varying application load
- **Metrics**: CPU, memory, custom metrics
- **Scale range**: Min/Max replica count
- **Decision time**: Every 15-30 seconds

### Vertical Pod Autoscaler (VPA)
- **Purpose**: Adjust resource requests/limits
- **Use case**: Optimize resource allocation
- **Metrics**: Historical CPU/memory usage
- **Updates**: On pod creation or recreation
- **Best for**: Applications with unpredictable resource needs

### Cluster Autoscaler
- **Purpose**: Scale cluster nodes
- **Use case**: Handle overall cluster capacity
- **Trigger**: Pending pods due to insufficient resources
- **Scale up**: Adds nodes when pods can't be scheduled
- **Scale down**: Removes underutilized nodes (after 10-15 min)

## Troubleshooting

### Scaling Issues

- **HPA shows "no metrics returned" or "FailedGetResourceMetric"**:
  - This is normal during the first 1-2 minutes after creating pods
  - Metrics Server needs time to collect initial data
  - Solution: Wait 60-90 seconds and check again
  ```bash
  kubectl get hpa <hpa-name> --watch
  ```
  - Verify Metrics Server is running:
  ```bash
  kubectl get deployment metrics-server -n kube-system
  kubectl top pods
  ```

- **HPA not scaling**: Check metrics server and resource requests
  ```bash
  kubectl top pods
  kubectl describe hpa <hpa-name>
  ```

- **Nodes not autoscaling**: Check autoscaler logs
  ```bash
  kubectl logs -n kube-system -l app=cluster-autoscaler
  ```

- **Pods pending**: Check node resources
  ```bash
  kubectl describe node <node-name>
  kubectl top nodes
  ```

## Best Practices

### Scaling
- Start with HPA for application scaling
- Use cluster autoscaler for infrastructure scaling
- Set appropriate resource requests/limits
- Test autoscaling before production
- Monitor costs with autoscaling enabled
- Don't combine HPA and VPA on CPU/memory metrics

## Additional Resources

- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [AKS Cluster Autoscaler](https://docs.microsoft.com/azure/aks/cluster-autoscaler)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)

## Next Steps

Continue to Exercise 6 to learn about persistent storage in AKS!
