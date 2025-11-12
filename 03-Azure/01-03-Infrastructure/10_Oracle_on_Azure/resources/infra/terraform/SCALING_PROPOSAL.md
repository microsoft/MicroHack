# Scaling Beyond 5 Users - Architecture Proposal

## Current Limitation

The infrastructure is limited to 5 users due to Terraform's requirement for **statically defined provider aliases**. The helm provider configuration in `helm-providers.tf` hard-codes 5 provider instances (slot_0 through slot_4), creating a 1:1 mapping constraint between subscriptions and AKS clusters.

### Root Cause
```terraform
provider "helm" {
  alias = "aks_deployment_slot_0"  # Static - cannot be created dynamically
  kubernetes { ... }
}
```

Terraform does not support dynamic provider generation at runtime, which prevents scaling beyond the pre-defined number of slots.

---

## Proposed Solutions

### **Solution 1: Post-Provisioning Helm Deployment (Recommended)**

Remove ingress-nginx deployment from Terraform and deploy it using a separate automation layer after AKS clusters are provisioned.

#### Implementation Approach

**Step 1:** Remove ingress-nginx modules from Terraform
- Delete `modules/ingress-nginx/` 
- Remove all `module "ingress_nginx_slot_*"` blocks from `main.tf`
- Remove helm provider configuration from `helm-providers.tf`

**Step 2:** Create PowerShell deployment script
```powershell
# deploy-ingress-controllers.ps1
param(
    [Parameter(Mandatory=$true)]
    [int]$UserCount
)

# Get AKS cluster credentials and deploy helm charts
for ($i = 0; $i -lt $UserCount; $i++) {
    $clusterName = "aks-user$('{0:D2}' -f $i)"
    $rgName = "aks-user$('{0:D2}' -f $i)"
    
    # Get credentials
    az aks get-credentials --name $clusterName --resource-group $rgName --overwrite-existing
    
    # Install ingress-nginx
    helm upgrade --install nginx-quick ingress-nginx/ingress-nginx `
        --repo https://kubernetes.github.io/ingress-nginx `
        --version 4.14.0 `
        --namespace ingress-nginx `
        --create-namespace `
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    
    Write-Host "✓ Deployed ingress-nginx to $clusterName"
}
```

**Step 3:** Update deployment workflow
```
1. terraform apply (provisions AKS clusters)
2. .\deploy-ingress-controllers.ps1 -UserCount 10 (deploys helm charts)
```

#### Benefits
- ✅ Supports unlimited users (10, 20, 50+)
- ✅ Simpler Terraform code
- ✅ Faster Terraform apply/destroy cycles
- ✅ More flexible for operational changes
- ✅ Industry standard pattern (IaC for infrastructure, GitOps/scripts for applications)
- ✅ Easier to troubleshoot and update helm releases independently

#### Considerations
- Requires separate deployment step
- Need to manage PowerShell/bash scripts
- Not "pure" Terraform

---

### **Solution 2: Dynamic Helm via null_resource + local-exec**

Use Terraform's `null_resource` with `local-exec` provisioner to run helm commands directly, bypassing the provider limitation.

#### Implementation Changes

