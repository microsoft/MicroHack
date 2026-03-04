# Challenge 5 - Encryption in use with Confidential VMs/Node Pools in Azure Kubernetes Service (AKS)

[Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-06.md)

## Goal

Deploy and validate guest attestation on Azure Confidential VMs to ensure business logic only executes in trusted, compliant confidential computing environments. You'll build and deploy a sample application that implements secure attestation flows using Confidential VMs in AKS. The application leverages Microsoft Azure Attestation (MAA) to validate VM integrity before executing protected business logic, demonstrating "encryption in use" capabilities.

## Actions

* Create an AKS Cluster
* Add a Confidential VM Node Pool
* Verify Node Pool Configuration
* Run Attestation Verification Sample
* Review the attestation token output

## Success criteria

* Attestation token output proving the App is running in a trusted confidential environment

## Learning resources

* [Azure confidential computing](https://learn.microsoft.com/azure/confidential-computing/)
* [Azure encryption overview](https://learn.microsoft.com/azure/security/fundamentals/encryption-overview)
* [Azure Confidential Computing Overview](https://learn.microsoft.com/azure/confidential-computing/overview)
* [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
* [Confidential containers on Azure](https://learn.microsoft.com/azure/confidential-computing/confidential-containers)

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 5](../walkthrough/challenge-05/solution-05.md)

</details>
