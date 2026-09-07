# Challenge 4 - Encryption in use with Azure Confidential Compute – VM

[Previous Challenge](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-05.md)

## Goal

Validate guest attestation on a pre-provisioned Azure Confidential VM to confirm that business logic only executes in a trusted, hardware-backed confidential computing environment. You will inspect the VM's security configuration, connect through Azure Bastion using username/password credentials, build and run a sample attestation application, and verify the cryptographic JWT proof of VM integrity using a dedicated Microsoft Azure Attestation (MAA) provider.

## Actions

* Inspect the pre-provisioned Confidential VM security settings (security type, secure boot, vTPM, no public IP)
* Connect to the Confidential VM via Azure Bastion using username/password credentials from your lab dashboard
* Install dependencies, build, and run the CVM guest attestation sample application
* Inspect the attestation token JWT claims to verify the confidential computing environment

## Success criteria

* Attestation token output proving the VM is running in a trusted confidential environment

## Learning resources

* [Azure confidential computing](https://learn.microsoft.com/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
* [About Azure confidential VMs](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 4](../walkthrough/challenge-04/solution-04.md)

</details>
