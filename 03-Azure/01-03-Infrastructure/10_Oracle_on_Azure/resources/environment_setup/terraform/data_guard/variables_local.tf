locals {
  vnet_oracle_name     = "vnet1"
  database_subnet_name = "subnet1"
  disable_telemetry    = var.disable_telemetry
  telem_core_puid         = "440d81eb-6657-4a7d-ad93-c7e9cc09e5da"
  empty_string = ""
  telem_random_hex = can(random_id.telem[0].hex) ? random_id.telem[0].hex : local.empty_string
}


# This constructs the ARM deployment name that is used for the telemetry.
# We shouldn't ever hit the 64 character limit but use substr just in case
locals {
  telem_core_arm_deployment_name = substr(
    format(
      "pid-%s_%s",
      local.telem_core_puid,
      local.telem_random_hex,
    ),
    0,
    64
  )
}

locals {
  telem_arm_subscription_template_content = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [],
  "outputs": {
    "telemetry": {
      "type": "String",
      "value": "For more information, see https://aka.ms/alz/tf/telemetry"
    }
  }
}
TEMPLATE
}

# Condition to determine whether we create the core telemetry deployment
locals {
  telem_core_deployment_enabled = !local.disable_telemetry
}
