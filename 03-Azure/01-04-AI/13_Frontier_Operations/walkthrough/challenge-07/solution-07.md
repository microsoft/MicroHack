# Challenge 7 solution: Prove it before you scale it

**[← Previous Solution](../challenge-06/solution-06.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-07.md) - [Next Solution →](../finish/solution-finish.md)

**Duration:** 40 minutes

## Our measurements

Guided portal run, distribution pack, Brightwell Packaging, the same agent definition (skill v6, ERP toolbox, egress guardrail) on each model:

| Measure | `ops-agent`, `gpt-5.4-mini` | `ops-agent-54`, `gpt-5.4` |
|---|---|---|
| Time from request to answer | 46 s | 76 s |
| Score | 6 of 6 | 6 of 6 |
| Tokens | 189,488 | 169,072 |
| What it did | Wrote the workbook (installed no library; wrote the .xlsx itself) | Also read the ERP and wrote three ledger notes |

Both models were equally accurate. The bigger model used about 10% fewer tokens but took longer and costs more per token; the smaller one is the better choice here. An API run of the mini agent with the same request took 69 s and 253K tokens: expect this much variation between runs.

The `gpt-5.4` copy also read the ERP and wrote three ledger notes on its own, because the instructions say the ERP is the system of record. That's the same behaviour as `ops-agent`, and a reminder that you compare **agents**, not models in isolation.

Earlier API runs (before the ERP and guardrail were added), for the scale of a full month:

| Measure | One partner, `gpt-5.4-mini` | One partner, `gpt-5.4` | Five partners, `gpt-5.4-mini` |
|---|---|---|---|
| Time from request to answer | 85 s | 110 s | 3 min 39 s |
| Score | 6 of 6 | 6 of 6 | 30 of 30 |
| Input tokens (cached) | 195,118 (176,640) | 120,476 (92,928) | 944,757 (622,592) |
| Output tokens (reasoning) | 11,387 (7,620) | 6,702 (2,883) | 41,999 (26,202) |

Runs vary: expect differences of 20 to 30% in time and tokens between two identical requests. Teams should look at the pattern, not one number.

What it shows:

- **With a good skill, the smaller model is as accurate** on this process. The skill carries the method, so the model doesn't need to work it out.
- **The bigger model used fewer tokens** and less reasoning, but each token costs more and it was slower here. Which is cheaper depends on the current prices: let teams do the sum with today's price list.
- **Most input is cached.** Files and the skill are read again by each step and each subagent; cached input is billed at a fraction of the normal price.
- Five partners on `gpt-5.4` failed twice in our lab with a server error after about four minutes, and in the portal even one partner failed with *Model deployment rate limit exceeded* while `gpt-5.4` had 50K tokens per minute. The lab now deploys it with 150K. That's why the challenge compares one partner, and it's a useful lesson: **quota is part of the design.**

## The business case, worked

With the challenge's assumptions: 4 people × 3 days × 400 pounds = **4,800 pounds a month** today. With the agent, the month's run costs a few pounds or less in tokens (do the sum with current prices), plus the harness from December 2026, plus a person's review: say half a day for the reviewer and an hour for the approver, about **250 pounds**. Even if the agent's run cost were ten times higher, the saving is people's time, and the real gain is speed: queries raised within a day of month-end, inside every partner's dispute window.

A good five sentences name the saving, the model choice and why, the control that stays with people, the pilot and what will be measured.

## Points to discuss

- **Accuracy is measured, not assumed.** The score came from an answer key. A real pilot builds its own: last month's reconciliation, checked by the expert.
- **Don't forget the person.** Review and approval are part of the cost, and the reason the process is trustworthy.
- **Prices change.** Build the case on measured tokens and time; plug in the current price list each time.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No token counts in **Traces** | Select the run, not a single step; the totals are on the run's summary. Only chats started after the Application Insights connection are traced. |
| The `gpt-5.4` run fails with a server error or rate limit | Run one partner, as the challenge says. If one partner still fails, wait a minute: someone else in the lab may be using the quota. |
| Can't change the model | Only models deployed in the project appear. Check **Build**, **Models**, **Deployments** for `gpt-5.4`. |
