# Day-of card

Print this page. It is the facilitator's checklist while the room is full. Preparation is in
[the facilitator guide](Facilitator.md); cost detail is in [the cost estimate](CostEstimate.md).

## Before 09:00: go/no-go

| Check | Green looks like |
| --- | --- |
| Participant map ready | Each person has `rg-userNNN`, Azure sign-in, VM names, and GitHub repo URL. |
| VMs healthy | Spot-check `C:\MicroHack\status\dotnet-smoke.json` and `java-smoke.json`. |
| JIT works | You can request Just-in-Time RDP and connect to one VM per region. |
| GitHub works | One test push from a provisioned VM succeeded. |
| Copilot works | A participant-like account can use Copilot Chat in VS Code. |
| Budget live | Alerts go to a named human. |
| Paid services approved | Defender and SRE Agent are either approved and ready, or explicitly out of scope. |

## Timetable

| Time | Block | Facilitator move |
| --- | --- | --- |
| 09:00 d1 | Opening demo + orientation | Show the legacy VM and target shape. Say: "Pick one stack and keep it." |
| 09:30 d1 | ch00 | Help with JIT and RDP. Keep it to the before-state tour. |
| 10:45 d1 | ch01 block 1 | Explain the two paths. Split tables so people can compare. |
| 13:15 d1 | ch01 block 2 | Walk the room: database, Dockerfile, Bicep, ACR, Container Apps, images. |
| 15:15 d1 | ch01 debrief | Compare approaches, not scores. Both paths target the same architecture. |
| 15:45 d1 | ch02 | Start load tests and watch Container Apps replicas plus database metrics. |
| 09:00 d2 | Kickoff | Make sure every team has a working Container App URL. |
| 09:15 d2 | ch03 | Watch for GitHub environment approval and OIDC identity setup. |
| 11:30 d2 | ch04 | Get traces flowing; restart the revision if collector settings changed. |
| 13:30 d2 | ch05-defender | Participants inspect posture; facilitators own paid plan changes. |
| 15:15 d2 | ch06-sre-agent | Use Review mode. Only an SRE Agent Administrator approves writes. |
| 16:15 d2 | Wrap-up | Do not cut this. Ask what they would change first at work. |

## Challenge 1 path message

Say this at 10:45:

> Challenge 1 has two paths. Path A modernizes the app you have. Path B rewrites from a
> Copilot-generated PRD and plan. Both end on Azure Container Apps with a managed database,
> ACR, Azure storage for images, and Bicep you author. If your table has several people,
> split the paths so you can compare what was easier, riskier, and more reviewable.

No preference? Steer them to Path A; it is closer to most real modernization backlogs.

## Fast health checks

```powershell
Get-Content C:\MicroHack\status\dotnet-smoke.json
Get-Content C:\MicroHack\status\java-smoke.json
type C:\MicroHack\source\.source-commit
```

If RDP fails, request JIT again with **My IP** before changing anything. If Azure CLI run
commands hang, check for a pending named run-command as described in
[Clean up after yourself on a participant VM](Facilitator.md#clean-up-after-yourself-on-a-participant-vm).

## Common saves

- ch01 database connection weirdness: check environment variables first.
- ch01 image missing: check Azure Files mount path or image base URL.
- ch01 build confusion: the VM has no Docker daemon; use `az acr build`.
- ch02 no scale-out: check Container Apps max replicas and HTTP concurrency rule.
- ch03 no approval prompt: GitHub plan/repo visibility may not support environment protection.
- ch04 no traces: generate traffic, wait a few minutes, restart the revision if needed.
- ch05 empty Defender blades: findings are asynchronous; discuss what each plan can see.
- ch06 overrun: switch to facilitator-led investigation.

## What to cut

1. Drop optional ch07 first.
2. Make ch06 facilitator-led for large cohorts.
3. Timebox ch05 and ch04; demo the portal flow if needed.
4. Never cut ch02 entirely and never cut the wrap-up.

## Closing line

Say the teardown date out loud: what will be deleted, when, and who owns it.
