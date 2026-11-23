# Challenge 1 - From CSV to a trusted Lakehouse

[Home](README.md) | [Next](challenge-02.md)

## Goal

Use Copilot to create your workspace on the designated shared F16, create a
Lakehouse, upload the chosen scenario, and author and execute an idempotent loader
notebook. Establish trustworthy data before asking for a report.

## Actions

1. Complete [host readiness](../resources/host-readiness.md). Verify both local
   scenario folders against `datasets/manifest.json`; choose one. Read its brief,
   dictionary, grains and reference controls. Agree a workspace alias with your coach.
2. Ask Copilot for a plan to create your workspace and assign the **provided**
   capacity. Review account, region, permissions, names and intended item types.
   Approve only those operations. Have Copilot create/resolve the workspace, inspect
   the assignment result, then create a schema-enabled Lakehouse. Do not accept
   name-only matching or create a second workspace on a retry.
3. Ask Copilot to upload the selected CSVs and manifest to Lakehouse Files under
   a dataset-hash-specific landing path. Verify every uploaded byte hash. A listed
   filename is not proof of a complete upload.
4. Have Copilot author a notebook attached to **your** Lakehouse. Require explicit
   types, strict parsing, exact headers, PK/FK/domain checks and financial controls.
   Inspect its source/diff before deploying or executing. Never infer money as
   floating point or append the same batch again.
5. Execute and monitor the notebook to terminal success, then query all Delta row
   counts and financial totals against the manifest. Run it twice. Demonstrate
   unchanged counts/totals and a complete generation marker, not partial tables.
6. Save reviewed notebook source and redacted run evidence privately; make a local
   Git checkpoint in your own exercise folder, excluding IDs, tokens and credentials.

Suggested opening prompt:

> Read my chosen brief and manifest. Propose, do not yet execute, a workspace,
> Lakehouse and typed loader plan. Show each permission and validation gate.
> Use my supplied capacity, not a new capacity. Ask before writes and stop on
> unsupported capabilities. Do not use any other participant's resources.

## Hints

First: inspect the manifest before generating code. Next: read CSV as strings and
validate before casting. Stronger: use immutable tables named by a validated
dataset hash and publish a marker only after every table reconciles. If interrupted,
verify and reuse identical tables; never overwrite a previous good generation.

## Success criteria

Workspace is actually assigned to the intended capacity; selected files are verified;
notebook execution succeeded; every Delta table has the correct grain, count and
controls; second execution is unchanged. Record source version, dataset hash,
workspace/Lakehouse aliases, job result and comparisons in **private** evidence.
These are AC-03/AC-04 evidence, not proof of AC-09 policy enforcement.

## Learning resources

- [Lakehouse overview](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-overview)
- [Fabric REST API](https://learn.microsoft.com/en-us/rest/api/fabric/articles/)
