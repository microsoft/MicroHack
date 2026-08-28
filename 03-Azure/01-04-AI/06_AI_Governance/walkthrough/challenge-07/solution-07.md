# Solution 07 — Build a Governed Hosted Agent with AGT

**[← Back to Challenge 7](../../challenges/challenge-07.md)** · [Home](../../README.md) · [← Solution 06](../challenge-06/solution-06.md) · [Solution 08 →](../challenge-08/solution-08.md)

Duration: 40 min

> [!NOTE]
> This is a **follow-on / optional** challenge. Teams that complete challenges 1–6
> are already successful; treat this as a stretch goal.

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/7. citadel-hosted-agent-with-agt.ipynb`](../../challenges/workshop/7.%20citadel-hosted-agent-with-agt.ipynb).
The notebook is the upstream Citadel workshop notebook (unchanged apart from its
setup cell, which now also reads configuration from the environment) and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] The hosted agent container built and pushed via `az acr build`, and the agent deployed to your spoke Foundry project.
- [ ] The agent's managed identity received the RBAC it needs (step `5a`) and the agent responds to a basic invocation (step `6️⃣`).
- [ ] Step `6a` proves the AGT policy actually enforces governance — an SSN-disclosure or 3rd-party salary request is denied rather than answered.
- [ ] A multi-turn conversation and a streaming response both work end-to-end.
- [ ] You can find `agt.audit.event` trace records in Application Insights for a denied request.

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
