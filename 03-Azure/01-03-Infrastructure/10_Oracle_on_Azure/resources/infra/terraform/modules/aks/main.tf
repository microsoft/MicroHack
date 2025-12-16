# ===============================================================================
# AKS Module - Main Configuration
# ===============================================================================
# This module creates an Azure Kubernetes Service cluster with supporting
# infrastructure including virtual network, Log Analytics workspace, and
# managed identity configuration.
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "aks" {
  name     = "aks-${var.prefix}${var.postfix}"
  location = var.location
  tags     = var.tags
}

locals {
  # Azure automatically creates a managed node resource group named
  # `MC_<aks-resource-group>_<aks-cluster-name>` for agent pools. Matching that
  # pattern lets the service own the group lifecycle, so deleting the cluster
  # tears down the node resource group without manual cleanup.
  cluster_name             = "aks-${var.prefix}${var.postfix}"
  node_resource_group_name = "MC_${azurerm_resource_group.aks.name}_${local.cluster_name}"
  private_dns_configs = {
    odaa_fra = {
      zone_name = var.fqdn_odaa_fra
      link_name = "aks-pdns-link-odaa"
    }
    odaa_app_fra = {
      zone_name = var.fqdn_odaa_app_fra
      link_name = "aks-pdns-link-odaa-app"
    }
    odaa_par = {
      zone_name = var.fqdn_odaa_par
      link_name = "aks-pdns-link-odaa"
    }
    odaa_app_par = {
      zone_name = var.fqdn_odaa_app_par
      link_name = "aks-pdns-link-odaa-app"
    }
  }
}

# ===============================================================================
# Log Analytics Workspace
# ===============================================================================

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "aks-${var.prefix}${var.postfix}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ===============================================================================
# Virtual Network
# ===============================================================================

resource "azurerm_virtual_network" "aks" {
  name                = "aks-${var.prefix}${var.postfix}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = ["${var.cidr}/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["${var.cidr}/23"]
}

# ===============================================================================
# AKS Cluster
# ===============================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.prefix}${var.postfix}"
  kubernetes_version  = "1.32.6"
  node_resource_group = local.node_resource_group_name
  sku_tier            = "Free"

  # Network Profile
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = cidrhost(var.service_cidr, 10) # deterministic CoreDNS VIP within the service CIDR
    service_cidr      = var.service_cidr
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    ip_versions       = ["IPv4"]
  }

  # Default Node Pool (System)
  default_node_pool {
    name                   = "agentpool"
    node_count             = 2
    vm_size                = var.aks_vm_size
    os_disk_size_gb        = 128
    os_disk_type           = var.os_disk_type
    vnet_subnet_id         = azurerm_subnet.aks.id
    max_pods               = 30
    type                   = "VirtualMachineScaleSets"
    auto_scaling_enabled   = false
    orchestrator_version   = "1.32.6"
    node_public_ip_enabled = false

    os_sku            = "Ubuntu"
    kubelet_disk_type = "OS"

    upgrade_settings {
      max_surge                     = "1"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  # Identity
  identity {
    type = "SystemAssigned"
  }



  # Auto Scaler Profile
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                         = "random"
    max_graceful_termination_sec     = "600"
    max_node_provisioning_time       = "15m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "0s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = "0.5"
    scan_interval                    = "10s"
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }

  # Workload Identity
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Monitor Metrics
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  # Add-ons
  azure_policy_enabled = true

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks.id
    msi_auth_for_monitoring_enabled = true
  }

  # Storage Profile
  storage_profile {
    blob_driver_enabled         = false
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  # Maintenance Configuration
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "00:00"
    utc_offset  = "+01:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "00:00"
    utc_offset  = "+01:00"
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet.aks
  ]
}

# ===============================================================================
# RBAC Role Assignments for Deployment Group
# ===============================================================================

# Azure Kubernetes Service Cluster User Role - allows getting cluster credentials
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.deployment_user_object_id
  description          = "Allows the deployment user to get cluster credentials for ${azurerm_kubernetes_cluster.aks.name}"
}

# Azure Kubernetes Service RBAC Writer - allows full cluster access
resource "azurerm_role_assignment" "aks_rbac_writer" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.deployment_user_object_id
  description          = "Allows the deployment user to deploy Kubernetes workloads in ${azurerm_kubernetes_cluster.aks.name}"
}

# Reader role for visibility into the AKS subscription
resource "azurerm_role_assignment" "subscription_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = var.deployment_user_object_id
  description          = "Allows the deployment user to view resources in subscription ${var.subscription_id}"
}

# ===============================================================================
# ACR Pull Access
# ===============================================================================

# Grant AKS cluster managed identity pull access to shared ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/09808f31-065f-4231-914d-776c2d6bbe34/resourceGroups/odaa/providers/Microsoft.ContainerRegistry/registries/odaamh"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  description          = "Allows AKS cluster ${azurerm_kubernetes_cluster.aks.name} to pull images from odaamh ACR"
}

# ===============================================================================
# User Node Pool
# ===============================================================================

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                   = "userpool"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.aks.id
  vm_size                = var.aks_vm_size
  node_count             = 1
  os_disk_size_gb        = 128
  os_disk_type           = var.os_disk_type
  vnet_subnet_id         = azurerm_subnet.aks.id
  max_pods               = 30
  auto_scaling_enabled   = true
  min_count              = 1
  max_count              = 2
  orchestrator_version   = "1.32.6"
  node_public_ip_enabled = false
  os_type                = "Linux"
  os_sku                 = "Ubuntu"
  mode                   = "User"
  kubelet_disk_type      = "OS"

  upgrade_settings {
    max_surge                     = "10%"
    drain_timeout_in_minutes      = 0
    node_soak_duration_in_minutes = 0
  }

  tags = var.tags
}

# ===============================================================================
# Private DNS Zones (Integrated DNS)
# ===============================================================================

# Private DNS zones for Oracle endpoints (FRA and PAR base/app domains)
resource "azurerm_private_dns_zone" "odaa" {
  for_each = local.private_dns_configs

  name                = each.value.zone_name
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "odaa" {
  for_each = local.private_dns_configs

  name                  = each.value.link_name
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.odaa[each.key].name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_role_assignment" "private_dns_contributor_odaa" {
  for_each = local.private_dns_configs

  scope                = azurerm_private_dns_zone.odaa[each.key].id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.deployment_user_object_id
  description          = "Allows the deployment user to manage private DNS zone ${azurerm_private_dns_zone.odaa[each.key].name}"
}
