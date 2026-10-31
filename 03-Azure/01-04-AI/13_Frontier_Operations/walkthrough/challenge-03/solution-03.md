# Challenge 3 solution: All partners at once with subagents

**[← Previous Solution](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-03.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 40 minutes

## Expected run

Our guided run in the portal (distribution, `gpt-5.4-mini`, with the skill): **91 seconds, 698,295 tokens**, steps `skill`, `view`, `task`, `shell_call`, `read_agent` and the upload. The answer line lists each kind of step once; the trace shows each of the five `task` calls.

Our API runs on the distribution pack, all five partners, `gpt-5.4-mini`, one request:

| | Without the skill | With the skill |
|---|---|---|
| Time from request to answer | 4 min 25 s | 3 min 39 s |
| Subagents (`task` calls) | 5 | 5 |
| Input tokens (cached) | 1,075,809 (857,600) | 944,757 (622,592) |
| Output tokens (reasoning) | 61,447 (41,853) | 41,999 (26,202) |
| Score | 15 of 30 | **30 of 30** |

The steps, in order: `view` on the files, **skill** (`reconciliation`), five **task** calls (one per partner), the lead's own `shell` work while it waits, five **read_agent** calls, more `shell` to build the workbook, and the upload. The lead often cross-checks the subagents' results against its own calculation before writing the workbook.

The Summary sheet lists the five partners with their exception count and money at stake. Counts are 5 per partner with the skill (the within-tolerance line is accepted), 6 without it. How "money at stake" is calculated varies between runs (absolute differences, or totals of missing amounts); ask the team to say which one their approver would want and to put it in the skill's **What we hand over** section.

## Points to discuss

- **Why it's not five times faster.** Each subagent reads the files and the skill itself, and the lead waits for the slowest one, then checks and merges. Parallel work saves the most when the pieces are large.
- **Tokens.** Most input tokens are **cached**: the same files and skill read again by each helper. Cached input is much cheaper, which is why the cost in Challenge 7 is lower than the raw token count suggests.
- **When not to.** One partner with a subagent costs more and takes longer than doing it directly. A good rule: split when the pieces are independent, similar in size and each worth more than a minute of work.
- **The skill travels.** Every subagent applies the same method because the skill is loaded for them too. Without it, five helpers can make five different judgement calls.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No **task** steps | The agent decided to do it alone. Check that **Subagents** is on under **Harness tools**, and that the request says *one subagent per partner*. |
| The run takes more than ten minutes or stops with a server error | Usually the model's rate limit: a full run reads about a million tokens in a few minutes. Wait a minute and retry in a new chat. If it keeps failing, ask for two or three partners. |
| The workbook has one sheet with all partners | Ask again for *one sheet per partner* and a *Summary* sheet; `score` needs sheets named after partners. |
| Different counts between two runs | Agents aren't deterministic in how they present results. The **score** should be stable with the skill; if it isn't, the skill is ambiguous: find the rule the runs disagree on and make it exact. |
