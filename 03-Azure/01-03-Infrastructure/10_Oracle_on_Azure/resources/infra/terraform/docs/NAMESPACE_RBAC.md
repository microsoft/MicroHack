# Kubernetes Namespace-Based Access Control (RBAC)

## Overview

This document describes the namespace-based RBAC implementation that restricts users to the `microhack` namespace within their AKS clusters. This security model ensures users can only deploy and manage workloads in a specific namespace, preventing unauthorized access to cluster-wide resources.

---

## Architecture

### Previous Model (Insecure - Removed)

```
User (user00@cptazure.org)
  └─ Azure RBAC: "Azure Kubernetes Service RBAC Writer" (Cluster-wide)
      └─ Full access to ALL namespaces
          ├─ default ✅ (can deploy)
          ├─ kube-system ✅ (can deploy)
          ├─ microhack ✅ (can deploy)
          └─ ANY custom namespace ✅ (can create and deploy)
```

**Problem:** Users had unrestricted access to the entire cluster, including system namespaces.

### Current Model (Secure - Implemented)

```
User (user00@cptazure.org)
  ├─ Azure RBAC: "Azure Kubernetes Service Cluster User Role"
  │   └─ Allows getting kubeconfig (kubectl access) ✅
  │
  └─ Kubernetes RBAC: RoleBinding in "microhack" namespace
      └─ Role: "microhack-deployer"
          └─ ONLY access to "microhack" namespace
              ├─ default ❌ (cannot deploy)
              ├─ kube-system ❌ (cannot deploy)
              ├─ microhack ✅ (can deploy - ONLY THIS)
              └─ OTHER namespaces ❌ (cannot create or access)
```

**Solution:** Users can ONLY interact with the `microhack` namespace. All other namespaces are inaccessible.

---

## Components

### 1. Namespace: `microhack`

**File:** `modules/aks/kubernetes-rbac.tf`

```hcl
resource "kubernetes_namespace" "microhack" {
  metadata {
    name = "microhack"
    labels = {
      name         = "microhack"
      environment  = "training"
      managed-by   = "terraform"
      purpose      = "user-workloads"
    }
  }
}
```

**Purpose:**
- Dedicated namespace for all user workload deployments
- Isolated from system namespaces (kube-system, default, etc.)
- Managed by Terraform for consistency across all AKS clusters

**Properties:**
- Name: `microhack`
- Created in: Each AKS cluster (aks-user00 through aks-user04)
- Lifecycle: Managed by Terraform (created with cluster, destroyed with cluster)

### 2. Role: `microhack-deployer`

**File:** `modules/aks/kubernetes-rbac.tf`

**Permissions Granted (within `microhack` namespace only):**

| Resource Type | API Group | Verbs | Description |
|---------------|-----------|-------|-------------|
| **Pods** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on pods |
| **Services** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on services |
| **ConfigMaps** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on config maps |
| **Secrets** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on secrets |
| **PVCs** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on persistent volume claims |
| **ServiceAccounts** | "" (core) | get, list, watch, create, update, patch, delete | Full CRUD on service accounts |
| **Deployments** | apps | get, list, watch, create, update, patch, delete | Full CRUD on deployments |
| **ReplicaSets** | apps | get, list, watch, create, update, patch, delete | Full CRUD on replica sets |
| **StatefulSets** | apps | get, list, watch, create, update, patch, delete | Full CRUD on stateful sets |
| **DaemonSets** | apps | get, list, watch, create, update, patch, delete | Full CRUD on daemon sets |
| **Jobs** | batch | get, list, watch, create, update, patch, delete | Full CRUD on jobs |
| **CronJobs** | batch | get, list, watch, create, update, patch, delete | Full CRUD on cron jobs |
| **Ingresses** | networking.k8s.io | get, list, watch, create, update, patch, delete | Full CRUD on ingresses |
| **NetworkPolicies** | networking.k8s.io | get, list, watch, create, update, patch, delete | Full CRUD on network policies |
| **HorizontalPodAutoscalers** | autoscaling | get, list, watch, create, update, patch, delete | Full CRUD on HPAs |
| **PodDisruptionBudgets** | policy | get, list, watch, create, update, patch, delete | Full CRUD on PDBs |
| **Events** | "" (core) | get, list, watch | Read-only access to events |
| **Roles** | rbac.authorization.k8s.io | get, list, watch | Read-only access to roles |
| **RoleBindings** | rbac.authorization.k8s.io | get, list, watch | Read-only access to role bindings |

