# Walkthrough 2 - Engineer the business model

[Home](../README.md) | [Previous](../challenge-01/solution-01.md) | [Next](../challenge-03/solution-03.md)

## Preconditions and capability gate

Finish Challenge 1, including its second execution and completed generation.
Have Copilot resolve all eight schema-enabled Delta URLs from actual metadata:
`https://onelake.dfs.fabric.microsoft.com/{workspaceId}/{lakehouseId}/Tables/dbo/{physicalTable}`.
Never use an invented GUID or bind a partly loaded generation.

The current [Create Semantic Model API](https://learn.microsoft.com/en-us/rest/api/fabric/semanticmodel/items/create-semantic-model)
supports an explicit `creationPayload.oneLakeTables` array. Use the actual eight
URLs with `displayName: sm_<scenario>` at
`POST /v1/workspaces/{workspaceId}/semanticModels`. Contributor rights, source
access and a valid authoring license are separate prerequisites.
This is an explicit model creation, not a default model.

Wait for terminal completion, record its actual model ID privately, then
`POST /v1/workspaces/{workspaceId}/semanticModels/{id}/getDefinition?format=TMSL`.
Decode the returned InlineBase64 `model.bim` and `definition.pbism` parts locally.
Inspect every partition (`directLake`, entity source, `dbo`, intended generation)
and the service-generated `AzureStorage.DataLake` shared expression.
If the API or exported shape is unsupported, stop and record the actual response.
Do not silently substitute SQL Direct Lake, Import or an empty model.

## Author and review the model

The coach implementation uses **model.bim/TMSL**, a supported reviewable equivalent
to TMDL, so enrichment can preserve the real service-generated source binding
without inventing a TMDL serializer. This is an explicit source-format deviation
from the initial TMDL proposal, not a change to the Direct Lake teaching objective.
Do not include both `model.bim` and `definition/**/*.tmdl` in one item definition.

From this walkthrough directory, after inspecting the script:

```powershell
python .\enrich-model.py --scenario banking `
  --seed-model C:\LabWork\private\seed-model.bim `
  --manifest C:\LabWork\datasets\manifest.json `
  --generation $DatasetHash --output C:\LabWork\private\banking.SemanticModel
```

Use `insurance` for the other path. The script refuses overwrite, unknown
generation/source tables, Import/SQL source and missing relationship columns.
It preserves partition/source expressions while creating logical table names,
single-direction star relationships, descriptions, hidden raw units and date
metadata. [Business DAX source](business_measures.py) drives all measures.
Review its stock/flow, blank, leap-year, filter-scope and complete-month behavior.

The source guard validates **each referenced expression**, accepting only the
reviewed direct `AzureStorage.DataLake(url, [HierarchicalNavigation = true])`
or a single `let Source = ... in Source` form with the same actual workspace/
Lakehouse GUID URI. Mixed, unused, SQL or differently shaped expressions stop
explicitly for review. This bounded allowlist is not a general M parser and does
not prove live identity, credentials or compatibility with every service export.

Use the tested modeling tool/TOM or service validation to parse the complete model
before acceptance. The local transformation tests are **not a DAX engine or TOM
parser**. Verify that Date is unique/contiguous, marked as the date key, month
sorts correctly and source numeric/boolean/date types survived export.

## Deploy, query and reconcile

Use [the payload helper](../prepare-definition.py) to encode the two model parts.
It performs no HTTP calls. For `updateDefinition`, send only its `definition`
member, not the create envelope with `displayName`. Review the complete payload
and update the **same resolved model ID** after approval. Repeated blind POST
creation is not idempotency.

Verify SSO/effective source permissions and frame/refresh using the tested toolchain.
OneLake Direct Lake and SQL-endpoint Direct Lake have different sources, security
and fallback behavior. Do not use on-premises `BindToGateway` for an arbitrary
cloud connection. If fixed-identity binding is required, stop for a reviewed
identity/permission design; never embed an OAuth token in M.

Execute [banking](banking-reconcile.dax) or
[insurance](insurance-reconcile.dax) query blocks against the deployed model.
For the Power BI ExecuteQueries API, submit **one EVALUATE block per request**,
using the Power BI audience, valid model Build/read rights and the required
tenant setting; a Fabric token alone is not proof of query access.
Use XMLA/modeling MCP only if explicitly supported and preflighted for the host.

Compare exact counts and raw cents with the independent CSV controls in the
manifest. Compare CHF after independent two-decimal rounding. Include all years,
month ends, February 2024/2025, selected product/branch/market slices and invalid
filter tests. A full-period loan stock must use December 2025, not 24 summed months.
Claims reserve releases are signed; recoveries are subtracted once.
Require explicit blanks/reasons for unsupported scope and zero denominators.

## Troubleshooting and evidence

Wrong table/entity: inspect the completed generation and the actual exported
partition; do not strip the generation suffix. Access errors: distinguish model
Build rights, source read rights, connection identity and license. Wrong totals:
check date selection and grain before changing DAX.

Keep the complete model source/diff, dataset hash, query text/results, identity
context and refresh outcome privately. No live query, connection or refresh has
been run by this walkthrough's source author. AC-05 is **NOT VALIDATED**.
