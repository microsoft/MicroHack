# Solution 01 — Onboard a New LLM Backend

**[← Back to Challenge 1](../../challenges/challenge-01.md)** · [Home](../../README.md) · [Solution 02 →](../challenge-02/solution-02.md)

Duration: 35 min

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/1. llm-backend-onboarding-runner.ipynb`](../../challenges/workshop/1.%20llm-backend-onboarding-runner.ipynb).
The notebook is the **unmodified upstream Citadel workshop notebook** and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] The notebook generated a `.bicepparam` file describing your backend, auth type, and per-model metadata.
- [ ] The LLM backend onboarding Bicep deployment succeeded and the backend pool + `get-available-models` policy fragment are visible in APIM.
- [ ] `GET /deployments` (Foundry integration) returns your onboarded model.
- [ ] The deployed model responds successfully via the Universal LLM API, the Azure OpenAI API, the Azure OpenAI Python SDK, and a streaming request.

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
