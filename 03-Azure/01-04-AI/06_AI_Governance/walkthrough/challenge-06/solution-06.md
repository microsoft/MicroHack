# Solution 06 — Unified AI API Across Providers

**[← Back to Challenge 6](../../challenges/challenge-06.md)** · [Home](../../README.md) · [← Solution 05](../challenge-05/solution-05.md) · [Solution 07 →](../challenge-07/solution-07.md)

Duration: 35 min

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/6. citadel-unified-ai-api-tests.ipynb`](../../challenges/workshop/6.%20citadel-unified-ai-api-tests.ipynb).
The notebook is the upstream Citadel workshop notebook (unchanged apart from its
setup cell, which now also reads configuration from the environment) and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] An access contract deployed successfully and model/deployment discovery lists your models, with a `404` for a non-existent deployment.
- [ ] `POST /unified-ai/openai/deployments/{model}/chat/completions` (Azure OpenAI pattern) and `POST /unified-ai/models/chat/completions` (Foundry inference pattern) both return `200`.
- [ ] A missing API key returns `401`; an invalid API key also returns `401`.
- [ ] A request to an unrecognized path returns `403 PathNotAllowed`, and a request for a model outside `allowedModels` is rejected.
- [ ] The load test shows a mix of `200`/`429` responses, and every `UAIG-*` debug header is present and populated on responses.
- [ ] A streaming request (`stream: true`) returns a `200` SSE response with `UAIG-Is-Streaming: true`.

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
