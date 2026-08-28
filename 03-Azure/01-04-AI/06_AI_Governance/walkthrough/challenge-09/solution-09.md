# Solution 09 — HR MCP via APIM (Optional / Instructor-Led)

**[← Back to Challenge 9](../../challenges/challenge-09.md)** · [Home](../../README.md) · [← Solution 08](../challenge-08/solution-08.md) · [Finish →](../../challenges/finish.md)

Duration: variable

> [!NOTE]
> This is a **follow-on / optional** challenge. Teams that complete challenges 1–6
> are already successful; treat this as a stretch goal.

> [!IMPORTANT]
> **Coach-facing spoiler content.** Do not share this folder with participants before they
> have attempted the challenge.

## Reference notebook

This challenge is driven by
[`challenges/workshop/9. publish-and-use-hr-mcp-via-apim.ipynb`](../../challenges/workshop/9.%20publish-and-use-hr-mcp-via-apim.ipynb).
The notebook is the upstream Citadel workshop notebook (unchanged apart from its
setup cell, which now also reads configuration from the environment) and is the
authoritative solution — it contains the working code, the expected output, and its own
`📊 Results Summary` cell.

Participants must first bridge the lab-dashboard credentials into a local azd environment
with [`labautomation/setup-notebook-env.ps1`](../../labautomation/setup-notebook-env.ps1),
because the notebook reads its configuration via `azd env get-value`. See
[labautomation/README.md → Notebook Environment Setup](../../labautomation/README.md#notebook-environment-setup).

## Expected end state

- [ ] You can explain, from section `2️⃣`'s output, which `HR_MCP_*` values are missing and why (the HR MCP backend + Entra app role aren't part of this lab's automation).
- [ ] A delegated token was acquired without ever being printed (step `3️⃣`), and the APIM access contract was created or validated (step `4️⃣`).
- [ ] MCP `initialize`, `tools/list`, and both a read and a write tool call succeed through APIM only (step `7️⃣`).
- [ ] The 6th rapid `tools/call` request within 30 seconds returns `429` (step `8️⃣`).
- [ ] The hosted agent from step `🔟` calls HR MCP tools through APIM using its own managed identity, a fresh Entra token, and the APIM subscription key — not a participant token.

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
