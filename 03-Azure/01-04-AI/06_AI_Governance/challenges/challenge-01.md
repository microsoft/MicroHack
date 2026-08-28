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
confirm your attendee credentials are available to the notebooks (see Part A below);
every workshop notebook reads its configuration from the environment, falling back to
`azd env get-value`.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (5 min)

Every notebook in this MicroHack reads its settings from the environment, so do this
once and it applies to all nine challenges. Pick **either** route:

**Route 1 — `.env` file (recommended, no extra tooling):**

1. From the `challenges/workshop/` folder, copy the template:

   ```bash
   cd challenges/workshop
   cp .env.template .env
   ```

2. Open `.env` and paste in the matching `HackboxCredential` values from your MicroHack
   dashboard. The template names the exact dashboard credential for every key.
   For challenges 1-6 you only need `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`,
   `AZURE_SUBSCRIPTION_ID` and `LLM_BACKEND_CONFIG`.
3. Paste `LLM_BACKEND_CONFIG` as a **single line**, exactly as the dashboard shows it —
   it's a JSON document, so a stray line break will break it.

`.env` is gitignored, so your credentials stay out of source control.

**Route 2 — `azd` bridge (the original workshop workflow):**

1. Install `azd`, then run
   [`setup-notebook-env.ps1`](../labautomation/README.md#notebook-environment-setup)
   with your dashboard's `HackboxCredential` values. It writes a local `azd`
   environment that the notebooks fall back to for any key not already set.

> [!TIP]
> To confirm you're ready, run the first setup cell of notebook 1. It prints your
> resource group, location, and the number of configured LLM backends. If it raises
> instead, the message tells you which key is missing and whether a `.env` was found.

### Part B — Run the LLM backend onboarding notebook (30 min)

1. Open
   `workshop/1. llm-backend-onboarding-runner.ipynb`
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
| Setup cell raises a missing-key error | That key isn't in your `.env` (and no `azd` environment supplied it) — see Part A. The error message tells you which key is missing and whether a `.env` file was found. |
| `LLM_BACKEND_CONFIG` fails to parse | It must be on a single line, pasted exactly as the dashboard shows it. A line break or a truncated copy will break the JSON. |
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
