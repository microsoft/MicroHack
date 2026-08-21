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

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the PII processing notebook (35 min)

1. Open
   `../reference/ai-hub-gateway-solution-accelerator/workshop/5. citadel-pii-processing-tests.ipynb`.
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - **Use Case 1: PII Anonymization & Deanonymization** — `3️⃣.1`–`3️⃣.5` (define contract,
     product policy, parameter file + deploy, retrieve API key, test with various PII
     types)
   - **Use Case 2: PII Blocking** — `4️⃣.1`–`4️⃣.5` (same shape, blocking instead of masking)
   - **Use Case 3: PII Processing Performance Analytics** — `5️⃣.1`–`5️⃣.5` (Cosmos DB
     connection, grant data-plane access, query recent records, quantitative report +
     visualizations, deploy an analytics access contract, send the summary to an LLM)
3. Read the `📊 Results Summary` cell.

## 🏁 Success criteria

- [ ] The PII masking access contract anonymizes detected PII (names, emails, phone
      numbers, credit cards, IBANs, custom regex patterns) and can deanonymize it back.
- [ ] The PII blocking access contract detects and blocks requests containing PII,
      reporting what was detected.
- [ ] Your Cosmos DB query returns recent PII processing records, and the quantitative
      report/visualizations render successfully.
- [ ] The PII analytics access contract successfully sends the usage summary to an LLM
      through its own governed contract.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd env get-value` errors | `setup-notebook-env.ps1` hasn't been run — see Part A. |
| Cosmos DB query returns nothing / `Forbidden` | Section `5️⃣.1.1` grants your identity Cosmos DB data-plane access — re-run it and wait a minute for RBAC to propagate. |
| PII detection doesn't fire on a sample | Confirm the Azure AI Language Service instance is configured and reachable; some PII types need the exact regex/entity category the notebook defines. |
| Deanonymization returns masked text unchanged | The masking/deanonymization state must be saved via Event Hub first — confirm section `3️⃣.5` ran before attempting deanonymization. |

## 🚀 Go further

- Add a custom regex pattern for a PII type specific to your organization and confirm it
  is detected by both the masking and blocking contracts.

## 📚 Learning resources

- [Azure AI Language — PII detection](https://learn.microsoft.com/azure/ai-services/language-service/personally-identifiable-information/overview)
- [Azure API Management policy expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions)
