variable "release_name" {
  description = "Name of the Helm release for the ingress controller"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the ingress controller will be installed"
  type        = string
  default     = "ingress-nginx"
}

variable "repository" {
  description = "Helm repository URL for the ingress-nginx chart"
  type        = string
  default     = "https://kubernetes.github.io/ingress-nginx"
}

variable "chart" {
  description = "Helm chart name to deploy"
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "Specific Helm chart version to deploy. Leave null for the latest"
  type        = string
  default     = null
}

variable "wait_for_resources" {
  description = "Whether Helm should wait for Kubernetes resources to become ready"
  type        = bool
  default     = true
}

variable "timeout_seconds" {
  description = "Timeout in seconds for Helm operations"
  type        = number
  default     = 600
}

variable "create_namespace" {
  description = "Whether to create the namespace if it does not exist"
  type        = bool
  default     = true
}

variable "controller_service_annotations" {
  description = "Annotations to apply on the ingress controller Service"
  type        = map(string)
  default = {
    "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
  }
}

variable "additional_value_overrides" {
  description = "Additional YAML values (rendered as strings) to pass to the Helm chart"
  type        = list(string)
  default     = []
}
