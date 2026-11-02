# Challenge 3: All partners at once with subagents

**[← Previous](challenge-02.md)** - [Home](../README.md) - [Next Challenge →](challenge-04.md)

## 🎯 Objective

Reconcile **every** partner in one request. Let the agent split the work into **subagents**, one per partner, and combine their results into one workbook with a summary your approver can act on.

## 🧭 Why this matters for your business

One partner is a demo; month-end is all of them. A person works through statements one after another. An agent with **subagents** works like a lead with a small team: it hands each partner to a helper with the same skill and the same files, waits for the results, checks them and writes one report.

That changes what a team can promise. The work that took days now fits in one coffee break, so it can run every week instead of every month and differences are caught while they're still small.

Subagents aren't always the answer. They pay off when the work splits into **independent** pieces of similar size. They cost more tokens, because each helper reads the files and the skill itself. You'll see both sides.

## ✅ Tasks

### Part A: Hand over the whole month (15 min)

1. Open `ops-agent` and start a **new chat**. Check that the `reconciliation` skill is still attached.
2. Attach **all five** statements and `ledger-export.csv` (the chat shows the first five files and **+1**), and ask:

   > *Reconcile every partner statement against our ledger export, one subagent per partner. Combine the results into exceptions.xlsx with one sheet per partner (reference, category, our amount, their amount, difference, action) and a Summary sheet with the number of exceptions and the money at stake per partner. Give the workbook back to me as a file.*

   ![The chat with all five statements and the ledger export attached](../images/challenge-03-attach-all.png)

3. It takes a minute or two. When the answer arrives, look at the line under it: the time it took, the tokens, and the steps. New ones appear:
   - **skill**: the lead agent loads your method.
   - **task**: the lead starts a subagent, one per partner, each with its own brief.
   - **read_agent**: the lead collects each helper's result.
   - **shell_call** and **upload_file_from_workspace_to_foundry_project**: the lead builds and returns the workbook.

   ![The answer for all five partners: 91 seconds, with skill, task, read_agent and the upload among the steps](../images/challenge-03-subagent-steps.png)

4. Compare the time with how long your team takes for the month today.

### Part B: Check the result (10 min)

1. Fetch the workbook into Cloud Shell and score it:

   ```bash
   python3 -m frontierops download
   python3 -m frontierops score ~/exceptions.xlsx
   ```

   **What this does:** the same check as in Challenge 2, now for all five partners: 30 planted lines in total.

   Don't expect a perfect score every time. In our run, four partners were perfect and one wasn't: Northgate Freight writes its references as `IN-41015` instead of `INV-41015`, and that partner's subagent didn't match them, so it reported most of the statement as missing.

   ![Cloud Shell: 26 of 30, with one partner's lines mismatched by its subagent](../images/challenge-03-score.png)

   This is why a person still checks the result. If one partner looks wrong, ask the agent in the same chat to redo just that partner, for example: *Northgate Freight writes references as IN- instead of INV-. Redo Northgate using the matching rules in your skill, update exceptions.xlsx and give it back to me.* Then download and score again. In our run the redo took 23 seconds and the score went to 30 of 30.

   ![The agent redoes one partner and returns the corrected workbook in 23 seconds](../images/challenge-03-redo-partner.png)

   ![Cloud Shell: 26 of 30 before the redo, 30 of 30 after](../images/challenge-03-score-after-redo.png)

2. Open the **Summary** sheet. Which partner has the most money at stake? That's where your approver will look first.

   ![The returned exceptions.xlsx: the Summary sheet with exceptions and money at stake per partner, and one sheet per partner](../images/challenge-03-workbook-summary.png)

3. Select **Traces** on the answer line. The header shows how much work went into the month: in our run 124 steps, 35 model calls and 40 tool calls in 92 seconds. Scroll down past the skill and the file reads to the **execute_tool task** steps, one per partner, and select one to see the brief the lead agent gave that subagent. Which partner took longest?

   ![The trace of the five-partner run: totals in the header, the skill, then the file reads before the subagent tasks](../images/challenge-03-trace.png)

   Each subagent gets a written brief, the way a lead briefs a colleague. In ours the lead copied the skill's matching rules and the GBP 2.00 tolerance into each brief, and started all five subagents within a fraction of a second, so they worked in parallel:

   ![execute_tool task selected: the brief the lead agent wrote for the Brightwell subagent](../images/challenge-03-subagent-brief.png)

### Part C: When not to use subagents (10 min)

Discuss as a team, then try one of these:

- Ask the same question with *"Do this yourself, without subagents."* in a new chat. Compare the time and the score.
- Ask for only **one** partner with *"one subagent per partner"*. Does the agent still start a helper? Is it worth it?

Write down one rule of thumb your team would use to decide.

## ✔️ Success criteria

- [ ] One request reconciled all five partners and returned one workbook with a Summary sheet.
- [ ] You saw the five subagent tasks in the steps or in **Traces**.
- [ ] You scored the result and recorded how long the whole month took.
- [ ] You can say when subagents help and when they only add cost.

## 📚 Learning resources

- [Use the Microsoft Copilot harness: harness tools and subagents](https://learn.microsoft.com/azure/foundry/agents/how-to/use-tools-skills-copilot-harness#configure-harness-tools)
- [Trace agent runs in Foundry](https://learn.microsoft.com/azure/foundry/observability/how-to/trace-agent-setup)

[Coach solution and expected answers](../walkthrough/challenge-03/solution-03.md)
