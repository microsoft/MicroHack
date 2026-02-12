# Challenge 4 - Encryption in use with Azure Confidential Compute – VM

[Previous Challenge Solution](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-05.md)

## Goal

Deploy and validate guest attestation on Azure Confidential VMs to ensure business logic only executes in trusted, compliant confidential computing environments. You'll build and deploy a sample application that implements secure attestation flows using Azure Confidential VMs. The application leverages Microsoft Azure Attestation (MAA) to validate VM integrity before executing protected business logic, demonstrating "encryption in use" capabilities.

## Actions

* Create Key Vault and SSH Keys
* Create Attestation Provider
* Create Virtual Network and Confidential VM
* Create Azure Bastion
* Configure Confidential VM (Run on the CVM)
* Review the attestation token output

## Success criteria

* Attestation token output proving the VM is running in a trusted confidential environment

## Learning resources

* [Azure confidential computing](https://learn.microsoft.com/en-us/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/en-us/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/en-us/azure/attestation/overview)
* [About Azure confidential VMs](https://learn.microsoft.com/en-us/azure/confidential-computing/confidential-vm-overview)


