# Exercise 6: Persistent Storage in AKS

## Objective
In this exercise, you will learn how to configure persistent storage for your applications using Azure Disks and Azure Files. You'll understand the difference between ephemeral and persistent storage, and when to use each Azure storage option.

## Understanding Storage in Kubernetes

By default, pod storage is ephemeral (temporary). When a pod is deleted, its data is lost. Persistent storage is needed for:
- Databases
- User uploads
- Configuration data
- Logs

**Azure Storage Options for AKS**:
- **Azure Disks**: Block storage, can only be mounted to one pod at a time (ReadWriteOnce)
- **Azure Files**: SMB/NFS file shares, can be mounted to multiple pods (ReadWriteMany)
- **Azure Blob Storage**: Object storage via CSI driver

## Prerequisites
- Completed Exercise 4 (Applications exposed)
- Running AKS cluster with deployed applications
- kubectl configured

## Tasks

### Task 0: Test the non persistent nature of the actual configuration

1. Before to start with this task, make sure you have the sample application deployed and exposed as per Exercise 3 and 4.

2. Scale delete the HPA
    ```bash
    kubectl delete hpa backend-hpa
    ```
3. Make sure that the backend deployment is running with only one replica
    ```bash
    kubectl get deployment backend
    ```
4. If not, scale it to one replica
    ```bash
    kubectl scale deployment backend --replicas=1
    ```
5. Test the non-persistent nature of the current backend deployment:
   - Open your web browser
   - Navigate to `http://<EXTERNAL-IP>` 
   - Add a task in the UI (e.g., "Test persistent storage")
   - Delete the backend pod

      ```bash
      # Delete pod
      kubectl delete pod $POD_NAME
      
      # Wait for new pod to be created
      kubectl get pods -l app=backend --watch
      ```

      Press `Ctrl+C` to stop watching once the pod is running.

   - Refresh your browser
   - Now you can see that the task you added earlier is not there! This demonstrates that the data are ephemeral, only saved in the memory of the pod.

### Task 1: Understanding Storage Classes

Before creating persistent storage, let's explore the available storage classes in AKS.

1. **View available storage classes**
   ```bash
   kubectl get storageclass
   ```

   Some of the default classes in AKS are:
   - `managed-csi`: Azure Disk (default)
   - `azurefile-csi`: Azure Files
   - `managed-csi-premium`: Premium Azure Disk

2. **Describe a storage class**
   ```bash
   kubectl describe storageclass managed-csi
   ```

3. **View storage class details**
   ```bash
   kubectl get storageclass managed-csi -o yaml
   ```

### Task 2: Using Azure Disks with Persistent Volumes

Azure Disks provide block-level storage for single-pod applications like databases.
You can find the manifests for this exercise in the [`resources/exercise-06`](../resources/exercise-06/k8s-manifests) directory of the lab repository. Please review the configuration for the PersistentVolumeClaim (PVC) and StatefulSet files before proceeding.

1. **Create a Persistent Volume Claim (PVC) using Azure Disk**

   ```bash
   kubectl apply -f pvc.yaml
   ```

2. **Verify PVC creation**
   ```bash
   kubectl get pvc task-data-pvc
   ```

   Status should change from `Pending` to `Bound`.

3. **Create a StatefulSet for the backend that uses the PVC**
    First of all, delete the existing backend deployment if you have it running:
    ```bash
    kubectl delete deployment backend
    ```

    It is not required to delete the Service, as it will remain the same.

    Remember to update the image name in the `backend-stateful.yaml` file with your actual backend image from your ACR.

    Apply the manifest:
    ```bash
      kubectl apply -f backend-stateful.yaml
    ```

4. **View the automatically created Persistent Volume**
   ```bash
   kubectl get pv
   ```

5. **Wait for pod to be ready**
   ```bash
   kubectl get pods -l app=backend --watch
   ```

   You will see something like:
   ```
   NAME                        READY   STATUS    RESTARTS   AGE
   backend-0                   1/1     Running   0          30s
   ```

   Press `Ctrl+C` to stop watching.

6. **Test persistence by deleting and recreating the pod**

   - Open your web browser
   - Navigate to `http://<EXTERNAL-IP>`
   - Add a task in the UI
   - Delete the backend pod

      ```bash
      # Delete pod
      kubectl delete pod $POD_NAME
      
      # Wait for new pod to be created
      kubectl get pods -l app=backend --watch
      ```

      Press `Ctrl+C` to stop watching once the pod is running.

   - Refresh your browser
   - Now you can see that the task you added earlier is still there! This demonstrates that the Azure Disk persists beyond the pod lifecycle.

