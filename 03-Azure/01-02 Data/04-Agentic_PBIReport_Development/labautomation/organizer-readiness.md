# Organizer readiness

The [deployment guide](README.md) describes the supplied nonsecret settings,
actual pinned assets, private Bastion access and two host configurations.
No custom environment injection or private event JSON file is required.
Infrastructure provisioning is distinct from permission to admit learners.

Before delivery, record private evidence for:

- Enabled Power BI author service plans and seat stock for each identity, plus
  Copilot seats, permitted models and usage budget. F16 alone is not a license.
- Fabric workspace creation and assignment rights, and supported ItemCreation
  policies for Lakehouse, Notebook, SemanticModel and Report. Verify the managed
  SQL endpoint dependency and coverage for new workspaces. Do not grant capacity
  admin to participants or pretend instructions enforce allowed types.
- Region/VM SKU availability, quotas and Azure Policy, Windows Server license
  inclusion, outbound download hosts and working browser Bastion connections.
  Windows client images/Hybrid Benefit are not enabled by these defaults.
- Correct source and package pins from `lab-settings.psd1`, downloaded hashes,
  installed runtime and VSIX versions and the npm lock. Validate the selected
  Fabric skills and shared references; do not rely on outdated skill names.
- First-login initialization and complete three-challenge journeys through
  **each host separately**. Confirm tools actually start, skills are discovered,
  interactive Fabric/Power BI authentication works with the required token
  audiences, Spark executes, DAX reconciles and report rendering/filters work.
- Two-identity isolation for Windows credentials, VM reachability and Fabric
  workspace/data access. Shared subscription Reader reveals infrastructure
  metadata; it is not data/workspace isolation.
- Measured F16 concurrency, Bastion load, actual VM/F16/Bastion/NAT/IP/storage/
  egress/license costs, retention and cleanup. Approve platform estimates and
  cohort settings before participant admission; no measured envelope is supplied.

Retain source ref, dataset hashes, image version, tools/skills/extensions,
approved model, schemas, timestamps and assertion-specific results privately.
Follow the [release ledger](../resources/release-gates.md) and obtain independent
review before promotion from Testing. Do not fill missing evidence with a default
approval or treat offline tests/provider metadata as live acceptance.

Give learners their identity, capacity information, workspace naming guidance,
the approved version/model record and support route. They follow
[participant readiness](../resources/host-readiness.md), verify the supplied VM,
sign in interactively and start workspace creation in Challenge 1.
