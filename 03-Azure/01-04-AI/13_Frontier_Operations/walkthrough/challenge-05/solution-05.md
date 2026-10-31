# Challenge 5 solution: Work in a portal that has no API

**[← Previous Solution](../challenge-04/solution-04.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-05.md) - [Next Solution →](../challenge-06/solution-06.md)

**Duration:** 60 minutes

## Expected run

1. **Prepare.** The agent reads the workbook and lists the queries with the skill's types: for distribution, *Price dispute* for each amount mismatch, *Duplicate charge* for each duplicate, *Invoice confirmation* for missing-on-statement lines, *Copy invoice request* for missing-in-ledger lines and *Credit note confirmation* for credits. It doesn't open the browser yet.
2. **Approve.** After the approval message the agent opens `<BackOfficeUrl>/portal/new`, chooses the partner and type, fills in reference, amount and details, types the approver's name in **Approved by** and submits.
3. **Confirm.** The portal returns a reference such as `INQ-101` for Ashgrove Supply or `CHQ-101` for Kestrel Connect: the first two letters come from the company's reference prefix. The agent reports one reference per query.

In our tests one portal submission took about 80 seconds, so five queries take several minutes. The portal list and the activity page show each case with *approved by &lt;name&gt;*.

The portal refuses a submission without **Approved by** (*missing required fields*), so an agent that skips the approval step can't raise a case. That's a control in the system, not only in the prompt.

## Points to discuss

- **Prepare, approve, submit.** The approval here is a chat message. In production it would come from a workflow, an email or Teams, and the trace should show the approval before each browser step.
- **Why the browser is the riskiest tool.** Anything it submits is real, and web pages can contain text aimed at the agent. Keep it to named sites (Challenge 6 adds network rules), and always with a person in the loop.
- **When to ask for an API instead.** Browser automation is the bridge, not the destination. If a partner portal matters, ask the partner for an API and move the tool to OpenAPI later.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No **Browser Automation** option in the toolbox | Check the project has the `browser` connection (Operate, Admin, Connected resources). The lab automation creates it with the Playwright workspace. |
| The browser can't start, or *access denied* on the workspace | The project's identity needs the Playwright Workspace Contributor role on the workspace; the lab automation assigns it. Wait ten minutes after deployment. |
| The agent submits without waiting for approval | Ask it to start again and say *don't submit anything until I approve*; add the rule to the skill's **Safety** section. The portal still blocks cases without an approver. |
| The agent types a made-up approver | The portal checks the field is filled, not who it is. That's a discussion point: real approval needs identity, not a typed name. |
| A run takes very long | Each form takes about a minute. Ask for two or three queries first. |
| No **Live View** link in the steps | Open the Playwright workspace in the Azure portal (`PlaywrightWorkspaceName`) to see browser sessions. |
