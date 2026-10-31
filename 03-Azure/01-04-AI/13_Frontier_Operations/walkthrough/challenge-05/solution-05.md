# Challenge 5 solution: Work in a portal that has no API

**[← Previous Solution](../challenge-04/solution-04.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-05.md) - [Next Solution →](../challenge-06/solution-06.md)

**Duration:** 60 minutes

## Expected run

1. **Prepare.** The agent reads the workbook and lists the queries with the skill's types: for distribution, *Price dispute* for each amount mismatch, *Duplicate charge* for each duplicate, *Invoice confirmation* for missing-on-statement lines, *Copy invoice request* for missing-in-ledger lines and *Credit note confirmation* for credits. It doesn't open the browser yet.
2. **Approve.** After the approval message the agent opens `<BackOfficeUrl>/portal/new`, chooses the partner and type, fills in reference, amount and details, types the approver's name in **Approved by** and submits.
3. **Confirm.** The portal returns a reference such as `INQ-101` for Ashgrove Supply or `CHQ-101` for Kestrel Connect: the first two letters come from the company's reference prefix. The agent reports one reference per query.

In our tests one portal submission took about 80 seconds through the API. In the guided portal run, three queries took **510 seconds and 1.26M tokens**: every browser step (snapshot, click, type, wait) goes back to the model, and one `browser_select_option` on the supplier dropdown timed out after 60 seconds. The agent recovered, but filed one query (INQ-106, INV-41002) under **Kellerman Hygiene** instead of Brightwell Packaging, and reported it as done. Use this in the debrief: the portal list is the evidence, not the agent's report. Asking the agent to snapshot and check every field before submitting is part of the approval prompt for this reason. With that check, two further queries (Osric Office Supplies INV-41029, Tamsin Workwear INV-41054) were both filed correctly in **167 seconds**, and the agent reported the supplier shown on each confirmation page.

The portal refuses a submission without **Approved by** (*missing required fields*), so an agent that skips the approval step can't raise a case. That's a control in the system, not only in the prompt.

## Points to discuss

- **Prepare, approve, submit.** The approval here is a chat message. In production it would come from a workflow, an email or Teams, and the trace should show the approval before each browser step.
- **Why the browser is the riskiest tool.** Anything it submits is real, and web pages can contain text aimed at the agent. Keep it to named sites (Challenge 6 adds network rules), and always with a person in the loop.
- **When to ask for an API instead.** Browser automation is the bridge, not the destination. If a partner portal matters, ask the partner for an API and move the tool to OpenAPI later.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The agent has no browser tool after adding Browser Automation to the toolbox | Saving the toolbox creates a new version; the agent stays on the old one. On the agent, **⋯** next to `ops-tools`, **Switch version**, **Version 2**, then save. Adding the toolbox again doesn't change the version. |
| No **Browser Automation** option in the toolbox | Check the project has the `browser` connection (Manage, Project details, Connected resources). The lab automation creates it with the Playwright workspace. |
| The browser can't start, or *access denied* on the workspace | The project's identity needs the Playwright Workspace Contributor role on the workspace; the lab automation assigns it. Wait ten minutes after deployment. |
| The agent submits without waiting for approval | Ask it to start again and say *don't submit anything until I approve*; add the rule to the skill's **Safety** section. The portal still blocks cases without an approver. |
| The agent types a made-up approver | The portal checks the field is filled, not who it is. That's a discussion point: real approval needs identity, not a typed name. |
| A query is filed under the wrong partner, though the agent reported it as done | A dropdown step timed out or landed on the wrong option and the agent didn't look again. Put the check in the approval (*take a snapshot and check every field before you submit*), and always compare the portal list with the approval. To correct it, raise the query again under the right partner; the portal keeps the wrong one, like a real system would, so note it for the partner. |
| `browser_select_option` takes 60 seconds and fails | The managed browser sometimes times out on a dropdown. The agent usually retries with a click instead; let it. If a whole run stalls, ask for one query at a time. |
| Browser sessions show as **Active** long after the agent answered, and billable time is far longer than the run | The browser stays open until the agent closes it or it times out. Add *When you have finished in a web page, close the browser.* to the instructions (Part D). In our lab, one- to two-minute runs were billed 15 to 31 minutes each before that. |
| A run takes very long | Each form takes about a minute. Ask for two or three queries first. |
| Participants look for a live view of the browser | There isn't one for harness agents in this preview. The Playwright workspace's **Browser activity log** lists every session with its billable time and the agent that opened it (Part D). |
