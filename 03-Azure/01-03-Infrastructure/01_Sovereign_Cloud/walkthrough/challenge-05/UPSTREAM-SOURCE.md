# Challenge 5 upstream source

The local [`resources/azure-voting-app`](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-05/resources/azure-voting-app/README.md)
directory is a byte-for-byte snapshot of the Azure Confidential Computing
Azure Voting App sample.

- Original repository: `Azure/confidential-computing`
- Source path: `aks-samples/azure-voting-app`
- Source commit: `37f033361f1ded657e26382534f42b5f95a88054`
- Source commit date: 2026-06-04

The original repository and commit URL returned HTTP 404 during the 2026-09-30 link check. Use the checked-in snapshot linked above; the provenance values are retained for reference, and the snapshot has not been changed.

Do not edit the snapshot when making MicroHack-specific changes. The
top-level `Deploy-VotingAppCC.ps1` starts from the upstream script and contains
the workshop adaptations.

> [!IMPORTANT]
> Run the top-level script from the Challenge 5 walkthrough directory. The
> script inside `resources/azure-voting-app` is the unchanged upstream
> reference and creates and deletes its own resource group.

## MicroHack adaptations

1. Read `RESOURCE_GROUP` and the Console-provided `AKS_CLUSTER`, with explicit parameter overrides.
2. Use the active Azure CLI subscription; no Az PowerShell session or unused-quota preflight is required for application deployment.
3. Validate the existing shared AKS cluster and its two labeled Ubuntu confidential nodes; never create, scale or delete infrastructure.
4. Use a temporary kubeconfig, explicit context and owned `challenge-05` namespace for every Kubernetes command. Preserve Challenge 7's Radius namespaces.
5. Resolve attestation assets from the unchanged local snapshot.
6. Delete only the named Challenge 5 deployments, services and ConfigMap during cleanup. Retain the cluster and node pools.

When updating the sample, replace the complete snapshot from one upstream
commit, update the commit above, and review the top-level script diff against
the new upstream `Deploy-VotingAppCC.ps1`.