**What Users CAN Do:**
- ✅ Deploy applications (deployments, pods, services)
- ✅ Create and manage configurations (configmaps, secrets)
- ✅ Set up ingress for external access
- ✅ Configure autoscaling (HPA)
- ✅ Run batch jobs and cron jobs
- ✅ Create stateful applications (StatefulSets)
- ✅ View logs and events for troubleshooting
- ✅ Manage network policies within the namespace

**What Users CANNOT Do:**
- ❌ Access other namespaces (default, kube-system, etc.)
- ❌ Create new namespaces
- ❌ View or modify cluster-wide resources (ClusterRoles, ClusterRoleBindings)
- ❌ Modify node settings or cluster configuration
- ❌ Access other users' resources (each user has their own cluster)
- ❌ Create PersistentVolumes (only PersistentVolumeClaims)
- ❌ Modify RBAC settings (cannot escalate privileges)

### 3. RoleBinding: `{user}-microhack-binding`

**File:** `modules/aks/kubernetes-rbac.tf`

**Purpose:** Binds the user's Entra ID identity to the `microhack-deployer` Role within the `microhack` namespace.

**Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: user00-microhack-binding
  namespace: microhack
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: microhack-deployer
subjects:
- kind: User
  name: user00@cptazure.org  # Entra ID UPN
  apiGroup: rbac.authorization.k8s.io
```

**Binding Details:**
- **User:** Entra ID principal name (e.g., `user00@cptazure.org`)
- **Role:** `microhack-deployer`
- **Scope:** `microhack` namespace only
- **Result:** User can perform all actions defined in the Role, but ONLY within `microhack` namespace

---

## Azure RBAC vs Kubernetes RBAC

### Understanding the Two Layers

| Aspect | Azure RBAC | Kubernetes RBAC |
|--------|------------|-----------------|
| **Scope** | Azure resources (AKS cluster, subscriptions, RGs) | Kubernetes objects (pods, services, namespaces) |
| **Manages Access To** | Getting kubeconfig, viewing cluster in Azure Portal | Deploying workloads, creating resources in cluster |
| **Assignment Level** | Subscription, Resource Group, or Cluster | Cluster-wide (ClusterRole) or Namespace (Role) |
| **Identity Provider** | Entra ID (Azure AD) | Kubernetes (mapped from Entra ID) |
| **Configuration** | Terraform azurerm_role_assignment | Terraform kubernetes_role_binding |

### Our Implementation

#### Azure RBAC (Kept)
- **Role:** `Azure Kubernetes Service Cluster User Role`
- **Scope:** AKS Cluster (e.g., aks-user00)
- **Purpose:** Allows user to run `az aks get-credentials` to obtain kubeconfig
- **Result:** User can connect to cluster with kubectl

#### Kubernetes RBAC (New)
- **Role:** `microhack-deployer` (custom Kubernetes Role)
- **Scope:** `microhack` namespace only
- **Purpose:** Defines what user can do INSIDE the cluster
- **Result:** User can deploy workloads only to `microhack` namespace

**Why Both Are Needed:**
1. **Azure RBAC** gets you INTO the cluster (kubeconfig)
2. **Kubernetes RBAC** determines what you can DO inside the cluster

---

## Deployment

### Files Modified

1. **versions.tf**
   - Added `kubernetes` provider requirement (~> 2.30)

2. **modules/aks/variables.tf**
   - Added `deployment_user_principal_name` (UPN for RoleBinding)
   - Added `deployment_user_name` (short name for labels)

3. **modules/aks/kubernetes-rbac.tf** (NEW)
   - Kubernetes provider configuration
   - `kubernetes_namespace.microhack` resource
   - `kubernetes_role.microhack_deployer` resource
   - `kubernetes_role_binding.user_microhack` resource

4. **modules/aks/main.tf**
   - **REMOVED:** `azurerm_role_assignment.aks_rbac_writer` (cluster-wide access)
   - Added extensive comments explaining why it was removed

5. **modules/aks/outputs.tf**
   - Removed `rbac_writer_assignment` from outputs
   - Added comment explaining replacement with Kubernetes RBAC

6. **main.tf**
   - Updated all 5 `module.aks_slot_*` calls to pass new variables:
     * `deployment_user_principal_name`
     * `deployment_user_name`

### Deployment Steps

```bash
# 1. Initialize Terraform (downloads kubernetes provider)
terraform init

