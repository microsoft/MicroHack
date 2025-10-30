# -----------------------------------------------------------------------------
# Helm Provider Configuration per AKS deployment slot
# -----------------------------------------------------------------------------
# Each slot maps to at most one AKS cluster. These providers reuse the kubeconfig
# emitted by the AKS modules so that downstream modules can install Helm charts
# without embedding their own provider configurations.
# -----------------------------------------------------------------------------

locals {
  ingress_slot_counts = {
    slot_0 = length(module.aks_slot_0)
    slot_1 = length(module.aks_slot_1)
    slot_2 = length(module.aks_slot_2)
    slot_3 = length(module.aks_slot_3)
    slot_4 = length(module.aks_slot_4)
  }

  helm_slot_0_kubeconfig = length(module.aks_slot_0) == 1 ? values(module.aks_slot_0)[0].aks_cluster_kube_config[0] : null
  helm_slot_1_kubeconfig = length(module.aks_slot_1) == 1 ? values(module.aks_slot_1)[0].aks_cluster_kube_config[0] : null
  helm_slot_2_kubeconfig = length(module.aks_slot_2) == 1 ? values(module.aks_slot_2)[0].aks_cluster_kube_config[0] : null
  helm_slot_3_kubeconfig = length(module.aks_slot_3) == 1 ? values(module.aks_slot_3)[0].aks_cluster_kube_config[0] : null
  helm_slot_4_kubeconfig = length(module.aks_slot_4) == 1 ? values(module.aks_slot_4)[0].aks_cluster_kube_config[0] : null
}

check "single_ingress_target_per_slot" {
  assert {
    condition = alltrue([
      for count in values(local.ingress_slot_counts) : count <= 1
    ])

    error_message = "Ingress automation currently supports at most one AKS deployment per subscription slot. Increase the number of subscription targets or adjust user_count so that each slot maps to a single cluster."
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
