# ===============================================================================
# Ingress NGINX Module - Main Configuration
# ===============================================================================
# This module deploys the ingress-nginx controller via Helm and configures
# the Azure Load Balancer health probe annotation expected for AKS.
# ===============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

locals {
  controller_values = {
    controller = {
      service = {
        annotations = var.controller_service_annotations
      }
    }
  }

  rendered_values = concat(
    [yamlencode(local.controller_values)],
    var.additional_value_overrides,
  )
}

resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "this" {
  name            = var.release_name
  repository      = var.repository
  chart           = var.chart
  namespace       = var.namespace
  version         = var.chart_version
  wait            = var.wait_for_resources
  timeout         = var.timeout_seconds
  cleanup_on_fail = true
  atomic          = true

  create_namespace = false

  values = local.rendered_values

  depends_on = [
    kubernetes_namespace.this,
  ]
}

# Read the controller service so the external IP can be exposed via outputs.
data "kubernetes_service" "controller" {
  metadata {
    name      = "${var.release_name}-ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [
    helm_release.this,
  ]
}