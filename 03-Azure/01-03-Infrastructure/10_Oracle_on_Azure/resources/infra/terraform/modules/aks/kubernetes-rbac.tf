# ===============================================================================
# Kubernetes RBAC Configuration - Namespace Restriction
# ===============================================================================
# Restricts users to "microhack" namespace only using Kubernetes RBAC.
# Uses null_resource + kubectl (not kubernetes provider due to for_each limitation).
# ===============================================================================

locals {
  # Namespace manifest
  microhack_namespace_yaml = <<-EOT
    apiVersion: v1
    kind: Namespace
    metadata:
      name: microhack
      labels:
        name: microhack
        managed-by: terraform
  EOT

  # Role manifest - defines permissions within microhack namespace
  microhack_role_yaml = <<-EOT
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: microhack-deployer
      namespace: microhack
    rules:
    - apiGroups: [""]
      resources: ["pods", "pods/log", "services", "configmaps", "secrets", "persistentvolumeclaims", "serviceaccounts"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["batch"]
      resources: ["jobs", "cronjobs"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["networking.k8s.io"]
      resources: ["ingresses", "networkpolicies"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["autoscaling"]
      resources: ["horizontalpodautoscalers"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["policy"]
      resources: ["poddisruptionbudgets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    - apiGroups: ["rbac.authorization.k8s.io"]
      resources: ["roles", "rolebindings"]
      verbs: ["get", "list"]  # Read-only to prevent privilege escalation
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["get", "list", "watch"]  # Read-only for troubleshooting
  EOT

  # RoleBinding manifest - binds user to role
  microhack_rolebinding_yaml = <<-EOT
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: ${var.deployment_user_name}-microhack-binding
      namespace: microhack
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: microhack-deployer
    subjects:
    - kind: User
      name: ${var.deployment_user_principal_name}
      apiGroup: rbac.authorization.k8s.io
  EOT
}

# ===============================================================================
# Apply RBAC Resources using kubectl
# ===============================================================================

resource "null_resource" "kubernetes_rbac" {
  # Re-apply when cluster changes or YAML manifests change
  triggers = {
    cluster_id         = azurerm_kubernetes_cluster.aks.id
    namespace_yaml     = md5(local.microhack_namespace_yaml)
    role_yaml          = md5(local.microhack_role_yaml)
    rolebinding_yaml   = md5(local.microhack_rolebinding_yaml)
  }

  # Apply RBAC resources
  provisioner "local-exec" {
    command = <<-EOT
      az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing --file .kube/config-${azurerm_kubernetes_cluster.aks.name}
      $env:KUBECONFIG = ".kube/config-${azurerm_kubernetes_cluster.aks.name}"
      
      @"
${local.microhack_namespace_yaml}
"@ | kubectl apply -f -
      
      @"
${local.microhack_role_yaml}
"@ | kubectl apply -f -
      
      @"
${local.microhack_rolebinding_yaml}
"@ | kubectl apply -f -
      
      Write-Host "Successfully applied Kubernetes RBAC for ${var.deployment_user_name}"
    EOT

    interpreter = ["powershell", "-Command"]
  }

  # Cleanup on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "Write-Host 'Namespace microhack will be removed with cluster deletion'"
    interpreter = ["powershell", "-Command"]
  }

  # Ensure AKS cluster exists before applying RBAC
  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

# ===============================================================================
# Outputs
# ===============================================================================

output "namespace_name" {
  description = "Name of the created namespace"
  value       = "microhack"
}

output "role_name" {
  description = "Name of the created Role"
  value       = "microhack-deployer"
}

output "role_binding_name" {
  description = "Name of the created RoleBinding"
  value       = "${var.deployment_user_name}-microhack-binding"
}

output "kubernetes_rbac_summary" {
  description = "Summary of Kubernetes RBAC configuration"
  value = {
    namespace          = "microhack"
    role               = "microhack-deployer"
    rolebinding        = "${var.deployment_user_name}-microhack-binding"
    user_principal     = var.deployment_user_principal_name
    user_display_name  = var.deployment_user_name
    access_scope       = "namespace-only (microhack)"
  }
}
