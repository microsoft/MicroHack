# Challenge 6 — Unified AI API Across Providers

**[Home](../README.md)** - [← Previous Challenge](challenge-05.md) - [Next Challenge →](challenge-07.md)

## 🎯 Objective

Validate the **Unified AI Wildcard API** (`/unified-ai`) across different model
providers and API patterns: Azure OpenAI, Foundry inference, the Responses API, and
Gemini's OpenAI-compatible surface — plus authentication modes, load testing, debug
headers, blocked-path rejection, model access control, and streaming.

## 🧭 Context

This notebook deploys its own access contract via Bicep to obtain API credentials, then
runs 11 test sections against the Unified AI API. It assumes an existing Citadel
Governance Hub deployment with the Unified AI API enabled — that's already part of your
lab's hub deployment. Confirm your notebook environment bridge is in place before you
start.

## ✅ Tasks

### Part A — Confirm your notebook environment is ready (2 min)

Same prerequisite as every notebook in this MicroHack — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the Unified AI API validation notebook (35 min)

1. Open
   `workshop/6. citadel-unified-ai-api-tests.ipynb`
2. Run the setup sections:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Provision Access Contract`
   - `4️⃣ Retrieve API Key from Access Contract`
   - `5️⃣ Discover Available Models & Deployment Discovery`
3. Run the 11 test sections, in order:
   - `Test 1` — Azure OpenAI pattern
   - `Test 2` — Inference pattern (Foundry models)
   - `Test 3` — Responses API pattern (if supported)
   - `Test 4` — Gemini OpenAI pattern (if configured)
   - `Test 5` — API key authentication
   - `Test 6` — Load test & throttling
   - `Test 7` — UAIG debug response headers
   - `Test 8` — Blocked path rejection
   - `Test 9` — Model access control (`allowedModels`)
   - `Test 10` — Invalid API key
   - `Test 11` — Streaming request
4. Read the `Summary` table at the end (it lists the expected result for every test),
   then run `🧹 Cleanup` if you want to remove the test access contract.

## 🏁 Success criteria

- [ ] An access contract deployed successfully and model/deployment discovery lists your
      models, with a `404` for a non-existent deployment.
- [ ] `POST /unified-ai/openai/deployments/{model}/chat/completions` (Azure OpenAI
      pattern) and `POST /unified-ai/models/chat/completions` (Foundry inference
      pattern) both return `200`.
- [ ] A missing API key returns `401`; an invalid API key also returns `401`.
- [ ] A request to an unrecognized path returns `403 PathNotAllowed`, and a request for
      a model outside `allowedModels` is rejected.
- [ ] The load test shows a mix of `200`/`429` responses, and every `UAIG-*` debug
      header is present and populated on responses.
- [ ] A streaming request (`stream: true`) returns a `200` SSE response with
      `UAIG-Is-Streaming: true`.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `azd env get-value` errors | `setup-notebook-env.ps1` hasn't been run — see Part A. |
| Test 3 (Responses API) or Test 4 (Gemini) show as skipped | These are conditional on your onboarded backends supporting that pattern — not every lab environment configures a Gemini backend. |
| Load test (Test 6) shows only `200`s, no `429`s | Capacity limits are per-contract; the load may not be high enough to trip the token bucket — increase the burst size in that cell. |

## 🚀 Go further

- Compare the `UAIG-*` debug headers returned for the Azure OpenAI pattern vs. the
  Foundry inference pattern and note what differs.

## 📚 Learning resources

- [Azure API Management — Unified AI Gateway design pattern](https://techcommunity.microsoft.com/blog/integrationsonazureblog/azure-api-management---unified-ai-gateway-design-pattern/4495436)
- [APIM Unified AI Gateway sample](https://github.com/Azure-Samples/APIM-Unified-AI-Gateway-Sample)