> [!WARNING]
> The following tasks are optional. You can skip them if you only want to learn about Azure Disks. If instead you want to learn about Azure Files, continue with the next task, but notice that the commands are just examples for reference, not directly aligned with the sample application and the manifests provided. 

### Task 3: Using Azure Files for Shared Storage

Azure Files allows multiple pods to mount the same volume simultaneously, making it ideal for shared content.

1. **Create a PVC using Azure Files**

   ```bash
   cat > azure-files-pvc.yaml <<EOF
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: azure-files-pvc
   spec:
     accessModes:
     - ReadWriteMany
     storageClassName: azurefile-csi
     resources:
       requests:
         storage: 5Gi
   EOF
   ```

   Apply the PVC:
   ```bash
   kubectl apply -f azure-files-pvc.yaml
   ```

2. **Verify PVC is bound**
   ```bash
   kubectl get pvc azure-files-pvc
   ```

3. **Create a deployment with multiple replicas using shared storage**

   ```bash
   cat > app-with-shared-storage.yaml <<EOF
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: app-with-shared-storage
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: shared-app
     template:
       metadata:
         labels:
           app: shared-app
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           volumeMounts:
           - name: shared-data
             mountPath: /shared
         volumes:
         - name: shared-data
           persistentVolumeClaim:
             claimName: azure-files-pvc
   EOF
   ```

   Apply the deployment:
   ```bash
   kubectl apply -f app-with-shared-storage.yaml
   ```

4. **Wait for all pods to be ready**
   ```bash
   kubectl get pods -l app=shared-app
   ```

5. **Write data from one pod and read from another**

   ```bash
   # Get pod names
   PODS=($(kubectl get pods -l app=shared-app -o jsonpath='{.items[*].metadata.name}'))
   
   # Write from first pod
   kubectl exec ${PODS[0]} -- bash -c "echo 'Shared data from pod 1' > /shared/shared-file.txt"
   
   # Read from second pod
   kubectl exec ${PODS[1]} -- cat /shared/shared-file.txt
   
   # Read from third pod
   kubectl exec ${PODS[2]} -- cat /shared/shared-file.txt
   ```

   All pods can read the same file! This demonstrates the ReadWriteMany capability of Azure Files.

6. **Write from multiple pods**
   ```bash
   # Each pod writes to a different file
   kubectl exec ${PODS[0]} -- bash -c "echo 'Data from pod 0' > /shared/pod-0.txt"
   kubectl exec ${PODS[1]} -- bash -c "echo 'Data from pod 1' > /shared/pod-1.txt"
   kubectl exec ${PODS[2]} -- bash -c "echo 'Data from pod 2' > /shared/pod-2.txt"
   
   # List files from any pod
   kubectl exec ${PODS[0]} -- ls -la /shared/
   ```

### Task 4: View Storage Resources in Azure Portal

1. **View Persistent Volumes in Kubernetes**
   ```bash
   kubectl get pv
   kubectl describe pv <pv-name>
   ```

2. **In Azure Portal**
   - Navigate to your resource group `rg-aks-lab-<yourinitials>`
   - You'll see **Disk** resources (for Azure Disks)
   - You'll see a **Storage Account** (for Azure Files)
   - Click on them to view details, size, and pricing tier

3. **View PVC details**
   ```bash
   kubectl get pvc
   kubectl describe pvc azure-disk-pvc
   kubectl describe pvc azure-files-pvc
   ```

### Task 5: Comparison - Azure Disks vs Azure Files

Let's test the key difference: Azure Disks can only be mounted to one pod, while Azure Files can be shared.

1. **Try to scale the Azure Disk deployment to 2 replicas**
   ```bash
   kubectl scale deployment app-with-disk --replicas=2
   kubectl get pods -l app=app-with-disk
   ```

2. **Check pod status**
   ```bash
   kubectl describe pod -l app=app-with-disk
   ```

   You'll likely see one pod running and another stuck in `ContainerCreating` or `Pending` state because Azure Disks only support ReadWriteOnce (single node attachment).

3. **Scale back to 1 replica**
   ```bash
   kubectl scale deployment app-with-disk --replicas=1
   ```

4. **Compare with Azure Files deployment** (already has 3 replicas)
   ```bash
   kubectl get pods -l app=shared-app
   ```

   All 3 pods are running because Azure Files supports ReadWriteMany.

**Key Takeaway**:
- **Azure Disks**: Use for databases, single-pod applications
- **Azure Files**: Use for shared content, multi-pod applications

