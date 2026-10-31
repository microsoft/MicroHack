# Challenge 7: Prove it before you scale it

**[← Previous](challenge-06.md)** - [Home](../README.md) - [Next Challenge →](finish.md)

## 🎯 Objective

Measure what one month's run costs and how good it is, on two models, and turn the numbers into a business case your finance director would accept.

## 🧭 Why this matters for your business

A demo shows that something *can* work. A business case shows that it's **worth** it: how long a run takes, how often it's right and what it costs, compared with how the team works today. Those numbers also decide the model. A bigger model may be more accurate and slower and dearer; a smaller one may be good enough once the skill carries the method. You won't know until you measure.

## ✅ Tasks

### Part A: Your numbers so far (10 min)

Every answer in the playground shows its time and tokens on the line under it, and **Traces** keeps them for every run. Find two runs and record their numbers:

- your Challenge 2 run **with the skill** (one partner);
- your Challenge 3 run (all five partners, with subagents).

| Measure | One partner, `gpt-5.4-mini` | Five partners, `gpt-5.4-mini` |
|---|---|---|
| Time from request to answer | | |
| Score | | |
| Input tokens, of which cached | | |
| Output tokens | | |

> 📸 **Screenshot to add:** `images/challenge-07-trace-tokens.png`: The trace summary of a full run: duration and token counts.

### Part B: Run the same partner on the bigger model (15 min)

1. Open `ops-agent` and change the **model** to your `CompareModelDeploymentName` (`gpt-5.4`). Select **Save and start new chat**.
2. Attach the **same one** partner statement and ledger export as in Challenge 2, and send the same request.
3. Score the workbook, and record the same measures from **Traces** in a new column.
4. Change the model back to `ModelDeploymentName` (`gpt-5.4-mini`) and save.

Why one partner? The bigger model has a smaller quota in your lab, and a five-partner run reads about a million tokens in a few minutes. Comparing one partner is fair to both models; you scale the result up in Part C.

### Part C: Cost per run (10 min)

1. Open the [Azure OpenAI pricing page](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/) and find the **Global** prices per million tokens for both models: input, cached input and output.
2. Work out the model cost of one partner on each model:

   *(uncached input × input price + cached input × cached price + output × output price) ÷ 1,000,000*

   Then the cost of the month: your five-partner run for `gpt-5.4-mini`, and roughly five times the one-partner cost for `gpt-5.4`.

3. Add the harness: while the Copilot harness is in preview it's free until 1 December 2026; after that its workspace is billed per vCPU-hour and GiB-hour while a session runs. A run of a few minutes is a small share of an hour.
4. Add the browser if the run used it: Browser Automation is billed per minute of browser session on your Playwright workspace, and a session stays open until the agent closes it or it times out (Challenge 5, Part D). Take the billable time from the workspace's **Browser activity log**, and the price from the [Playwright Workspaces pricing page](https://azure.microsoft.com/pricing/details/app-testing/).

### Part D: The business case (10 min)

Use your company's numbers or these, and change anything you disagree with:

| Today | Value |
|---|---|
| People on the month-end reconciliation | 4 |
| Days each, every month | 3 |
| Cost of a person-day | 400 pounds |
| Queries raised late, after the partner's dispute window | 1 in 10 |

1. What does one month cost today, and what would it cost with the agent? Keep a person in the loop: who reviews the workbook and approves the queries, and for how long?
2. Which model would you choose, and why? Is the difference in score worth the difference in cost and time?
3. What would you measure in the first three months of a pilot to know it worked?

Write it as five sentences you could send to your finance director.

## ✔️ Success criteria

- [ ] You measured time, score and tokens for a full run on two models.
- [ ] You worked out the cost of one run, and know which parts of the price are tokens, harness and browser.
- [ ] You chose a model with a reason you can defend.
- [ ] You wrote a short business case in your own words.

## 📚 Learning resources

- [Azure OpenAI pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- [Copilot harness limits, quotas and regions](https://learn.microsoft.com/azure/foundry/agents/concepts/limits-quotas-regions#microsoft-copilot-harness-preview)
- [Evaluate your agents](https://learn.microsoft.com/azure/foundry/observability/how-to/evaluate-agent)

[Coach solution and expected answers](../walkthrough/challenge-07/solution-07.md)
