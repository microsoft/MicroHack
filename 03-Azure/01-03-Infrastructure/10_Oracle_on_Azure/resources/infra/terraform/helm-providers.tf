# -----------------------------------------------------------------------------
# Helm Provider Configuration per AKS subscription assignment
# -----------------------------------------------------------------------------
# Each subscription index maps to at most one AKS cluster. These providers reuse the kubeconfig
# emitted by the AKS modules so that downstream modules can install Helm charts
# without embedding their own provider configurations.
# -----------------------------------------------------------------------------

locals {
  helm_provider_slots = [for index in range(5) : tostring(index)]

  helm_deployment_keys_by_slot = {
    for slot in local.helm_provider_slots :
    slot => [
      for key, deployment in local.deployments : key
      if tostring(deployment.provider_index) == slot
    ]
  }

  ingress_subscription_counts = {
    for slot, keys in local.helm_deployment_keys_by_slot :
    "subscription_${slot}" => length(keys)
  }

  helm_slot_0_keys = try(local.helm_deployment_keys_by_slot["0"], [])
  helm_slot_1_keys = try(local.helm_deployment_keys_by_slot["1"], [])
  helm_slot_2_keys = try(local.helm_deployment_keys_by_slot["2"], [])
  helm_slot_3_keys = try(local.helm_deployment_keys_by_slot["3"], [])
  helm_slot_4_keys = try(local.helm_deployment_keys_by_slot["4"], [])

  helm_slot_0_kubeconfig = (
    length(local.helm_slot_0_keys) == 1 ?
    try(module.aks_slot_0[local.helm_slot_0_keys[0]].aks_cluster_kube_config[0], null) :
    null
  )

  helm_slot_1_kubeconfig = (
    length(local.helm_slot_1_keys) == 1 ?
    try(module.aks_slot_1[local.helm_slot_1_keys[0]].aks_cluster_kube_config[0], null) :
    null
  )

  helm_slot_2_kubeconfig = (
    length(local.helm_slot_2_keys) == 1 ?
    try(module.aks_slot_2[local.helm_slot_2_keys[0]].aks_cluster_kube_config[0], null) :
    null
  )

  helm_slot_3_kubeconfig = (
    length(local.helm_slot_3_keys) == 1 ?
    try(module.aks_slot_3[local.helm_slot_3_keys[0]].aks_cluster_kube_config[0], null) :
    null
  )

  helm_slot_4_kubeconfig = (
    length(local.helm_slot_4_keys) == 1 ?
    try(module.aks_slot_4[local.helm_slot_4_keys[0]].aks_cluster_kube_config[0], null) :
    null
  )
}

check "single_ingress_target_per_subscription" {
  assert {
    condition = alltrue([
      for count in values(local.ingress_subscription_counts) : count <= 1
    ])

    error_message = "Ingress automation currently supports at most one AKS deployment per subscription index. Increase the number of subscription targets or adjust user_count so that each index maps to a single cluster."
  }
}

provider "helm" {
  alias = "aks_deployment_slot_0"

  kubernetes {
    host                   = local.helm_slot_0_kubeconfig == null ? null : local.helm_slot_0_kubeconfig.host
    client_certificate     = local.helm_slot_0_kubeconfig == null ? null : base64decode(local.helm_slot_0_kubeconfig.client_certificate)
    client_key             = local.helm_slot_0_kubeconfig == null ? null : base64decode(local.helm_slot_0_kubeconfig.client_key)
    cluster_ca_certificate = local.helm_slot_0_kubeconfig == null ? null : base64decode(local.helm_slot_0_kubeconfig.cluster_ca_certificate)
  }
}

provider "helm" {
  alias = "aks_deployment_slot_1"

  kubernetes {
    host                   = local.helm_slot_1_kubeconfig == null ? null : local.helm_slot_1_kubeconfig.host
    client_certificate     = local.helm_slot_1_kubeconfig == null ? null : base64decode(local.helm_slot_1_kubeconfig.client_certificate)
    client_key             = local.helm_slot_1_kubeconfig == null ? null : base64decode(local.helm_slot_1_kubeconfig.client_key)
    cluster_ca_certificate = local.helm_slot_1_kubeconfig == null ? null : base64decode(local.helm_slot_1_kubeconfig.cluster_ca_certificate)
  }
}

provider "helm" {
  alias = "aks_deployment_slot_2"

  kubernetes {
    host                   = local.helm_slot_2_kubeconfig == null ? null : local.helm_slot_2_kubeconfig.host
    client_certificate     = local.helm_slot_2_kubeconfig == null ? null : base64decode(local.helm_slot_2_kubeconfig.client_certificate)
    client_key             = local.helm_slot_2_kubeconfig == null ? null : base64decode(local.helm_slot_2_kubeconfig.client_key)
    cluster_ca_certificate = local.helm_slot_2_kubeconfig == null ? null : base64decode(local.helm_slot_2_kubeconfig.cluster_ca_certificate)
  }
}

provider "helm" {
  alias = "aks_deployment_slot_3"

  kubernetes {
    host                   = local.helm_slot_3_kubeconfig == null ? null : local.helm_slot_3_kubeconfig.host
    client_certificate     = local.helm_slot_3_kubeconfig == null ? null : base64decode(local.helm_slot_3_kubeconfig.client_certificate)
    client_key             = local.helm_slot_3_kubeconfig == null ? null : base64decode(local.helm_slot_3_kubeconfig.client_key)
    cluster_ca_certificate = local.helm_slot_3_kubeconfig == null ? null : base64decode(local.helm_slot_3_kubeconfig.cluster_ca_certificate)
  }
}

provider "helm" {
  alias = "aks_deployment_slot_4"

  kubernetes {
    host                   = local.helm_slot_4_kubeconfig == null ? null : local.helm_slot_4_kubeconfig.host
    client_certificate     = local.helm_slot_4_kubeconfig == null ? null : base64decode(local.helm_slot_4_kubeconfig.client_certificate)
    client_key             = local.helm_slot_4_kubeconfig == null ? null : base64decode(local.helm_slot_4_kubeconfig.client_key)
    cluster_ca_certificate = local.helm_slot_4_kubeconfig == null ? null : base64decode(local.helm_slot_4_kubeconfig.cluster_ca_certificate)
  }
}
