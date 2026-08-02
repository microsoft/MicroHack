# Challenge 5 - Confidential workloads on AKS

[Previous Challenge](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-06.md)

## Goal

Deploy the Azure Voting App and a runtime attestation UI to an Azure Kubernetes
Service cluster. Pin the user-facing workloads to an AMD SEV-SNP Confidential
VM node pool and verify the execution environment with a fresh MAA token.

## Actions

- Deploy an AKS cluster with managed identity and automatic upgrade channels.
- Add and label an AMD SEV-SNP Confidential VM node pool.
- Deploy the Azure Voting App to the confidential nodes.
- Deploy the newer runtime attestation UI to the same node pool.
- Verify pod placement and inspect the attestation claims.
- Remove the AKS cluster without deleting the shared attendee resource group.

## Success criteria

- Voting front-end pods run on nodes labelled `workload=confidential`.
- The voting application is reachable through its LoadBalancer service.
- The attestation UI returns an MAA-signed SEV-SNP token.
- The token reports `azure-compliant-cvm` and a non-debuggable TEE.

## Learning resources

- [Use Confidential VMs in AKS](https://learn.microsoft.com/azure/aks/use-cvm)
- [AKS confidential computing overview](https://learn.microsoft.com/azure/aks/confidential-computing-overview)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
- [Source sample: Azure Voting App on confidential AKS nodes](https://github.com/Azure/confidential-computing/tree/main/aks-samples/azure-voting-app)

## Solution

> [!TIP]
> Before opening the walkthrough, decide how Kubernetes can constrain a workload to confidential nodes.

[Automated walkthrough for Challenge 5](../walkthrough/challenge-05/solution-05.md)
