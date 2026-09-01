# Challenge 4 — Drive Access Contracts from Agent Frameworks

**[Home](../README.md)** - [← Previous Challenge](challenge-03.md) - [Next Challenge →](challenge-05.md)

## 🎯 Objective

Drive the three access contracts from [Challenge 3](challenge-03.md) through three
different agent frameworks — Microsoft Agent Framework, Microsoft Foundry Agent SDK, and
LangChain — each simulating a multi-turn conversation, then compare token consumption
across frameworks.

## 🧭 Context

| Access Contract | Agent Framework | Integration | Target model |
|---|---|---|---|
| Sales-Assistant | Microsoft Agent Framework | Azure Key Vault (endpoint + key), with an APIM fallback — see Troubleshooting | gpt-4.1 |
| HR-ChatAgent | Microsoft Foundry Agent SDK | Foundry Project Connection | gpt-4.1 |
| Support-Bot | LangChain | Local (direct endpoint + key) | phi-4 |

**This notebook requires [Challenge 3](challenge-03.md) to have been completed first** —
it reuses the access contracts that notebook created and does not deploy any APIM
resources itself.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the agent frameworks notebook (30 min)

1. Open
   `workshop/4. citadel-agent-frameworks-tests.ipynb`
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Retrieve Access Contract API Keys`
   - `4️⃣ Install Required Agent Frameworks`
   - `5️⃣ Microsoft Agent Framework (Sales-Assistant)`
   - `6️⃣ Microsoft Foundry Agent SDK (HR-ChatAgent)`
   - `7️⃣ LangChain Agent (Support-Bot)`
   - `8️⃣ Display Agent Statistics and Comparison`
   - `9️⃣ Token Efficiency Analysis`
3. Read the `📊 Results Summary` cell, which compares integration patterns across the
   three frameworks.

## 🏁 Success criteria

- [ ] All three agent frameworks are installed and each successfully authenticates
      against its access contract's API key.
- [ ] Each agent completes a multi-turn conversation relevant to its business domain
      (sales pricing, HR policies, technical support).
- [ ] The agent-statistics comparison and token-efficiency analysis produce a table
      comparing all three frameworks.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| API key retrieval fails | This notebook does not create access contracts — run [Challenge 3](challenge-03.md) first. |
| `Key Vault unreachable … using APIM credentials instead` | Expected in this environment, and not an error. The lab tenant enforces an Azure Policy that disables public network access on every Key Vault, so the Sales agent cannot read its secrets from the vault data plane. Challenge 3 still writes those secrets successfully, because that goes through the ARM control plane. The agent falls back to the same endpoint and contract subscription key read from APIM, so the run continues normally. |
| Foundry SDK connection step fails | Confirm the Foundry connection name printed at the end of Challenge 3 (`4️⃣.2`) matches what this notebook resolves. |
| Package install errors in step `4️⃣` | Some agent framework packages (`agent-framework`, `langchain`, `langchain-openai`) pin specific versions — re-run the cell after resolving any dependency conflict shown in the error. |

## 🚀 Go further

- Swap the LangChain Support-Bot's target model and compare its token efficiency against
  the other two frameworks.

## 📚 Learning resources

- [Microsoft Agent Framework overview](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview)
- [Microsoft Foundry Agent Service](https://learn.microsoft.com/azure/ai-foundry/agents/overview)
