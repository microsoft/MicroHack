# Challenge 1 - Enforce Sovereign Controls with Azure Policy and RBAC

- All policy assignments in this challenge should be scoped to your own resource group (e.g. `rg-labuser-0024`).
- Use a consistent friendly prefix for assignments (`Lab User-0024`) and Microsoft Entra groups (`Lab-User-0024`), replacing the number with your own.
- Start the governance assignments in **DoNotEnforce**. In walkthrough Task 9, temporarily enable only the location, tag, and public-IP assignments in your group for the deny tests, then restore **DoNotEnforce** before continuing.

## Goal

The goal of this exercise is to establish foundational sovereign cloud governance controls using Azure native platform capabilities. You will configure Azure Policy to restrict resource deployments to sovereign regions, enforce compliance requirements through tagging and network restrictions, and implement least-privilege access using RBAC.

## Actions

- Create and assign Azure Policy controls to restrict deployments to the lab-approved European regions (Norway East, Germany North, North Europe, West Europe). West Europe accommodates Azure Local management resources when LocalBox is registered there.
- Enforce resource tagging requirements for data classification and compliance tracking.
- Block public IP resource creation and evaluate storage public-network-access restrictions. Disabling public network access does not create or verify a private endpoint.
- Assign least-privilege RBAC roles for the SovereignOps team.
- Create a custom RBAC role for compliance officers with audit-only permissions.
- Review the Azure Policy Compliance Dashboard to identify non-compliant resources.
- Trigger remediation tasks to bring existing resources into compliance.

## Success criteria

- You have successfully assigned Azure Policy to restrict deployments to sovereign regions only.
- During the temporary enforcement test, resources require the `DataClassification=Sovereign` tag before deployment.
- During that test, public IP addresses are blocked for new deployments.
- You have created and assigned a custom RBAC role for compliance auditing.
- The Azure Policy Compliance Dashboard shows your compliance status.
- Non-compliant resources have been successfully remediated.
- Your exercise assignments are returned to **DoNotEnforce** before the next challenge; organizer-managed policies remain unchanged.

## Learning resources

- [Sovereign Landing Zone (SLZ)](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/sovereign-landing-zone/overview-slz?tabs=hubspoke)
- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Azure Policy built-in definitions](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies)
- [Azure Policy initiatives](https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure)
- [Azure RBAC overview](https://learn.microsoft.com/azure/role-based-access-control/overview)
- [Create custom roles for Azure RBAC](https://learn.microsoft.com/azure/role-based-access-control/custom-roles)
- [Remediate non-compliant resources](https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources)