# 2. Validate configuration
terraform validate

# 3. Review planned changes
terraform plan

# 4. Apply changes (creates namespace + RBAC in all clusters)
terraform apply

# 5. Verify namespace creation
kubectl get namespace microhack

# 6. Verify RBAC configuration
kubectl get role -n microhack
kubectl get rolebinding -n microhack
```

---

## Testing & Validation

### 1. Verify Namespace Exists

```bash
# Connect to user's AKS cluster
az login -u user00@cptazure.org
az aks get-credentials --resource-group rg-aks-user00 --name aks-user00

# Check namespace
kubectl get namespace microhack
# Expected output:
# NAME        STATUS   AGE
# microhack   Active   10m
```

### 2. Test Namespace Access - ALLOWED

```bash
# Deploy to microhack namespace (should SUCCEED)
kubectl create deployment nginx --image=nginx -n microhack
kubectl get pods -n microhack

# Create a service (should SUCCEED)
kubectl expose deployment nginx --port=80 --type=ClusterIP -n microhack
kubectl get svc -n microhack

# View logs (should SUCCEED)
kubectl logs deployment/nginx -n microhack

# Clean up
kubectl delete deployment nginx -n microhack
kubectl delete service nginx -n microhack
```

### 3. Test Default Namespace Access - DENIED

```bash
# Try to deploy to default namespace (should FAIL)
kubectl create deployment nginx --image=nginx -n default

# Expected error:
# Error from server (Forbidden): deployments.apps is forbidden: 
# User "user00@cptazure.org" cannot create resource "deployments" 
# in API group "apps" in the namespace "default"
```

### 4. Test Kube-System Access - DENIED

```bash
# Try to view pods in kube-system (should FAIL)
kubectl get pods -n kube-system

# Expected error:
# Error from server (Forbidden): pods is forbidden: 
# User "user00@cptazure.org" cannot list resource "pods" 
# in API group "" in the namespace "kube-system"
```

### 5. Test Namespace Creation - DENIED

```bash
# Try to create a new namespace (should FAIL)
kubectl create namespace test

# Expected error:
# Error from server (Forbidden): namespaces is forbidden: 
# User "user00@cptazure.org" cannot create resource "namespaces" 
# in API group "" at the cluster scope
```

### 6. Test Authorization with kubectl auth can-i

```bash
# Check microhack namespace permissions (should be "yes")
kubectl auth can-i create pods -n microhack
kubectl auth can-i create deployments -n microhack
kubectl auth can-i create services -n microhack

# Check default namespace permissions (should be "no")
kubectl auth can-i create pods -n default
kubectl auth can-i create deployments -n default

