# Challenge 5 upstream source

The local [`resources/azure-voting-app`](resources/azure-voting-app/README.md)
directory is a byte-for-byte snapshot of the Azure Confidential Computing
Azure Voting App sample.

- Repository: <https://github.com/Azure/confidential-computing>
- Source path: `aks-samples/azure-voting-app`
- Source commit: [`37f033361f1ded657e26382534f42b5f95a88054`](https://github.com/Azure/confidential-computing/tree/37f033361f1ded657e26382534f42b5f95a88054/aks-samples/azure-voting-app)
- Source commit date: 2026-06-04

Do not edit the snapshot when making MicroHack-specific changes. The
top-level `Deploy-VotingAppCC.ps1` starts from the upstream script and contains
the workshop adaptations.

> [!IMPORTANT]
> Run the top-level script from the Challenge 5 walkthrough directory. The
> script inside `resources/azure-voting-app` is the unchanged upstream
> reference and creates and deletes its own resource group.

## MicroHack adaptations

1. Read `RESOURCE_GROUP`, `ATTENDEE_ID`, `HASH_SUFFIX`, and `LOCATION` from the
   established MicroHack environment variables.
2. Derive the subscription from the active Azure CLI account and retain the
   upstream requirement for the Az PowerShell context to target that same
   subscription.
3. Reuse the attendee resource group instead of creating or deleting a resource
   group.
4. Derive a deterministic AKS cluster name from `HASH_SUFFIX` and make cluster
   and confidential node-pool creation rerunnable.
5. Resolve attestation assets from the unchanged local snapshot.
6. Delete only the Challenge 5 AKS cluster during cleanup.

When updating the sample, replace the complete snapshot from one upstream
commit, update the commit above, and review the top-level script diff against
the new upstream `Deploy-VotingAppCC.ps1`.