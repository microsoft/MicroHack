# Challenge 1 - Enforce Sovereign Controls with Azure Policy and RBAC

**[Home](../Readme.md)** - [Next Challenge Solution](challenge-02.md)

- All policy assignments in this challenge should be scoped to your own resource group (e.g. "LabUser-01")
- All resources created in Microsoft Entra should be prefixed with your prefix (e.g. "LabUser01")

## Goal

The goal of this exercise is to establish foundational sovereign cloud governance controls using Azure native platform capabilities. You will configure Azure Policy to restrict resource deployments to sovereign regions, enforce compliance requirements through tagging and network restrictions, and implement least-privilege access using RBAC.

## Actions

- Create and assign Azure Policy controls to restrict deployments to EU sovereign regions (Norway East, Germany North).
- Enforce resource tagging requirements for data classification and compliance tracking.
- Block public IP exposure by enforcing private endpoints for sensitive resources.
- Assign least-privilege RBAC roles for the SovereignOps team.
- Create a custom RBAC role for compliance officers with audit-only permissions.
- Review the Azure Policy Compliance Dashboard to identify non-compliant resources.
- Trigger remediation tasks to bring existing resources into compliance.

## Success criteria

- You have successfully assigned Azure Policy to restrict deployments to sovereign regions only.
- Resources require the `DataClassification=Sovereign` tag before deployment.
- Public IP addresses are blocked for new deployments.
- You have created and assigned a custom RBAC role for compliance auditing.
- The Azure Policy Compliance Dashboard shows your compliance status.
- Non-compliant resources have been successfully remediated.

## Learning resources

- [Sovereign Landing Zone (SLZ)](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/sovereign-landing-zone/overview-slz?tabs=hubspoke)
- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Azure Policy built-in definitions](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies)
- [Azure Policy initiatives](https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure)
- [Azure RBAC overview](https://learn.microsoft.com/azure/role-based-access-control/overview)
- [Create custom roles for Azure RBAC](https://learn.microsoft.com/azure/role-based-access-control/custom-roles)
- [Remediate non-compliant resources](https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources)