### Task 6: Update Your Sample Application with Persistent Storage

Let's update your sample application to use persistent storage:

```bash
cat > sample-app-with-storage.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sample-app-data
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-csi
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app-persistent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app-persistent
  template:
    metadata:
      labels:
        app: sample-app-persistent
    spec:
      containers:
      - name: app
        image: <your-acr>.azurecr.io/sample-app:v1
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: sample-app-data
EOF
```

Apply the configuration:
```bash
kubectl apply -f sample-app-with-storage.yaml
```

Verify the deployment:
```bash
kubectl get pods -l app=sample-app-persistent
kubectl get pvc sample-app-data
```

### Task 7: Storage Performance Tiers

Azure offers different performance tiers for storage:

1. **View storage class options**
   ```bash
   kubectl get storageclass
   ```

2. **Create a PVC with Premium storage** (for high-performance workloads)
   ```bash
   cat > azure-disk-premium-pvc.yaml <<EOF
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: premium-disk-pvc
   spec:
     accessModes:
     - ReadWriteOnce
     storageClassName: managed-csi-premium
     resources:
       requests:
         storage: 5Gi
   EOF
   ```

   Apply (optional - premium disks cost more):
   ```bash
   kubectl apply -f azure-disk-premium-pvc.yaml
   ```

**Performance Comparison**:
- **Standard**: Lower cost, suitable for dev/test
- **Premium**: Higher IOPS/throughput, suitable for production databases

## Verification Checklist

Ensure you have successfully:
- [ ] Created persistent volume claims
- [ ] Deployed applications with Azure Disk storage
- [ ] Verified data persists after pod deletion
- [ ] Created and tested Azure Files shared storage
- [ ] Accessed shared files from multiple pods
- [ ] Viewed storage resources in Azure Portal
- [ ] Understood the difference between Azure Disks and Azure Files

## Troubleshooting

### Storage Issues

- **PVC stuck in Pending**:
  ```bash
  kubectl describe pvc <pvc-name>
  ```
  Check for quota limits or storage class issues

- **Mount failures**:
  ```bash
  kubectl describe pod <pod-name>
  ```
  Check for permission issues or already-mounted disks (Azure Disk limitation)

- **Data not persisting**: 
  - Verify PVC is bound: `kubectl get pvc`
  - Check mount path in pod: `kubectl describe pod <pod-name>`
  - Ensure correct volume name in deployment YAML

- **Multiple pods can't mount Azure Disk**:
  - This is expected behavior (ReadWriteOnce)
  - Use Azure Files (ReadWriteMany) for multi-pod scenarios

## Best Practices

### Storage Selection
- Use **Azure Disks** for:
  - Databases (PostgreSQL, MySQL, MongoDB)
  - Single-pod applications requiring persistent data
  - High-performance workloads (use Premium tier)
  
- Use **Azure Files** for:
  - Shared content across multiple pods
  - Legacy applications requiring SMB/NFS
  - Content management systems
  - Shared configuration files

### Storage Management
- Choose appropriate storage class (Standard vs Premium)
- Set appropriate storage size (can be expanded later)
- Implement backup strategies for critical data
- Use storage quotas to control costs
- Monitor storage usage and performance
- Clean up unused PVCs to avoid charges

### Data Persistence
- Always use PVCs for stateful applications
- Test data persistence before production
- Document mount paths and storage requirements
- Use init containers for data initialization
- Consider using StatefulSets for complex stateful applications

## Additional Resources

- [AKS Storage Options](https://docs.microsoft.com/azure/aks/concepts-storage)
- [Azure Disk CSI Driver](https://docs.microsoft.com/azure/aks/azure-disk-csi)
- [Azure Files CSI Driver](https://docs.microsoft.com/azure/aks/azure-files-csi)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## Congratulations!

You've completed all the core AKS exercises! You now know how to:
- ✅ Set up an AKS environment
- ✅ Create and manage container registries
- ✅ Deploy and expose applications
- ✅ Implement autoscaling at pod and node levels
- ✅ Configure persistent storage with Azure Disks and Azure Files

## Next Steps

Continue learning about:
- **Ingress controllers** (NGINX, Application Gateway) for advanced routing
- **Azure Monitor and Application Insights** for observability
- **Azure Policy for AKS** for governance
- **GitOps** with Flux or ArgoCD for declarative deployments
- **Service Mesh** (Istio, Linkerd) for advanced networking
- **Security best practices** (Pod Security Standards, Network Policies)
- **Backup and disaster recovery** with Velero
- **StatefulSets** for complex stateful applications
