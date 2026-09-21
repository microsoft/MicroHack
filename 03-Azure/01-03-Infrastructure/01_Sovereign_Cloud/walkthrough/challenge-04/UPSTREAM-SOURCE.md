# Challenge 4 upstream source

The local [`resources/visual-attestation-demo-v2`](resources/visual-attestation-demo-v2/README.md)
directory is a byte-for-byte snapshot of the Azure Confidential Computing
Visual Attestation Demo v2 sample.

- Repository: <https://github.com/Azure/confidential-computing>
- Source path: `aci-samples/visual-attestation-demo-v2`
- Source commit: [`62fea0b9ce0ead5b615a3f8d19fd6d27a15cb29d`](https://github.com/Azure/confidential-computing/tree/62fea0b9ce0ead5b615a3f8d19fd6d27a15cb29d/aci-samples/visual-attestation-demo-v2)
- Source commit date: 2026-07-13

Do not edit the snapshot when making MicroHack-specific changes. The
top-level `Deploy-VisualAttestationV2.ps1` starts from the upstream script and
contains the workshop adaptations.

> [!IMPORTANT]
> Run the top-level script from the Challenge 4 walkthrough directory. The
> script inside `resources/visual-attestation-demo-v2` is the unchanged
> upstream reference and retains the upstream resource-group lifecycle.

## MicroHack adaptations

1. Read `RESOURCE_GROUP`, `ATTENDEE_ID`, `HASH_SUFFIX`, and `LOCATION` from the
   established MicroHack environment variables.
2. Reuse the attendee resource group instead of creating or deleting a resource
   group.
3. Derive deterministic ACR, container-group, and DNS names from `HASH_SUFFIX`.
4. Copy ARM templates and generated parameter files to a temporary directory so
   credentials and generated policy changes are not written into the snapshot.
5. Clear the policy only in the temporary confidential template and approve
   wildcard prompts so `confcom` can run non-interactively.
6. Delete only the two Challenge 4 container groups and ACR during cleanup.
7. Require cleanup before another build is recorded with the same workshop
   values.
8. Remove the tagged local Docker image during cleanup so a later clean run
   cannot generate a CCE policy from stale local layers.

When updating the sample, replace the complete snapshot from one upstream
commit, update the commit above, and review the top-level script diff against
the new upstream `Deploy-VisualAttestationV2.ps1`.