variable "n" {
  type        = number
  default     = 5
  description = <<EOT
Number of user environments to provision.
Each environment consists of a resource group containing:
 - Two independent Windows Server 2025 VMs: dotnet/SQL Server and java/PostgreSQL
 - One Standard static Public IP per VM, attached to the NIC for RDP
 - Network Security Group
 - Virtual Network (derived CIDR 10.<index>.0.0/22)
 - A single 'vms' subnet
Set to a reasonable small number for demos. Must be >=1.
EOT

  validation {
    condition     = var.n >= 1 && var.n <= 254 && floor(var.n) == var.n
    error_message = "n must be a whole number from 1 through 254."
  }
}

variable "locations" {
  type        = list(string)
  description = <<EOT
List of Azure regions to distribute per-user environments across (round-robin).
Assignment rule: environment index i (1-based) is placed in
  locations[(i - 1) % length(locations)].
All regions must support the required resource types (VM size, Standard public IPs).
Changing the region assigned to an existing index forces recreation of that environment's resource group and all contained resources.
Provide at least one region; empty list is invalid.
EOT
  validation {
    condition = (
      length(var.locations) > 0 &&
      length(distinct(var.locations)) == length(var.locations) &&
      alltrue([for location in var.locations : length(trimspace(location)) > 0])
    )
    error_message = "Provide at least one non-empty, unique region name in locations."
  }
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = <<EOT
Administrative username configured on both Windows VMs in every participant environment.
Avoid reserved names (Administrator, admin, etc.).
EOT
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = <<EOT
Administrative password for all facilitator-created Windows VMs.
Provide through the sensitive TF_VAR_admin_password environment variable.
Do NOT commit real secrets to version control.
Password must satisfy Windows complexity requirements.
EOT
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2as_v5"
  description = <<EOT
SKU/size of the Windows VM per user environment.
The deployment creates two VMs of this size per participant.
The default is a two-vCPU SKU; update vm_vcpus when selecting another size.
EOT
}

variable "vm_vcpus" {
  type        = number
  default     = 2
  description = <<EOT
Number of vCPUs exposed by vm_size, used only to calculate the doubled deployment footprint.
The facilitator preflight script obtains the authoritative value from Azure.
Set this input to that reported value before plan/apply when vm_size is changed.
EOT

  validation {
    condition     = var.vm_vcpus >= 1 && floor(var.vm_vcpus) == var.vm_vcpus
    error_message = "vm_vcpus must be a positive whole number."
  }
}

variable "os_disk_size_gb" {
  type        = number
  default     = 127
  description = <<EOT
Size in GiB of each Premium_LRS operating-system disk.
Two disks of this size are created per participant, one for each independent VM.
The value is included in the required capacity and cost preflight.
EOT

  validation {
    condition     = var.os_disk_size_gb >= 127 && floor(var.os_disk_size_gb) == var.os_disk_size_gb
    error_message = "os_disk_size_gb must be a whole number of at least 127 GiB for the pinned Windows image."
  }
}

variable "source_commit" {
  type        = string
  description = <<EOT
Immutable Git commit used to download the application, canonical manifest, catalog, and images.
There is deliberately no default: a stale pin provisions a tree that has none of the chapters the
room is following, and that failure only surfaces once the VMs are built. Re-pin this for every
delivery to the published workshop commit, then verify the downloaded archive contains the
application sources and every challenge folder before provisioning. See "Re-pin the VM source commit" in docs/Facilitator.md.
Values must be full lowercase 40-hex commit IDs; branches, tags, main, and other mutable
references are rejected.
EOT

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.source_commit))
    error_message = "source_commit must be a full lowercase 40-hex Git commit ID."
  }

  validation {
    condition     = var.source_commit != "fd298de6ded4e55b5208fe3f6d8e81fbcdf836c9"
    error_message = "source_commit is the historical fd298de6 pin, whose tree has none of the current challenges. Re-pin it - see docs/Facilitator.md."
  }
}

variable "source_archive_sha256" {
  type        = string
  description = <<EOT
Expected SHA-256 digest of the immutable GitHub source archive for source_commit.
Provisioning verifies this digest before expanding the archive. Supply the reviewed digest through
TF_VAR_source_archive_sha256; it is integrity metadata, not a secret.
EOT

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.source_archive_sha256))
    error_message = "source_archive_sha256 must be a lowercase 64-hex SHA-256 digest."
  }
}

