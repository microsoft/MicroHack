# **MicroHack Microsoft Sovereign Cloud**

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)
# MicroHack introduction

This Microsoft Sovereign Cloud MicroHack introduces engineers and architects to the core concepts, technical controls, and hands-on deployment models of Microsoft Sovereign Cloud offerings — across both Microsoft Sovereign Public Cloud and Microsoft Sovereign Private Cloud environments.

![image](./img/Microsoft_Sovereign_Cloud.png)

Participants will explore how to design and operate cloud workloads that meet sovereignty, regulatory, and compliance requirements, leveraging Azure native capabilities such as Policy, RBAC, encryption, confidential compute, and hybrid enablement through Azure Arc and Azure Local.

## MicroHack context
This MicroHack scenario walks through the use of Microsoft Sovereign Cloud technologies with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with different solutions around the Microsoft Sovereign Public Cloud and the Microsoft Sovereign Private Cloud,

* [Microsoft Sovereign Cloud](https://www.microsoft.com/en-us/ai/sovereign-cloud?msockid=35d465bce58561e42620737ce487605e)
* [Microsoft Sovereign Cloud documentation](https://learn.microsoft.com/en-us/industry/sovereign-cloud/)
* [What is Sovereign Public Cloud?](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/overview-sovereign-public-cloud)
* [Sovereign Private CLoud](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-private-cloud/overview-sovereign-private-cloud)
* [Digital sovereignty](https://learn.microsoft.com/en-us/industry/sovereign-cloud/overview/digital-sovereignty)
* [Sovereign Landing Zone (SLZ)](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/sovereign-landing-zone/overview-slz?tabs=hubspoke)
* [Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/overview)
* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/en-us/azure/confidential-computing/overview)
* [Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/)
* [Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/)

## Objectives

After completing this MicroHack you will:

- Enforce sovereign cloud controls in Azure using native platform capabilities (Policy, RBAC, region restrictions).
- Protect data through encryption at rest, in transit, and in use (CMK, TLS, ACC).
- Operate a sovereign hybrid cloud environment by connecting local infrastructure using Azure Arc and Azure Local.

## MicroHack challenges

| Challenge | Topic    | Maker     | Status    |
|:---------:|----------|-----------|-----------|
| 1         | [Using Azure native platform controls (e.g. Policy, RBAC etc) to enforce sovereign controls in the public cloud](walkthrough/challenge-1/solution.md)  | Jan Egil Ring | ✅ |
| 2         | [Encryption at rest with Customer Managed Keys in Azure Key Vault](walkthrough/challenge-2/solution.md) | Ye Zhang | ✅ |
| 3         | [Encryption in transit - enforcing TLS](walkthrough/challenge-3/solution.md) | Ye Zhang | ✅ |
| 4         | [Encryption in use with Azure Confidential Compute - VM](walkthrough/challenge-4/solution.md) | Murali Rao Yelamanchili | ✅ |
| 5         | [Encryption in use with Azure Confidential Compute - Containers/Applications](walkthrough/challenge-5/solution.md) | Murali Rao Yelamanchili | ✅ |
| 6         | [Operating Sovereign in a hybrid environment with Azure Local and Azure Arc](walkthrough/challenge-6/solution.md) | Jan Egil Ring / Thomas Maurer | ✅ |

### General prerequisites

This MicroHack has a few but important prerequisites

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

- Your own Azure subscription with Owner RBAC rights at the subscription level
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (Hint: Make sure to use the lastest version)
- Contributor or Owner permissions on your subscription or resource group
- Optional: Access to Azure Arc Jumpstart LocalBox for hybrid challenges


## Challenge 1 - Enforce Sovereign Controls with Azure Policy and RBAC

- All policy assignments in this challenge should be scoped to your own resource group (e.g. "LabUser-01")
- All resources created in Microsoft Entra should be prefixed with your prefix (e.g. "LabUser01")

### Goal

The goal of this exercise is to establish foundational sovereign cloud governance controls using Azure native platform capabilities. You will configure Azure Policy to restrict resource deployments to sovereign regions, enforce compliance requirements through tagging and network restrictions, and implement least-privilege access using RBAC.

### Actions

- Create and assign Azure Policy controls to restrict deployments to EU sovereign regions (Norway East, Germany North).
- Enforce resource tagging requirements for data classification and compliance tracking.
- Block public IP exposure by enforcing private endpoints for sensitive resources.
- Assign least-privilege RBAC roles for the SovereignOps team.
- Create a custom RBAC role for compliance officers with audit-only permissions.
- Review the Azure Policy Compliance Dashboard to identify non-compliant resources.
- Trigger remediation tasks to bring existing resources into compliance.

### Success criteria

- You have successfully assigned Azure Policy to restrict deployments to sovereign regions only.
- Resources require the `DataClassification=Sovereign` tag before deployment.
- Public IP addresses are blocked for new deployments.
- You have created and assigned a custom RBAC role for compliance auditing.
- The Azure Policy Compliance Dashboard shows your compliance status.
- Non-compliant resources have been successfully remediated.

### Learning resources

- [Sovereign Landing Zone (SLZ)](https://learn.microsoft.com/en-us/industry/sovereign-cloud/sovereign-public-cloud/sovereign-landing-zone/overview-slz?tabs=hubspoke)
- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Azure Policy built-in definitions](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies)
- [Azure Policy initiatives](https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure)
- [Azure RBAC overview](https://learn.microsoft.com/azure/role-based-access-control/overview)
- [Create custom roles for Azure RBAC](https://learn.microsoft.com/azure/role-based-access-control/custom-roles)
- [Remediate non-compliant resources](https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Encryption at Rest with Customer-Managed Keys (CMKs) in Azure Key Vault

### Goal

Understand Customer-Managed Keys in Azure Key Vault. Configure an Azure Storage account to use a customer-managed key stored in Azure Key Vault (or Azure Managed HSM) for encryption at rest. Validate the configuration and understand operational considerations for sovereign scenarios.

### Actions

* Understand Azure Key Management Options
* Understand Customer-Managed Keys (CMK) in Azure Key Vault
* CMK for Azure Storage - Implementation Step by Step

### Success criteria

* You have deployed Azure Key Vault
* You successfully  implement CMK for an Azure Storage account using Azure CLI. 
* You have successfully verify encryption settings

### Learning resources

* [Customer-managed keys for Azure Storage encryption](https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-overview)
* [About Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
* [Azure Key Vault keys, secrets, and certificates overview](https://learn.microsoft.com/en-us/azure/key-vault/general/about-keys-secrets-certificates)
* [Azure Key Vault basic concepts](https://learn.microsoft.com/en-us/azure/key-vault/general/basic-concepts)
* [What is Azure Key Vault Managed HSM?](https://learn.microsoft.com/en-us/azure/key-vault/managed-hsm/overview)
* [Azure Key & Certificate Management](https://learn.microsoft.com/azure/key-vault/general/overview)
* [Services that support CMKs with Key Vault & Managed HSM](https://learn.microsoft.com/azure/key-vault/general/key-vault-integrate-sdks)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Encryption in transit: enforcing TLS

### Goal

Understand encryption in transit considerations for sovereign scenarios. Configure Azure Storage accounts to require secure transfer (HTTPS only) and enforce TLS 1.2 as the minimum protocol version. Apply Azure Policy to block weaker TLS versions and monitor client protocol usage through Log Analytics.

### Actions

* Understand Encryption in transit
* Understand TLS versions & recommendation
* Hands-on: Azure Blob Storage - require secure transfer (HTTPS only) in Azure Portal
* Hands-on: Enforce minimum TLS version with Azure Policy
* Validation: detect TLS versions used by clients (Log Analytics/KQL)

### Success criteria

* Storage accounts reject HTTP requests and enforce HTTPS (secure transfer required).
* Policy compliance shows all storage accounts with Minimum TLS Version = TLS 1.2.
* Log Analytics reports no requests using TLS 1.0/1.1 in the past 7 days (or policy denies/blocks them).

### Learning resources

* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Require secure transfer (HTTPS only) for Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)
* [Enforce a minimum required TLS version for Storage](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)
* [Azure Resource Manager TLS support](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tls-support)
* [Policy: Storage accounts should have the specified minimum TLS version](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Encryption in use with Azure Confidential Compute – VM

### Goal

Deploy and validate guest attestation on Azure Confidential VMs to ensure business logic only executes in trusted, compliant confidential computing environments. You'll build and deploy a sample application that implements secure attestation flows using Azure Confidential VMs. The application leverages Microsoft Azure Attestation (MAA) to validate VM integrity before executing protected business logic, demonstrating "encryption in use" capabilities.

### Actions

* Create Key Vault and SSH Keys
* Create Attestation Provider
* Create Virtual Network and Confidential VM
* Create Azure Bastion
* Configure Confidential VM (Run on the CVM)
* Review the attestation token output

### Success criteria

* Attestation token output proving the VM is running in a trusted confidential environment

### Learning resources

* [Azure confidential computing](https://learn.microsoft.com/en-us/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/en-us/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/en-us/azure/attestation/overview)
* [About Azure confidential VMs](https://learn.microsoft.com/en-us/azure/confidential-computing/confidential-vm-overview)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Encryption in use with Confidential VMs/Node Pools in Azure Kubernetes Service(AKS)

### Goal

Deploy and validate guest attestation on Azure Confidential VMs to ensure business logic only executes in trusted, compliant confidential computing environments. You'll build and deploy a sample application that implements secure attestation flows using Confidential VMs in AKS. The application leverages Microsoft Azure Attestation (MAA) to validate VM integrity before executing protected business logic, demonstrating "encryption in use" capabilities.

### Actions

* Create an AKS Cluster
* Add a Confidential VM Node Pool
* Verify Node Pool Configuration
* Run Attestation Verification Sample
* Review the attestation token output

### Success criteria

* Attestation token output proving the App is running in a trusted confidential environment

### Learning resources

* [Azure confidential computing](https://learn.microsoft.com/en-us/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/en-us/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/en-us/azure/attestation/overview)
* [Confidential containers on Azure](https://learn.microsoft.com/en-us/azure/confidential-computing/confidential-containers)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Challenge 6 (optional) - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

### Goal

The goal of this challenge is to operate a sovereign hybrid cloud environment by combining Microsoft Sovereign Public Cloud and Sovereign Private Cloud components. You will work with Azure Local (simulated via LocalBox) as a sovereign on-premises cloud environment and use Azure Arc to bridge on-premises resources with Azure for unified governance, security, and management.

### Scenario

Your organization must run workloads in a sovereign cloud while still leveraging Azure's management and governance capabilities. Azure Local represents your sovereign on-premises infrastructure, and Azure Arc enables you to apply consistent governance across your hybrid estate.

### Actions

* Explore the ArcBox and LocalBox hybrid infrastructure in the Azure Portal
* Navigate Arc-enabled servers and understand their Azure resource representation
* Assign Azure Policy with Machine Configuration to audit/enforce OS settings on Arc-enabled Linux servers
* Deploy a VM on Azure Local using Azure Arc VM management
* Enable and review Microsoft Defender for Cloud security posture for Arc-enabled resources
* Explore Azure Update Manager for hybrid patching across Arc-connected machines

### Success criteria

* You can navigate and understand the ArcBox/LocalBox hybrid environment in the Azure Portal
* You have successfully assigned an Azure Policy (e.g., SSH security baseline) to Arc-enabled servers
* You can verify the compliance status of Arc-enabled servers in the Azure Policy dashboard
* You have deployed a VM on Azure Local via the Azure Portal
* You have enabled Microsoft Defender for Cloud and reviewed security recommendations for hybrid resources
* You understand how Azure Arc provides a unified control plane for sovereign hybrid scenarios

### Learning resources

* [Azure Arc-enabled Servers overview](https://learn.microsoft.com/azure/azure-arc/servers/overview)
* [Azure Local hybrid capabilities](https://learn.microsoft.com/azure/azure-local/hybrid-capabilities-with-azure-services-23h2)
* [Azure Machine Configuration (Guest Configuration)](https://learn.microsoft.com/azure/governance/machine-configuration/overview)
* [Azure Policy built-in definitions for Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/policy-reference)
* [Microsoft Defender for Cloud with Arc-enabled servers](https://learn.microsoft.com/azure/defender-for-cloud/quickstart-onboard-machines)
* [Azure Arc Jumpstart - LocalBox](https://jumpstart.azure.com/azure_jumpstart_localbox)
* [Govern Azure Arc-enabled servers (Microsoft Learn Training)](https://learn.microsoft.com/training/modules/govern-azure-arc-enabled-servers/)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-6/solution.md)

## Finish

Congratulations! You finished the MicroHack Microsoft Sovereign Cloud. We hope you had the chance to learn about the how to implement a successful...
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!


## Contributors
* Thomas Maurer [GitHub](https://github.com/thomasmaurer); [LinkedIn](https://www.linkedin.com/in/thomasmaurer2/)
* Jan Egil Ring [GitHub](https://github.com/janegilring); [LinkedIn](https://www.linkedin.com/in/janegilring/)
* Murali Rao Yelamanchili [GitHub](https://github.com/yelamanchili-murali); [LinkedIn](https://www.linkedin.com/in/muraliyelamanchili/)
* Ye Zhang [GitHub](https://github.com/zhangyems); [LinkedIn](https://www.linkedin.com/in/ye-zhang-497b96a7/)
