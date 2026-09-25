resource "azurerm_resource_provider_registration" "providers" {
  for_each = toset(local.resource_providers)

  name = each.value

  # `azurerm_resource_provider_registration` treats the set of `feature` blocks as the
  # authoritative preview-feature state for the provider. With no blocks at all it actively
  # *unregisters* any preview feature that is registered, so every apply silently revoked
  # Microsoft.Network/AllowBringYourOwnPublicIpAddress and public IP creation started failing
  # again minutes after a facilitator registered it by hand. That looked exactly like tenant
  # governance reverting the change, and was previously recorded as such; it was this
  # resource. Declaring the feature here is what keeps it registered.
  dynamic "feature" {
    for_each = lookup(local.provider_features, each.value, {})
    content {
      name       = feature.key
      registered = feature.value
    }
  }

  lifecycle {
    prevent_destroy = true

    # Azure reports every preview feature it knows about for a provider, including ones nobody
    # here asked for and that are already unregistered. Because the `feature` set is
    # authoritative, those show up as a permanent "remove this block" diff that never settles -
    # Microsoft.CognitiveServices did exactly that with Cloud.Speech.PersonalVoice and
    # OpenAI.1PGatingTier. A provider module that never reaches a clean plan is not just noise:
    # `module.user_environment` has `depends_on` on this module, so a pending change here defers
    # its `azurerm_client_config` data source to apply time, which makes the subscription ID
    # unknown at plan time and forces replacement of the resource group and everything in it.
    # Features are applied on create and then left alone, which is all this workshop needs.
    ignore_changes = [feature]
  }
}