variable "capacity_preflight_confirmed" {
  type        = bool
  default     = false
  description = <<EOT
Explicit facilitator acknowledgement that baseInfra/scripts/preflight-capacity.ps1 completed for the
selected subscription, locations, participant count, VM size, vCPU count, disk size, and cost ceiling.
Azure resource creation is blocked until this value is true.
EOT
}

variable "manage_entra_users" {
  type        = bool
  default     = true
  description = <<EOT
Flag controlling whether temporary Entra ID (Azure AD) user accounts are provisioned and granted Owner on each user resource group.
When true: an additional module creates n users and their object IDs are passed to each user_environment module which performs the RBAC assignment.
When false: no Entra users are created and no role assignments are added (user_environment skips RBAC if no user object id provided).
EOT
}

variable "entra_user_domain" {
  type        = string
  default     = ""
  description = <<EOT
Custom domain (e.g. example.onmicrosoft.com) to append to generated user UPNs (user<index>@domain). Required if manage_entra_users is true.
Leave empty to disable user creation implicitly or set manage_entra_users=false.
EOT
}

variable "entra_user_password_length" {
  type        = number
  default     = 24
  description = <<EOT
Character length of the distinct password Terraform generates for each provisioned Entra ID user.
There is no shared workshop password: every user gets its own random value, must change it at
first sign-in, and receives it only through the `entra_user_credentials` sensitive output.
EOT

  validation {
    condition     = var.entra_user_password_length >= 16 && var.entra_user_password_length <= 64
    error_message = "entra_user_password_length must be between 16 and 64 characters."
  }
}

variable "subscription_id" {
  type        = string
  description = <<EOT
Azure Subscription ID where all resources will be deployed.
Provide via tfvars file (e.g. config.auto.tfvars), CLI -var flag, or environment variable TF_VAR_subscription_id.
Externalizing this value avoids editing provider configuration when switching target subscriptions.
If omitted, provider authentication will attempt to infer a default subscription from the Azure CLI / Managed Identity context (not recommended for reproducible workshop setups).
EOT
}

variable "manage_azure_resources" {
  type        = bool
  default     = true
  description = <<EOT
Flag controlling whether user environments (Azure resources) should be deployed.
When true: user environments with VMs, networking, and associated resources are provisioned.
When false: only Entra ID users are created (if manage_entra_users is true), but no Azure infrastructure is deployed.
This allows for scenarios where user accounts are needed but the workshop environment is provided separately.
EOT
}

variable "manage_sub_providers" {
  type        = bool
  default     = true
  description = <<EOT
Flag controlling whether Azure resource providers should be registered in the subscription.
When true: registers all required resource providers (AI, containers, databases, networking, etc.) before deploying resources.
When false: skips provider registration (assumes providers are already registered or will be registered separately).
This is useful for workshop scenarios where users don't have subscription-level permissions to register providers.
EOT
}

variable "enable_defender_foundation" {
  type        = bool
  default     = false
  description = <<EOT
Opt-in switch for the paid Microsoft Defender for Cloud plans and subscription budget frozen in
defender.tf. The default is false so ordinary plans cannot create paid Defender
resources. Setting this true also requires defender_facilitator_authorized=true and valid budget inputs.
EOT
}

variable "defender_facilitator_authorized" {
  type        = bool
  default     = false
  description = <<EOT
Explicit acknowledgement that an authorized facilitator approved creation of the paid Defender plans
and subscription budget. This does not represent participant authorization and must remain false for
participant-driven plans. Both this value and enable_defender_foundation must be true to enable the foundation.
EOT

  validation {
    condition     = !var.enable_defender_foundation || var.defender_facilitator_authorized
    error_message = "enable_defender_foundation=true requires defender_facilitator_authorized=true."
  }
}

variable "defender_budget_name" {
  type        = string
  default     = "mh-defender-workshop"
  description = <<EOT
Name of the single subscription-level monthly cost budget created with the Defender foundation.
Use a stable name so reviewed plans and post-workshop cost verification refer to the same resource.
EOT

  validation {
    condition     = length(trimspace(var.defender_budget_name)) > 0
    error_message = "defender_budget_name must not be empty."
  }
}

variable "defender_budget_amount" {
  type        = number
  default     = 0
  description = <<EOT
Explicit monthly budget amount in the subscription billing currency. The zero default is intentionally
invalid when enable_defender_foundation=true, forcing the facilitator to enter and review a positive amount.
EOT

  validation {
    condition     = !var.enable_defender_foundation || var.defender_budget_amount > 0
    error_message = "enable_defender_foundation=true requires a positive defender_budget_amount."
  }
}

