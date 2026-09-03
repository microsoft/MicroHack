# Challenge 5 — PII Anonymization, Blocking & Analytics

**[Home](../README.md)** - [← Previous Challenge](challenge-04.md) - [Next Challenge →](challenge-06.md)

## 🎯 Objective

Verify PII processing in Citadel Access Contracts across three use cases: **PII
anonymization/deanonymization** with state saving, **PII blocking** with detection
reporting, and **PII processing performance analytics** — testing various PII types
(names, emails, phone numbers, credit cards, IBANs, etc.) and custom regex detection.

## 🧭 Context

This notebook assumes your Citadel Governance Hub already has PII processing enabled:
an Azure AI Language Service instance with PII detection, the `pii-anonymization`,
`pii-deanonymization`, and `pii-state-saving` APIM policy fragments deployed, and Event
Hub configured for PII state logging. These are part of the lab's hub deployment — you
don't need to provision anything extra beyond confirming your notebook environment.

## ✅ Tasks

> [!IMPORTANT]
> **Challenge 1 must be completed first — not just its environment setup.**
> Notebook 1 deploys the APIM **policy fragments** (`set-llm-requested-model`,
> `validate-model-access`, `set-backend-pools`, `set-target-backend-pool`,
> `set-backend-authorization`, `set-llm-usage`) that this challenge's product
> policy includes with `<include-fragment>`. The lab's hub deployment
> intentionally ships only a minimal gateway, so if you jump straight here the
> Bicep deployment fails with a *"Policy fragment not found"* error.

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the PII processing notebook (35 min)

1. Open
   `workshop/5. citadel-pii-processing-tests.ipynb`
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - **Use Case 1: PII Anonymization & Deanonymization** — `3️⃣.1`–`3️⃣.5` (define contract,
     product policy, parameter file + deploy, retrieve API key, test with various PII
     types)
   - **Use Case 2: PII Blocking** — `4️⃣.1`–`4️⃣.5` (same shape, blocking instead of masking)
   - **Use Case 3: PII Processing Performance Analytics** — `5️⃣.1`–`5️⃣.5` —
     ⏭️ **skip this section.** It is optional and cannot run in the MicroHack
     environment (see the note below). The notebook detects this and skips it
     cleanly, so you can simply run the cells and move on.
3. Read the `📊 Results Summary` cell.

> **Why Use Case 3 is skipped**
>
> Two things block it, and neither is something you can change:
>
> - The subscription applies an Azure Policy (`CosmosDB_PublicNetwork_Modify`) that
>   forces the Cosmos DB account's public network access to stay disabled. Enabling it
>   in the portal does **not** work — the change is reverted immediately, so the setting
>   never changes. `CosmosDB_LocalAuth_Modify` likewise forces key auth off, so the
>   notebook's `cosmos_auth_mode = "key"` fallback is unavailable too.
> - The `pii-usage-container` has no writer in this lab: the usage-ingestion Logic App
>   that would move events from Event Hub into Cosmos is not deployed, so the query
>   would return zero records even with network access.
>
> The audit trail itself **does** work. The `pii-state-saving` policy fragment emits an
> event to the `usage-events` Event Hub for every PII operation — check *Metrics →
> Incoming Messages* on the Event Hub namespace in the portal to see them arrive. Only
> the Cosmos-backed reporting layer built on top of it is missing.

## 🏁 Success criteria

- [ ] The PII masking access contract anonymizes detected PII (names, emails, phone
      numbers, credit cards, IBANs, custom regex patterns) and can deanonymize it back.
- [ ] The PII blocking access contract detects and blocks requests containing PII,
      reporting what was detected.
- [ ] The masking verification probe confirms the model received a placeholder rather
      than the real name — a `200` response on its own does not prove masking, because
      deanonymization restores the original values on the way out.
- [ ] You can see PII events arriving in the `usage-events` Event Hub (*Metrics →
      Incoming Messages*), which is the audit trail behind the masking policy.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| Setup cell raises a missing-key error | Your `challenges/workshop/.env` is missing that key (or you haven't run the `azd` bridge) — see [Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min). |
| `CosmosHttpResponseError: (Forbidden) Request originated from IP ...` | Expected — Use Case 3 is optional and cannot run here. Azure Policy keeps Cosmos DB's public network access disabled and reverts any attempt to enable it. The notebook skips the section automatically; carry on. |
| Masking tests all pass but you're unsure anything was masked | Run the masking verification cell. Because deanonymization restores the original values, a `200` looks identical whether or not masking occurred — the probe asks the model a question only an *unmasked* request could answer. |
| PII detection doesn't fire on a sample | Confirm the Azure AI Language Service instance is configured and reachable; some PII types need the exact regex/entity category the notebook defines. |
| Deanonymization returns masked text unchanged | The masking/deanonymization state must be saved via Event Hub first — confirm section `3️⃣.5` ran before attempting deanonymization. |

## 🚀 Go further

- Add a custom regex pattern for a PII type specific to your organization and confirm it
  is detected by both the masking and blocking contracts.

## 📚 Learning resources

- [Azure AI Language — PII detection](https://learn.microsoft.com/azure/ai-services/language-service/personally-identifiable-information/overview)
- [Azure API Management policy expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions)
