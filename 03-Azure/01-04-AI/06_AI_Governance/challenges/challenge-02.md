# Challenge 2 — Universal LLM API Across Every Model

**[Home](../README.md)** - [← Previous Challenge](challenge-01.md) - [Next Challenge →](challenge-03.md)

## 🎯 Objective

Validate the **Universal LLM API** (`/models`) against **every model** exposed by the
gateway: provision an access contract with `allowedModels = ""` (no model restriction),
dynamically discover the live model catalogue via `GET /models/models`, and exercise the
right operation for each model (chat completions, embeddings, or the Responses API trio).

## 🧭 Context

This challenge deploys its own **Access Contract** (an APIM product + subscription) via
Bicep — a dynamically generated product policy with no model RBAC restriction and a
generous capacity allocation. Make sure your notebook configuration is already
in place (see [Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min))
before you start.

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

Same prerequisite as every notebook in this MicroHack: confirm your attendee
credentials are in `challenges/workshop/.env` (or bridged via `azd`) — see
[Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min).

### Part B — Run the Universal LLM API validation notebook (25 min)

1. Open
   `workshop/2. citadel-universal-llm-api-all-models-tests.ipynb`
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Provision Access Contract (allowedModels = "")`
   - `4️⃣ Retrieve API Key from Access Contract`
   - `5️⃣ Discover All Models via Universal LLM API`
   - `6️⃣ Classify Models and Plan Operations`
   - `7️⃣ Execute Per-Model Operations`
   - `8️⃣ Confirm allowedModels = "" Behaviour`
3. Read the `📊 Results Summary` cell, then run `🧹 Cleanup (Optional)` if you want to
   remove the test access contract afterward.

## 🏁 Success criteria

- [ ] An access contract (APIM product + subscription) with `allowedModels = ""` deployed
      successfully via Bicep.
- [ ] `GET /models/models` returned the live catalogue of models the gateway serves.
- [ ] Every discovered model was classified correctly (embedding vs. `gpt`-style vs.
      other) and exercised the matching operation — `POST /models/embeddings`,
      `POST /models/chat/completions`, or the Responses API trio
      (`/models/responses`, `GET /models/responses/{id}`,
      `GET /models/responses/{id}/input_items`).
- [ ] The final per-model results table shows no unexpected failures, confirming
      `allowedModels = ""` does not block any model.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| Setup cell raises a missing-key error | Your `challenges/workshop/.env` is missing that key (or you haven't run the `azd` bridge) — see [Challenge 1, Part A](challenge-01.md#part-a--confirm-your-notebook-environment-is-ready-5-min). |
| A model in the catalogue fails every operation | Check whether that backend was onboarded in [Challenge 1](challenge-01.md) or is otherwise disabled in APIM. |
| Responses API calls fail for a `gpt` model | Some models don't implement the Responses API trio — the notebook's classification is a heuristic based on the model name, not a guarantee. |

## 🚀 Go further

- Re-run section `3️⃣` with a restricted `allowedModels` list instead of `""` and observe
  which models section `7️⃣` now skips or rejects.

## 📚 Learning resources

- [Azure OpenAI Responses API](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/responses)
- [Azure API Management products and subscriptions](https://learn.microsoft.com/azure/api-management/api-management-howto-add-products)
