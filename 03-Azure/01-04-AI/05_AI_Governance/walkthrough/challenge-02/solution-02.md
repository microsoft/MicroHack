# Solution 02 — Universal LLM API Across Every Model

**[← Back to Challenge 2](../../challenges/challenge-02.md)** · [Home](../../README.md) · [← Solution 01](../challenge-01/solution-01.md) · [Solution 03 →](../challenge-03/solution-03.md)

Duration: 25 min

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/2. citadel-universal-llm-api-all-models-tests.ipynb`](../../challenges/workshop/2.%20citadel-universal-llm-api-all-models-tests.ipynb).
The notebook is the **unmodified upstream Citadel workshop notebook** and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] An access contract (APIM product + subscription) with `allowedModels = ""` deployed successfully via Bicep.
- [ ] `GET /models/models` returned the live catalogue of models the gateway serves.
- [ ] Every discovered model was classified correctly (embedding vs. `gpt`-style vs. other) and exercised the matching operation — `POST /models/embeddings`, `POST /models/chat/completions`, or the Responses API trio (`/models/responses`, `GET /models/responses/{id}`, `GET /models/responses/{id}/input_items`).
- [ ] The final per-model results table shows no unexpected failures, confirming `allowedModels = ""` does not block any model.

## 🛠️ Task-by-task walkthrough

<!-- TODO(author): Narrate the solution here.
     Suggested structure, mirroring the sibling labs:
       ### Task 1 · <what the participant does>
       - the exact cells/commands to run
       - the output that proves it worked
       - why it matters for AI governance
     Keep the notebook as the source of truth; this file explains and de-risks it. -->

_Walkthrough narrative to be written._

## 🧭 Coaching notes

<!-- TODO(author): Fill in from dry-run experience. -->

- **Common failure:** _TBD_
- **Where teams get stuck:** _TBD_
- **Good question to ask the room:** _TBD_

## ✅ How to verify

<!-- TODO(author): The concrete check a coach runs to confirm the team is done. -->

_Verification steps to be written._
