# Walkthrough 1 - From CSV to a trusted Lakehouse

[Home](../README.md) | [Next](../challenge-02/solution-02.md)

## Readiness and workspace first

This is a source-based coach approach, **not a claim of a tested live lab**.
Verify host/license/model/policy readiness first. Ask Copilot to propose each
operation and show its target; review before execution. Manual portal experiments
are allowed within the same permissions.

At Challenge 1 start, have Copilot create a workspace using the supported Fabric
workspace API, resolve its returned ID, then assign the organizer-provided F16
with the documented `assignToCapacity` operation. The administrator must have
preflighted tenant workspace creation and capacity-assignment rights without
giving participants capacity administration. Read back workspace capacityId.
On retry, use the saved actual workspace ID; stop on ambiguous name-only matches.
The creator administers **their workspace**, not shared compute.

Create a schema-enabled Lakehouse (`Lakehouse` type), inspect the actual `dbo`
table namespace and managed SQL analytics endpoint, and record its ID privately.
Do not claim item-type enforcement from a workspace role or these instructions.
If the managed endpoint is blocked by policy, escalate; do not disable policy.

## Upload a complete landing package

Run the staged `datasets\generate-data.py --validate` locally. For one scenario,
upload to `Files/landing/<scenario>/<datasetHash>/`:
`manifest.json`, reviewed `generate_data.py`, and `<scenario>/*.csv` preserving
the scenario subdirectory. Do not upload the other scenario or coach solutions.
Use delegated OneLake access as the participant; never stage an organizer token.

Derive `datasetHash` from the selected manifest entry; verify uploaded byte hashes
against the locally trusted manifest. A hash copied from an untrusted replacement
manifest is not an independent integrity check. Keep notebook-builder inputs
pointing to the original checksum-reviewed local dataset package.

## Author, review and execute a notebook

The [loader source](loader.py) is a coach reference, not participant starter code.
It verifies pinned verifier/manifest hashes before importing code, then calls the
dataset validator for strict headers/types/PKs/FKs/domains/controls. It constructs
all typed candidates before writes, persists immutable content-addressed Delta
tables and checks exact read-back rows plus independently recomputed controls.

Create a notebook file from the actual private bindings:

```powershell
python .\build-notebook.py --scenario banking `
  --datasets C:\LabWork\datasets `
  --landing "/lakehouse/default/Files/landing/banking/$DatasetHash" `
  --workspace-id $WorkspaceId --lakehouse-id $LakehouseId `
  --lakehouse-name lh_agentic_banking --output C:\LabWork\private\loader.ipynb
```

Inspect parameters, dependencies and the entire notebook diff. The default
Lakehouse metadata must point to the participant's actual item. The `dbo`
namespace check is deliberate; if runtime name resolution differs, stop and
adapt the qualified names using actual metadata rather than writing to another
catalog. No live Spark compatibility is asserted by local Python checks.

Encode with [prepare-definition.py](../prepare-definition.py) using
`--kind Notebook`. The helper creates `notebook-content.ipynb` in `ipynb` definition
format but makes no network calls. After approval, create/update the resolved
notebook through the [Notebook REST API](https://learn.microsoft.com/en-us/rest/api/fabric/notebook/items/create-notebook).
Run the notebook job with the tested Spark skill/API and wait for its terminal
job status, inspecting failures. Item creation or HTTP 202 is not execution.
Follow service Retry-After with a bounded timeout; do not loop forever.

## Reconcile twice and recover deliberately

Inspect each persisted table's schema, count and financial controls. The loader
uses `exceptAll` in both directions to catch changed/duplicate rows, then
recalculates controls from actual Delta read-back. The completion marker in
`Files/control/generations/<hash>/complete.json` appears only after every table
passes. Bind no semantic model until that marker and successful job exist.

Run the same notebook again. Existing identical tables are verified/reused,
not appended or overwritten. A corrupt existing table/marker fails explicitly.
After interruption, the marker is absent: rerun to verify/reuse completed tables
and finish the rest. A previous good generation remains untouched and any old
model remains bound to it. Remove a failed new generation only with owner approval
and after proving no model references it.

The small lab deliberately verifies candidates on the driver; it is not a
production-scale ingestion framework. Record two successful job results, all
counts/controls and source hashes privately. Both scenarios must still be piloted
in the event tenant; AC-04 is **NOT VALIDATED**.
