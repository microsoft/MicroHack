# Challenge 3 — Access Contracts: Model RBAC & Capacity

**[Home](../README.md)** - [← Previous Challenge](challenge-02.md) - [Next Challenge →](challenge-04.md)

## 🎯 Objective

Provision and validate **three Access Contracts** with different configurations and
targets, each backed by a dynamically generated APIM product policy enforcing
model-level RBAC (`allowedModels`) and capacity allocation (`llm-token-limit`), and
explore optional Key Vault and Microsoft Foundry connection integrations.

## 🧭 Context

| Access Contract | Configuration | Target runtime |
|---|---|---|
| Sales-Assistant | Key Vault integration only | Agents on AKS / ACA / App Service |
| HR-ChatAgent | Key Vault + Foundry connection integrations | Foundry Agents |
| Support-Bot | Direct output (no Key Vault, no Foundry) | Custom hosted agents |

The Foundry connection name(s) this notebook prints are consumed by
[Challenge 4](challenge-04.md), so keep this notebook's output around before moving on.
As always, confirm
[`setup-notebook-env.ps1`](../labautomation/README.md#notebook-environment-setup) has
already been run.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the access contracts notebook (35 min)

1. Open
   `workshop/3. citadel-access-contracts-tests.ipynb`
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Define Access Contract Configurations`
   - `4️⃣ Create Access Contract Parameter Files`
   - `4️⃣.1 Deploy Access Contracts Using 🦾 Bicep`
   - `4️⃣.2 Foundry Connection Names (for downstream notebooks)`
   - `5️⃣ Retrieve API Keys for Each Access Contract`
   - `6️⃣ Test API Requests Across All Access Contracts`
   - `7️⃣ Run Load Test Across All Access Contracts`
   - `8️⃣ Visualize Results Across All Access Contracts`
   - `9️⃣ Compare Token Bucket Behavior`
3. Read the `📊 Results Summary` cell. **Do not run the `🧹 Cleanup (Optional)` cell
   yet** if you plan to continue to Challenge 4 — it deletes the access contracts.

## 🏁 Success criteria

- [ ] All three access contracts (APIM products + subscriptions) deployed successfully
      via Bicep, each with its own dynamically generated product policy.
- [ ] Requests against each contract respect its `allowedModels` RBAC list.
- [ ] The load test shows throttling behaviour consistent with each contract's
      `llm-token-limit` capacity allocation.
- [ ] The Foundry connection name(s) for HR-ChatAgent were printed and noted for
      Challenge 4.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd env get-value` errors | `setup-notebook-env.ps1` hasn't been run — see Part A. |
| Key Vault integration fails to resolve a secret | Confirm the spoke Key Vault name resolved correctly and your identity has data-plane access (RBAC propagation can take a minute). |
| Foundry connection step fails | Confirm the spoke Foundry account/project names resolved from `azd env get-value` — re-check `setup-notebook-env.ps1` was run with the correct `SpokeAiFoundryAccountName` / `SpokeAiFoundryProjectName` values. |
| Load test results look flat (no 429s) | Capacity limits are per-contract; make sure you're hitting the right subscription key for the contract you're testing. |

## 🚀 Go further

- Add a fourth access contract configuration with a tighter `allowedModels` list and
  compare its token-bucket behaviour against the three built-in contracts.

## 📚 Learning resources

- [Rate limit and quota policies in Azure API Management](https://learn.microsoft.com/azure/api-management/rate-limit-policy)
- [Connections in Microsoft Foundry projects](https://learn.microsoft.com/azure/ai-foundry/how-to/connections-add)
