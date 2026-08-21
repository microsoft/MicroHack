# Challenge 1 — Onboard a New LLM Backend

**[Home](../README.md)** - [Next Challenge →](challenge-02.md)

## 🎯 Objective

Use the **🏰 Citadel Backend Contracts** notebook to onboard a new AI backend and its
routing logic into the Citadel Governance Hub: configure an LLM backend endpoint and
authentication, generate the Bicep parameter file, deploy the backend pool and policy
fragments, then prove it works through multiple API formats.

## 🧭 Context

This challenge runs entirely against **Hub** resources — the APIM instance and its
backend pools sit in front of every model your governance hub serves. Before you start,
confirm your attendee credentials have been bridged into a local `azd` environment (see
Part A below); every workshop notebook reads its configuration via `azd env get-value`.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (5 min)

1. Check with your facilitator (or your own setup) that
   [`setup-notebook-env.ps1`](../labautomation/README.md#notebook-environment-setup)
   has already been run with your dashboard's `HackboxCredential` values.
2. If it hasn't, run it now — the workshop notebooks are **unchanged** and call
   `azd env get-value` for every setting, so this step is required once before any
   notebook in this MicroHack.

### Part B — Run the LLM backend onboarding notebook (30 min)

1. Open
   `../reference/ai-hub-gateway-solution-accelerator/workshop/1. llm-backend-onboarding-runner.ipynb`
   in VS Code / Jupyter.
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Extract Current APIM Backend-Pools Configuration`
   - `4️⃣ Discover Managed Identity for APIM Authentication`
   - `5️⃣ Generate LLM Backend Parameter File`
   - `6️⃣ Deploy LLM Backend Onboarding Bicep`
   - `7️⃣ Verify Deployed Configuration`
   - `8️⃣ Verify Get Available Models Policy Fragment`
3. Run the test sections: `🧪 Test GET /deployments (Microsoft Foundry Integration)` and
   `🧪 Test Deployed Models` (Universal LLM API, Azure OpenAI API, Azure OpenAI Python
   SDK, streaming).
4. Read the notebook's own `📊 Results Summary` and `Next Steps` cells at the end.

## 🏁 Success criteria

- [ ] The notebook generated a `.bicepparam` file describing your backend, auth type,
      and per-model metadata.
- [ ] The LLM backend onboarding Bicep deployment succeeded and the backend pool +
      `get-available-models` policy fragment are visible in APIM.
- [ ] `GET /deployments` (Foundry integration) returns your onboarded model.
- [ ] The deployed model responds successfully via the Universal LLM API, the Azure
      OpenAI API, the Azure OpenAI Python SDK, and a streaming request.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd env get-value` errors / empty values | `setup-notebook-env.ps1` hasn't been run for your attendee credentials yet — see Part A. |
| Backend deployment succeeds but test calls 401/403 | APIM RBAC / managed-identity propagation can take a minute after a fresh deployment — wait and retry. |
| A model call fails with a region/quota error | Model availability is region-specific; double-check the model/SKU you configured is available in your lab's region. |

## 🚀 Go further

- Add a second backend (a different `backend_type` such as `aws-bedrock` or
  `gemini-openai`) to the same `llm_backends_config` and re-run sections `5️⃣`–`8️⃣`.
- Configure a `model_alias` that routes a friendly client-facing name to more than one
  underlying model.

## 📚 Learning resources

- [Azure API Management policy reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [What is Microsoft Foundry?](https://learn.microsoft.com/azure/ai-foundry/what-is-ai-foundry)
