# Challenge 4 - Runtime attestation with Confidential ACI

## Goal

Deploy the same visual attestation application to Confidential and Standard
Azure Container Instances (ACI). Use the side-by-side result to prove that
runtime attestation depends on AMD SEV-SNP hardware rather than application
logic alone.

## Actions

- Build the visual attestation image server-side in Azure Container Registry.
- Generate a confidential-computing enforcement policy for the image.
- Deploy the image to Confidential and Standard ACI container groups.
- Run attestation in both applications and compare the results.
- Inspect the Microsoft Azure Attestation claims from the confidential instance.
- Remove only the resources created by this challenge.

## Success criteria

- Confidential ACI returns a signed MAA token with `x-ms-attestation-type` set to `sevsnpvm`.
- The compliance status is `azure-compliant-uvm`.
- Standard ACI fails because `/dev/sev-guest` is unavailable.
- Both instances use the same container image.

## Learning resources

- [Why Challenge 4 uses `confcom` and Docker](../walkthrough/challenge-04/CONFCOM-AND-CCE-POLICY.md)
- [Confidential containers on Azure Container Instances](https://learn.microsoft.com/azure/container-instances/container-instances-confidential-overview)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
- [Confidential computing enforcement policies](https://learn.microsoft.com/azure/container-instances/confidential-containers-attestation-concepts)
- [Source sample: Visual Attestation Demo v2](https://github.com/Azure/confidential-computing/tree/main/aci-samples/visual-attestation-demo-v2)
