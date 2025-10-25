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
  name                = "aks-${var.prefix}${var.postfix}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.prefix}${var.postfix}"
  kubernetes_version  = "1.32.6"
  node_resource_group = "MC_${var.prefix}${var.postfix}"
  sku_tier            = "Free"

  # Network Profile
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.72.0.10"
    service_cidr      = "10.72.0.0/16"
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
    os_disk_type           = "Ephemeral"
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
  principal_id         = var.deployment_group_object_id
  description          = "Allows group members to get cluster credentials for ${azurerm_kubernetes_cluster.aks.name}"
}

# Azure Kubernetes Service RBAC Admin - allows full admin access to cluster
resource "azurerm_role_assignment" "aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Admin"
  principal_id         = var.deployment_group_object_id
  description          = "Allows group members to perform admin operations in ${azurerm_kubernetes_cluster.aks.name}"
}

# Contributor role on the AKS resource group for managing AKS-related resources
resource "azurerm_role_assignment" "aks_contributor" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Contributor"
  principal_id         = var.deployment_group_object_id
  description          = "Allows group members to manage resources in ${azurerm_resource_group.aks.name}"
}

# Network Contributor role for managing network resources
resource "azurerm_role_assignment" "network_contributor" {
  scope                = azurerm_virtual_network.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = var.deployment_group_object_id
  description          = "Allows group members to manage network resources for AKS"
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
  os_disk_type           = "Ephemeral"
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

# Private DNS Zone for ODAA FQDN
resource "azurerm_private_dns_zone" "odaa" {
  name                = var.fqdn_odaa
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "odaa" {
  name                  = "aks-pdns-link-odaa"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.odaa.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags                  = var.tags
}

# Private DNS Zone for ODAA App FQDN
resource "azurerm_private_dns_zone" "odaa_app" {
  name                = var.fqdn_odaa_app
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "odaa_app" {
  name                  = "aks-pdns-link-odaa-app"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.odaa_app.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags                  = var.tags
}