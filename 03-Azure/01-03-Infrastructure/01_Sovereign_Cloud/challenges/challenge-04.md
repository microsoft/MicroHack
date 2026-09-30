# Challenge 4 - Runtime attestation with Confidential ACI

## Goal

Deploy the same visual attestation application to Confidential and Standard
Azure Container Instances (ACI). Use the side-by-side result to prove that
runtime attestation depends on AMD SEV-SNP hardware rather than application
logic alone.

## Understand Runtime Attestation Fundamentals

Encryption at rest and in transit protect stored data and network traffic.
Confidential computing adds protection for data **while it is being processed**.
Runtime attestation provides evidence about that protected environment that a
relying party can evaluate before trusting it.

This challenge is a controlled experiment: run **one application image in two
environments**. Confidential ACI can obtain an AMD SEV-SNP hardware attestation
report and submit it to Microsoft Azure Attestation (MAA) for a signed token.
Standard ACI runs the same application but cannot obtain that report. Its
attestation failure is the expected negative control, not a failed lab.

The flow is **build one image → approve its confidential runtime configuration →
deploy both environments → request attestation → compare the evidence**.
Azure Container Registry builds the image remotely. For the confidential
deployment, the Azure CLI `confcom` extension uses a local Docker engine to
inspect image layers and generate a confidential-computing enforcement (CCE)
policy: the rules for what the confidential runtime may run. Docker is
preparation tooling here, not the location where the comparison applications run.

By the end, you should be able to explain the difference between hardware-backed
attestation and an application's own claim to be secure, identify the expected
MAA claims, and describe why the enforcement policy matters. Inspecting the demo's
token is a learning exercise, not a complete production token-validation or
sovereignty-compliance solution.

## Actions

- Continue in the [recommended GitHub Codespaces environment](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/Readme.md#recommended-environment-github-codespaces)
  used for all challenges. Start `pwsh` from its Bash terminal and
  [verify the Linux Docker Engine](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-04/solution-04.md#verify-your-environment-before-you-start)
  before deployment; Azure Cloud Shell cannot generate this CCE policy.
- Understand runtime attestation and the purpose of the two-environment experiment.
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

- [Why Challenge 4 uses `confcom` and Docker](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-04/CONFCOM-AND-CCE-POLICY.md#the-short-answer)
- [Codespaces setup for all challenges](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/Readme.md#recommended-environment-github-codespaces)
- [Optional local Windows Docker Desktop preparation](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-04/solution-04.md#windows-docker-desktop-setup-before-the-workshop)
- [Confidential containers on Azure Container Instances](https://learn.microsoft.com/azure/container-instances/container-instances-confidential-overview)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
- [Confidential computing enforcement policies](https://learn.microsoft.com/azure/container-instances/confidential-containers-attestation-concepts)
- [Source sample: Visual Attestation Demo v2 (checked-in snapshot)](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-04/resources/visual-attestation-demo-v2/README.md)