variable "defender_budget_start_date" {
  type        = string
  default     = ""
  description = <<EOT
Explicit RFC 3339 start date for the monthly Defender subscription budget, for example
2026-09-01T00:00:00Z. Azure requires the first day of a month at midnight UTC and a date
in the current month through twelve months ahead. The value is required and validated only when
the Defender foundation is enabled.
EOT

  validation {
    condition = !var.enable_defender_foundation ? true : try(
      can(regex("^[0-9]{4}-(0[1-9]|1[0-2])-01T00:00:00Z$", var.defender_budget_start_date)) &&
      timecmp(var.defender_budget_start_date, "2017-06-01T00:00:00Z") >= 0 &&
      (
        tonumber(substr(var.defender_budget_start_date, 0, 4)) * 12 +
        tonumber(substr(var.defender_budget_start_date, 5, 2)) -
        tonumber(formatdate("YYYY", plantimestamp())) * 12 -
        tonumber(formatdate("MM", plantimestamp()))
      ) >= 0 &&
      (
        tonumber(substr(var.defender_budget_start_date, 0, 4)) * 12 +
        tonumber(substr(var.defender_budget_start_date, 5, 2)) -
        tonumber(formatdate("YYYY", plantimestamp())) * 12 -
        tonumber(formatdate("MM", plantimestamp()))
      ) <= 12,
      false
    )
    error_message = "enable_defender_foundation=true requires defender_budget_start_date on the first day of the current month through twelve months ahead at 00:00:00Z."
  }
}

variable "defender_budget_end_date" {
  type        = string
  default     = ""
  description = <<EOT
Explicit RFC 3339 end date for the monthly Defender subscription budget. It must be later than
defender_budget_start_date when the Defender foundation is enabled.
EOT

  validation {
    condition = !var.enable_defender_foundation ? true : (
      can(timecmp(var.defender_budget_end_date, var.defender_budget_start_date)) ?
      timecmp(var.defender_budget_end_date, var.defender_budget_start_date) > 0 :
      false
    )
    error_message = "enable_defender_foundation=true requires a valid defender_budget_end_date later than defender_budget_start_date."
  }
}

variable "defender_budget_notification_emails" {
  type        = set(string)
  default     = []
  description = <<EOT
Facilitator email recipients for the Defender budget's actual-cost notification at the configured
threshold of 80 percent. At least one non-empty address is required when the foundation is enabled.
EOT

  validation {
    condition = !var.enable_defender_foundation || (
      length(var.defender_budget_notification_emails) > 0 &&
      alltrue([for address in var.defender_budget_notification_emails : length(trimspace(address)) >= 3])
    )
    error_message = "enable_defender_foundation=true requires at least one non-empty facilitator notification email."
  }
}

variable "facilitator_principal_name" {
  type        = string
  description = <<EOT
User principal name of the facilitator identity recorded as
`facilitatorPrincipalName`. Every Challenge 1 deployment requires it, so provisioning writes it
into the protected deployment parameter files on each participant VM. Use the signed-in
facilitator UPN, or the display name of the facilitator group when you delegate through a group.
EOT

  validation {
    condition     = length(trimspace(var.facilitator_principal_name)) > 0
    error_message = "facilitator_principal_name must not be empty."
  }
}

variable "facilitator_principal_object_id" {
  type        = string
  description = <<EOT
Entra ID object ID of the same facilitator principal, surfaced as
`facilitatorPrincipalObjectId`. Read it with `az ad signed-in-user show --query id -o tsv`, or
`az ad group show --group '<group>' --query id -o tsv` when you delegate through a group.
EOT

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.facilitator_principal_object_id))
    error_message = "facilitator_principal_object_id must be a GUID, for example 00000000-0000-0000-0000-000000000000."
  }
}


# See modules/user_environment/variables.tf for why this defaults to empty. Set it only to a
# concrete address or CIDR, never to "Internet": tenant governance deletes unscoped inbound
# 3389 rules within ~20 minutes (docs/CommonErrors.md #124).
variable "rdp_source_address_prefixes" {
  description = "Source CIDRs allowed to reach RDP (3389) on every participant VM. Empty creates no inbound rule; participants open their own in Challenge 0."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains([for p in var.rdp_source_address_prefixes : lower(p)], "internet")
    error_message = "Use concrete CIDRs. An 'Internet' source is removed by tenant governance shortly after apply."
  }
}
