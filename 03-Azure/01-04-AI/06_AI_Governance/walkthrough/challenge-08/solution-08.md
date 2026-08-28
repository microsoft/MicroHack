# Solution 08 — Publish a Foundry Agent as an A2A Endpoint

**[← Back to Challenge 8](../../challenges/challenge-08.md)** · [Home](../../README.md) · [← Solution 07](../challenge-07/solution-07.md) · [Solution 09 →](../challenge-09/solution-09.md)

Duration: 35 min

> [!NOTE]
> This is a **follow-on / optional** challenge. Teams that complete challenges 1–6
> are already successful; treat this as a stretch goal.

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/8. publish-and-use-a2a-endpoint.ipynb`](../../challenges/workshop/8.%20publish-and-use-a2a-endpoint.ipynb).
The notebook is the upstream Citadel workshop notebook (unchanged apart from its
setup cell, which now also reads configuration from the environment) and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] The HR prompt agent was created on `gpt-4.1` and its A2A endpoint was enabled, with the `v1.0` agent card verified (step 8).
- [ ] Public network access on the Foundry account was re-disabled (step 9) **before** publishing through APIM.
- [ ] An APIM API, product, and subscription were created (steps `10.1`–`10.4`) fronting the agent's A2A JSON-RPC runtime URL.
- [ ] Both calls in step 11 (agent card `GET` and JSON-RPC `message/send` `POST`) succeed through APIM using only the subscription key — with the Foundry account still privately-networked.

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
