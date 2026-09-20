# Challenge 5 - Encryption in use with Confidential VMs/Node Pools in Azure Kubernetes Service (AKS)

## Goal

Validate guest attestation on a pre-provisioned Azure Confidential VM node pool in AKS to ensure business logic only executes in trusted, compliant confidential computing environments. You'll inspect the AKS cluster and Confidential VM node pool that were deployed for you, then deploy a sample application that implements secure attestation flows. The application leverages Microsoft Azure Attestation (MAA) to validate VM integrity before executing protected business logic, demonstrating "encryption in use" capabilities.

## Actions

* Inspect the pre-provisioned AKS cluster and Confidential VM node pool
* Validate node pool configuration (VM size, node image, node labels)
* Deploy the attestation verification sample
* Review the attestation token output

## Success criteria

* Attestation token output proving the App is running in a trusted confidential environment

## Learning resources

* [Azure confidential computing](https://learn.microsoft.com/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
* [Confidential containers on Azure](https://learn.microsoft.com/azure/confidential-computing/confidential-containers)