# Check cluster-wide permissions (should be "no")
kubectl auth can-i create namespaces
kubectl auth can-i get nodes
```

**Expected Results:**
```
✅ kubectl auth can-i create pods -n microhack → yes
✅ kubectl auth can-i create deployments -n microhack → yes
❌ kubectl auth can-i create pods -n default → no
❌ kubectl auth can-i create namespaces → no
❌ kubectl auth can-i get nodes → no
```

---

## User Guide

### Getting Started

1. **Log in to Azure:**
   ```bash
   az login -u user00@cptazure.org
   ```

2. **Get AKS credentials:**
   ```bash
   az aks get-credentials --resource-group rg-aks-user00 --name aks-user00
   ```

3. **Verify access:**
   ```bash
   kubectl get namespace microhack
   ```

### Deploying Applications

**Always specify `-n microhack` or set default namespace:**

```bash
# Option 1: Specify namespace in every command
kubectl create deployment myapp --image=nginx -n microhack
kubectl get pods -n microhack

# Option 2: Set microhack as default namespace (recommended)
kubectl config set-context --current --namespace=microhack

# Now all commands default to microhack
kubectl create deployment myapp --image=nginx
kubectl get pods
```

### Example Deployment

```bash
# Set default namespace
kubectl config set-context --current --namespace=microhack

# Deploy application
kubectl create deployment webapp --image=nginx:latest --replicas=3

# Expose service
kubectl expose deployment webapp --port=80 --type=LoadBalancer

# Check status
kubectl get pods
kubectl get svc

# View logs
kubectl logs deployment/webapp

# Scale deployment
kubectl scale deployment webapp --replicas=5

# Clean up
kubectl delete deployment webapp
kubectl delete service webapp
```

### Using YAML Manifests

Ensure `namespace: microhack` is specified in your YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: microhack  # ← IMPORTANT
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: microhack  # ← IMPORTANT
spec:
  selector:
    app: myapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
```

Apply the manifest:
```bash
kubectl apply -f deployment.yaml
```

---

## Troubleshooting

### Error: "Forbidden: User cannot create resource"

**Symptom:**
```
Error from server (Forbidden): deployments.apps is forbidden: 
User "user00@cptazure.org" cannot create resource "deployments" 
in API group "apps" in the namespace "default"
```

**Cause:** User trying to deploy to a namespace other than `microhack`.

**Solution:**
1. Always specify `-n microhack` in commands
2. Set default namespace: `kubectl config set-context --current --namespace=microhack`
3. Ensure YAML manifests include `namespace: microhack`

### Error: "Cannot get kubeconfig"

**Symptom:**
```
az aks get-credentials fails with permission error
```

**Cause:** Azure RBAC not properly configured (missing Cluster User Role).

**Solution:**
Verify Azure RBAC assignment exists:
```bash
az role assignment list --assignee user00@cptazure.org \
  --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/aks-user00
```

Should see "Azure Kubernetes Service Cluster User Role" assigned.

### Namespace Not Found

**Symptom:**
```
Error from server (NotFound): namespaces "microhack" not found
```

**Cause:** Terraform not applied or namespace creation failed.

**Solution:**
```bash
# Re-apply Terraform
terraform apply

# Verify namespace exists
kubectl get namespace microhack
```

### Checking Your Permissions

```bash
# See all your permissions in microhack namespace
kubectl auth can-i --list -n microhack

# Check specific permission
kubectl auth can-i create pods -n microhack
kubectl auth can-i delete deployments -n microhack
```

---

## Security Considerations

### Why Namespace Restrictions?

1. **Principle of Least Privilege:** Users only have access to resources they need
2. **Blast Radius Limitation:** Mistakes confined to `microhack` namespace, not entire cluster
3. **System Protection:** kube-system and other critical namespaces are protected
4. **Multi-Tenancy:** Clear separation between users (each has own cluster + restricted namespace)

### What's Protected?

| Resource | Protection Level | Reason |
|----------|-----------------|---------|
| **kube-system namespace** | ❌ No access | Contains critical cluster components |
| **default namespace** | ❌ No access | Prevent cluttering default namespace |
| **Other namespaces** | ❌ No access | Users shouldn't see each other's work |
| **Cluster-level resources** | ❌ No access | Nodes, ClusterRoles, PVs are admin-only |
| **microhack namespace** | ✅ Full access | User's workspace for deployments |

