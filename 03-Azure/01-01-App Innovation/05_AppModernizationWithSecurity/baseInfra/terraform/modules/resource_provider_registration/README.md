# Resource provider registration

This module explicitly registers the namespaces required by the workshop while the root
`azurerm` provider disables automatic registration. The required set includes:

- `Microsoft.App` for Azure Container Apps and Azure SRE Agent
- `Microsoft.ContainerRegistry` for ACR
- `Microsoft.Sql` and `Microsoft.DBforPostgreSQL`
- `Microsoft.Insights`, `Microsoft.OperationalInsights`, and related Monitor namespaces
- `Microsoft.Security` for Microsoft Defender for Cloud
- the Compute, Network, Authorization, and Managed Identity namespaces used by base infrastructure

Registration is an intentional subscription-level, non-destroy boundary. Every registration
uses `prevent_destroy = true`, so an ordinary `terraform destroy` cannot unregister providers
that may serve unrelated resources. Before destroying only the participant infrastructure,
remove the registration module from this Terraform state without deleting the Azure registrations:

```pwsh
terraform state rm 'module.resource_providers[0]'
terraform destroy
```

If the configuration later needs to manage already-registered namespaces again, import them with
`import_existing_providers.ps1`; do not unregister and recreate them.
