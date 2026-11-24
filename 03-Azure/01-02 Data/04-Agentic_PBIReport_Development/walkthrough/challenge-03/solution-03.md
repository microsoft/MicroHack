# Walkthrough 3 - Brief the management team

[Home](../README.md) | [Previous](../challenge-02/solution-02.md) | [Cleanup](../../resources/cleanup.md)

## Build actual visuals

Read both the selected business brief and
[design brief](../../resources/report-design-brief.md). Review the deployed model's
exact names. The deterministic [coach generator](build-report.py) creates two
populated pages with real model-bound cards, trends, comparisons, detail matrix,
slicers, scope/as-of values and synthetic labels. It does not create an empty report
or use hardcoded business numbers. It refuses to overwrite an existing revision.

```powershell
python .\build-report.py --scenario banking --output C:\LabWork\report-review-v1
powerbi-report-author validate C:\LabWork\report-review-v1\banking.Report
```

Use `insurance` for the equivalent path. Without `--model-id`, this is local
`byPath` source expecting a sibling `banking.SemanticModel`/`insurance.SemanticModel`
from Challenge 2. Add a PBIP wrapper with the tested Desktop tool if needed.
The generated [banking](examples/banking/banking.Report/definition.pbir) and
[insurance](examples/insurance/insurance.Report/definition.pbir) PBIR examples are
also retained for direct source review. Copy an example into a short exercise
path before editing. Long Windows checkout paths may require the `\\?\` absolute
path prefix for generation and `git -c core.longpaths=true` for Git operations;
do not modify shared checkout settings to work around this.

No fake environment IDs are committed. The initial visible **page filter is 2025**;
clear/change that filter in the filter pane before using the Year slicer for 2024.
Explain this state to participants; a Year slicer cannot override a page filter.

Inspect the JSON/diff and visual bindings. Run the tested authoring CLI after
every logical batch. Current local checks used authoring CLI 0.1.1 and the explicit
schema URIs in the generator. This is not a promise that every future Desktop build
accepts/renders those schemas identically.

## Bind and deploy the reviewed definition

Resolve the actual returned semantic model ID from Challenge 2. Prepare a service
copy with [prepare-definition.py](../prepare-definition.py) using `--kind Report`,
the `.Report` directory, `--display-name` and `--model-id`. The helper replaces
`byPath` with only `byConnection.connectionString = semanticmodelid=<actual-id>`
in the transport payload, leaving local source unchanged.

After review, use
`POST /v1/workspaces/{workspaceId}/reports` with the full definition to create,
or `POST /v1/workspaces/{workspaceId}/reports/{reportId}/updateDefinition` with
only the definition member to update the resolved existing report. Honor bounded
LRO/Retry-After handling. Preserve ID-based retry state privately; ambiguous
same-name items are an error, not permission to create another report.

## Render, test and iterate

Open the deployed report in Power BI. For a supported Desktop preview, use
`powerbi-desktop status`, select the correct PID, then reload/screenshot serially.
The author's local bridge reported **not_connected**; no rendering evidence exists.
Service rendering against the actual model is still mandatory.

Check titles, no error visuals, readable CHF/%/as-of values, complete-month
insurance behavior, default and reset filters, and totals against Challenge 2.
Select channel/claim-type/risk bars and confirm only intended scope is affected.
The model must also guard unsupported ad-hoc contexts. A schema validator cannot
prove interactions or numbers; do not declare AC-06 passed from its output.

Ask Copilot for a concrete revision: for example, clarify that a bank channel chart
shows activity rather than portfolio, or make the insurance partial-period warning
visible. Generate a new revision folder, inspect the diff, validate, redeploy,
render and compare. Save redacted before/after screenshots privately.

## Coach completion discussion

Have the learner explain stock versus flow, filter scope, independent controls
and one agent mistake. Compare two synthetic insights with their caveats.
Retain source and query evidence, then follow [cleanup](../../resources/cleanup.md).
No rendered report, live binding or successful filter interaction is asserted here.
