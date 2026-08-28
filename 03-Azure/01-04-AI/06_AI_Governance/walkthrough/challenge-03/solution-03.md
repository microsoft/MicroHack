# Solution 03 — Access Contracts: Model RBAC & Capacity

**[← Back to Challenge 3](../../challenges/challenge-03.md)** · [Home](../../README.md) · [← Solution 02](../challenge-02/solution-02.md) · [Solution 04 →](../challenge-04/solution-04.md)

Duration: 35 min

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/3. citadel-access-contracts-tests.ipynb`](../../challenges/workshop/3.%20citadel-access-contracts-tests.ipynb).
The notebook is the upstream Citadel workshop notebook (unchanged apart from its
setup cell, which now also reads configuration from the environment) and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] All three access contracts (APIM products + subscriptions) deployed successfully via Bicep, each with its own dynamically generated product policy.
- [ ] Requests against each contract respect its `allowedModels` RBAC list.
- [ ] The load test shows throttling behaviour consistent with each contract's `llm-token-limit` capacity allocation.
- [ ] The Foundry connection name(s) for HR-ChatAgent were printed and noted for Challenge 4.

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
