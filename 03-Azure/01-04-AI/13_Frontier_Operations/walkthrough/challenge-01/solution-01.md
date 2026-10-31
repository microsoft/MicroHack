# Challenge 1 solution: Your first agent that does the work

**[Home](../../README.md)** - [Challenge](../../challenges/challenge-01.md) - [Next Solution →](../challenge-02/solution-02.md)

**Duration:** 45 minutes

## What good looks like

- `python3 -m frontierops ... setup` prints the company, its five partners, *Portal check: OK* and the files in `my-files`, including `ledger-export.csv` and `skills/reconciliation/SKILL.md`.
- `ops-agent` shows **Microsoft Copilot harness** in its details. The harness can only be chosen when the agent is created; if a team forgot, they create a new agent.
- With only a statement attached, the agent says it needs the ledger and doesn't invent numbers.
- With both files, the steps show `view` (reading the files), one or more `shell_call` steps running Python, and `upload_file_from_workspace_to_foundry_project`. The answer has a downloadable `reconciliation.xlsx`.

Our run (distribution, Brightwell Packaging, `gpt-5.4-mini`): **56 seconds, 222,069 tokens**. The agent found `openpyxl` missing, switched to another way of writing the workbook, fixed a column-name mismatch on its own and returned a workbook with four sheets: *Exact matches*, *Amount differences*, *Missing in statement* and *Missing in ledger*. Self-correction like this is the harness at work; point it out to participants.

Without a skill the agent uses its own judgement. That is the point of Challenge 2: expect it to list the within-tolerance line as a mismatch, and to call the duplicate and the credit note "statement only". The exact lines per partner are in [expected results](../expected-results.md).

## Points to discuss

- **What the harness adds.** A prompt agent answers; a harness agent works. It has a workspace (`/home/session/workspace`), a shell and Python, and the same agent loop as GitHub Copilot, run by Microsoft. Ask a business participant what they'd hand it first.
- **Rules are code.** Matching references and applying a tolerance are rules, so the agent writes and runs code for them. The answer is the same every time and can be checked.
- **The agent's own identity.** Returning a file uses the agent's identity, not the participant's. That's why `grant-agent` exists, and it's the first glimpse of the identity story in Challenge 6.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| *Timeout waiting for token from portal* (Audience `https://graph.microsoft.com/` or `https://ai.azure.com`) | Cloud Shell's automatic sign-in only covers Azure resources. Run `az login --use-device-code` in Cloud Shell once (Part B, step 3) and run the command again. Setup works without it; `publish-skill` needs it. If device-code sign-in is blocked in your tenant, use `grant-agent ops-agent --identity <ID>` with the identity copied from the agent's **Details** tab: that needs only Azure Resource Manager. |
| `grant-agent` can't find the agent's identity | It reads the identity from Foundry first and doesn't need directory access. If that fails, it tries Microsoft Entra by name, which lab accounts may not be allowed to read. Use `--identity` with the ID from the agent's **Details** tab. |
| *Foundry Files access denied* when the agent tries to return the workbook | The agent's identity has no Foundry User role yet, or the chat started before the grant. Run `grant-agent`, wait five minutes and start a **new chat**: the grant only reaches chats started after it. In our tests a chat started before the grant kept failing for hours. |
| `grant-agent` says the agent has no identity yet | The agent wasn't saved. Select **Save** in the portal and run it again. |
| `grant-agent` fails with *AuthorizationFailed* | The participant isn't using their lab account in Cloud Shell, or the lab was deployed less than ten minutes ago. Their lab account may assign only Foundry User on their own project. |
| The setup *Portal check* says it couldn't reach the portal | The Functions app is cold-starting. Open `BackOfficeUrl` in a browser and run setup again. |
| The agent says it can't open `.xlsx` or Excel libraries are missing | It switches to another library or writes the workbook with plain XML; let it work. If it insists, ask for a CSV instead. |
| The upload button in the chat is missing | Make sure the agent was created with the harness; file inputs need it. |