### Privilege Escalation Prevention

Users CANNOT:
- Modify their own RBAC (Role, RoleBinding are read-only)
- Create ClusterRoles or ClusterRoleBindings
- Bind to existing ClusterRoles
- Create new namespaces
- Access ServiceAccounts in other namespaces

---

## Comparison with Previous Model

| Aspect | Previous (Insecure) | Current (Secure) |
|--------|---------------------|------------------|
| **Azure RBAC** | AKS RBAC Writer (cluster-wide) | Cluster User Role (kubeconfig only) |
| **Kubernetes RBAC** | None (inherited from Azure) | Namespace-scoped Role + RoleBinding |
| **Accessible Namespaces** | ALL (default, kube-system, etc.) | ONLY microhack |
| **Can Create Namespaces** | ✅ Yes | ❌ No |
| **Can Access kube-system** | ✅ Yes | ❌ No |
| **Can Modify RBAC** | ✅ Yes (via Azure RBAC) | ❌ No (read-only) |
| **Security Model** | Trust-based (admin access) | Zero-trust (explicit permissions) |
| **Blast Radius** | Entire cluster | Single namespace |

---

## Maintenance & Updates

### Adding New Permissions

If users need additional permissions (e.g., access to Custom Resource Definitions):

1. **Update the Role** in `modules/aks/kubernetes-rbac.tf`:
   ```hcl
   rule {
     api_groups = ["example.com"]
     resources  = ["customresources"]
     verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
   }
   ```

2. **Apply changes:**
   ```bash
   terraform apply
   ```

### Creating Additional Namespaces

If you need a second namespace for a different purpose:

1. **Add new namespace resource:**
   ```hcl
   resource "kubernetes_namespace" "staging" {
     metadata {
       name = "staging"
     }
   }
   ```

2. **Create Role and RoleBinding for new namespace:**
   ```hcl
   resource "kubernetes_role" "staging_deployer" {
     metadata {
       name      = "staging-deployer"
       namespace = kubernetes_namespace.staging.metadata[0].name
     }
     # ... rules ...
   }
   
   resource "kubernetes_role_binding" "user_staging" {
     metadata {
       name      = "${var.deployment_user_name}-staging-binding"
       namespace = kubernetes_namespace.staging.metadata[0].name
     }
     # ... binding configuration ...
   }
   ```

### Re-enabling Cluster-Wide Access (NOT RECOMMENDED)

If absolutely necessary, uncomment the Azure RBAC Writer assignment in `modules/aks/main.tf`:

```hcl
resource "azurerm_role_assignment" "aks_rbac_writer" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.deployment_user_object_id
}
```

⚠️ **WARNING:** This grants full cluster access and defeats the security model.

---

## Related Documentation

- [RBAC_SUMMARY.md](./RBAC_SUMMARY.md) - Complete access rights per user
- [VNET_ISOLATION_CORRECT.md](./VNET_ISOLATION_CORRECT.md) - Network isolation architecture
- [CLOUDSHELL_SHARED_STORAGE.md](./CLOUDSHELL_SHARED_STORAGE.md) - Cloud Shell configuration
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Azure Kubernetes Service RBAC](https://learn.microsoft.com/en-us/azure/aks/azure-ad-rbac)

---

## Summary

✅ **Users NOW have:**
- Access to `microhack` namespace only
- Full deployment capabilities within their namespace
- Protection from accidental system modifications
- Clear security boundaries

❌ **Users NO LONGER have:**
- Cluster-wide admin access
- Ability to create/access other namespaces
- Access to kube-system or other system namespaces
- Ability to modify cluster-level resources

This model balances **usability** (users can deploy applications freely) with **security** (restricted to safe boundaries).