**File: `main.tf`**
```terraform
# Replace all ingress_nginx_slot modules with:
resource "null_resource" "ingress_nginx_deployment" {
  for_each = local.deployments

  depends_on = [
    module.aks_slot_0,
    module.aks_slot_1,
    module.aks_slot_2,
    module.aks_slot_3,
    module.aks_slot_4,
  ]

  triggers = {
    cluster_id = module.aks_slot_${each.value.provider_index}[each.key].cluster_id
    version    = "4.14.0"  # Update this to force redeployment
  }

  provisioner "local-exec" {
    command = <<-EOT
      az aks get-credentials `
        --name aks-${each.value.name} `
        --resource-group aks-${each.value.name} `
        --subscription ${each.value.subscription_id} `
        --overwrite-existing `
        --file $env:TEMP/kubeconfig-${each.value.name}
      
      $env:KUBECONFIG = "$env:TEMP/kubeconfig-${each.value.name}"
      
      helm upgrade --install nginx-quick ingress-nginx/ingress-nginx `
        --repo https://kubernetes.github.io/ingress-nginx `
        --version 4.14.0 `
        --namespace ingress-nginx `
        --create-namespace `
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
    EOT
    interpreter = ["pwsh", "-Command"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      az aks get-credentials `
        --name aks-${each.value.name} `
        --resource-group aks-${each.value.name} `
        --subscription ${each.value.subscription_id} `
        --overwrite-existing `
        --file $env:TEMP/kubeconfig-${each.value.name}
      
      $env:KUBECONFIG = "$env:TEMP/kubeconfig-${each.value.name}"
      
      helm uninstall nginx-quick --namespace ingress-nginx
    EOT
    interpreter = ["pwsh", "-Command"]
    on_failure  = continue
  }
}
```

#### Benefits
- ✅ Keeps everything in Terraform
- ✅ Supports unlimited users
- ✅ Automatic cleanup on destroy

#### Considerations
- ⚠️ Requires `az` CLI and `helm` CLI installed on the machine running Terraform
- ⚠️ State drift risk (Terraform tracks triggers, not actual helm state)
- ⚠️ Less reliable error handling
- ⚠️ Harder to debug failures
- ⚠️ Not idempotent if helm upgrade fails mid-apply

---

### **Solution 3: Hybrid Approach with Kubernetes Provider**

Use Terraform's kubernetes provider with dynamic credentials instead of helm provider.

#### Implementation Overview
```terraform
# Deploy manifests directly instead of helm charts
resource "kubernetes_manifest" "ingress_nginx" {
  for_each = local.deployments

  manifest = yamldecode(file("${path.module}/manifests/ingress-nginx-${each.key}.yaml"))
  
  # Use exec credential plugin for dynamic authentication
  ...
}
```

#### Benefits
- ✅ Pure Terraform
- ✅ Supports unlimited users

#### Considerations
- ⚠️ More complex - need to convert helm chart to raw Kubernetes manifests
- ⚠️ Harder to maintain (100+ manifest resources)
- ⚠️ Less flexible than helm

---

## Recommended Implementation: Solution 1

### Reasoning
1. **Scalability**: No artificial limits on user count
2. **Separation of Concerns**: IaC (Terraform) for infrastructure, deployment tools for applications
3. **Production Ready**: Matches industry patterns (Terraform + ArgoCD/Flux/Scripts)
4. **Maintainability**: Easier to update helm charts without terraform apply
5. **Performance**: Faster terraform operations (no helm provider overhead)

### Migration Steps

1. **Backup current state**
   ```bash
   terraform state pull > terraform.tfstate.backup
   ```

2. **Create deployment script** (see Solution 1 above)

3. **Remove helm resources from state**
   ```bash
   # Remove all ingress_nginx resources from state
   terraform state list | Select-String "ingress_nginx" | ForEach-Object { terraform state rm $_ }
   ```

4. **Update Terraform code**
   - Remove `helm-providers.tf`
   - Remove ingress-nginx module calls from `main.tf`
   - Remove `modules/ingress-nginx/` directory

5. **Test with 10 users**
   ```bash
   # Update terraform.tfvars
   user_count = 10
   
   # Apply infrastructure
   terraform apply -auto-approve
   
   # Deploy ingress controllers
   .\deploy-ingress-controllers.ps1 -UserCount 10
   ```

6. **Validate**
   ```bash
   # Check all clusters have ingress controller
   for ($i=0; $i -lt 10; $i++) {
       $cluster = "aks-user$('{0:D2}' -f $i)"
       az aks get-credentials --name $cluster --resource-group $cluster --overwrite-existing
       kubectl get pods -n ingress-nginx
   }
   ```

---

## Alternative: Quick Win with More Subscriptions

If you want to keep the current architecture temporarily, you can:

1. Add 5 more subscriptions to `terraform.tfvars`:
   ```hcl
   subscription_targets = [
     { subscription_id = "...", tenant_id = "..." },  # slot 0
     { subscription_id = "...", tenant_id = "..." },  # slot 1
     { subscription_id = "...", tenant_id = "..." },  # slot 2
     { subscription_id = "...", tenant_id = "..." },  # slot 3
     { subscription_id = "...", tenant_id = "..." },  # slot 4
     { subscription_id = "...", tenant_id = "..." },  # slot 5 (reuse slot 0)
     { subscription_id = "...", tenant_id = "..." },  # slot 6 (reuse slot 1)
     { subscription_id = "...", tenant_id = "..." },  # slot 7 (reuse slot 2)
     { subscription_id = "...", tenant_id = "..." },  # slot 8 (reuse slot 3)
     { subscription_id = "...", tenant_id = "..." },  # slot 9 (reuse slot 4)
   ]
   user_count = 10
   ```

This maintains 1:1 mapping (10 users across 10 subscriptions, reusing 5 helm provider slots with modulo assignment).

**Limitation**: Still capped at increments of 5 (5, 10, 15, 20...) due to provider slot reuse.

---

## Conclusion

**For production scalability, implement Solution 1.** It's the cleanest, most maintainable, and industry-standard approach.

**For a quick prototype with 10 users, add 5 more subscriptions** as shown in the alternative approach.

Let me know which solution you'd like to implement!
