# Challenge 5 - Confidential workloads on AKS

## Goal

Deploy the Azure Voting App and a runtime attestation UI to an Azure Kubernetes
Service cluster. Pin the user-facing workloads to an AMD SEV-SNP Confidential
VM node pool and verify the execution environment with a fresh MAA token.

## Actions

- Connect to the provided AKS cluster shared with Challenge 7.
- Validate its two Ubuntu AMD SEV-SNP nodes labelled `workload=confidential`.
- Deploy the Azure Voting App to the confidential nodes.
- Deploy the newer runtime attestation UI to the same node pool.
- Verify pod placement and inspect the attestation claims.
- Remove only Challenge 5 applications from `challenge-05`, retaining AKS and its pools for Challenge 7.

## Success criteria

- Voting front-end pods run on nodes labelled `workload=confidential`.
- The voting application is reachable through its LoadBalancer service.
- The attestation UI returns an MAA-signed SEV-SNP token.
- The token reports `azure-compliant-cvm` and a non-debuggable TEE.

## Learning resources

- [When Confidential VM Orchestrator is required](../walkthrough/challenge-05/CVM-ORCHESTRATOR.md)
- [Use Confidential VMs in AKS](https://learn.microsoft.com/azure/aks/use-cvm)
- [AKS confidential computing overview](https://learn.microsoft.com/azure/aks/confidential-computing-overview)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
- [Source sample: Azure Voting App on confidential AKS nodes](https://github.com/Azure/confidential-computing/tree/main/aks-samples/azure-voting-app)
