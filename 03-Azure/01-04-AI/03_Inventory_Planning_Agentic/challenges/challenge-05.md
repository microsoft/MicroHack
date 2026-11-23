# Challenge 5 — Connect the Loop (Stretch)

**[← Previous](challenge-04.md)** - [Home](../README.md) - [Next Challenge →](challenge-06.md)

> [!NOTE]
> This is an optional challenge for teams that finish early. It uses the three agents
> from Challenges 2–4. You can skip it: Challenges 1–4 are the main part of the hack.

## 🎯 Objective

Connect the three agents into one **sequential workflow**: code that always runs them
in the same order. Then the whole Sense → Plan → Approve → Act loop starts with a single
call and stops only when a person must approve. Finally, add a **"Run the whole loop"**
button to the console.

## 🧭 Context

Planners don't want to click four buttons. They want to type one sentence and let the
system run the loop. The system should stop only when it needs their approval.

## ✅ Tasks

### Part A — Read the workflow (10 min)

Open [`src/workflow.py`](../src/workflow.py) → `run_planning_workflow`. It takes a
scenario and an `approve` function (the person's decision), and runs
`sense → plan → propose → [person decides] → approve`. This follows the Microsoft Agent
Framework **sequential** pattern: each step hands its result to the next step, always in
the same order, and a person must approve before the final action.

### Part B — Read the workflow endpoint (10 min)

The console already makes the workflow available through one endpoint. Open
[`src/ui/app.py`](../src/ui/app.py) → `/api/run-loop`. It calls
`run_planning_workflow(scenario, approve=lambda _p: False, ...)`. This runs
`sense → plan → propose` on the server in one call and returns the results of all three
steps. It does **not** submit anything: the person still approves at Step 4.

### Part C — Add the one-click UI button (25 min)

Add a **"Run the whole loop"** button to
[`src/ui/static/index.html`](../src/ui/static/index.html) that:

1. `POST`s the chosen scenario to **`/api/run-loop`**, then
2. fills Steps 1–3 from the response (`assessment`, `recommendation`, `proposal`), and
   **stops at Step 4**, where a person clicks **Approve** or **Reject**.

First add the button element (for example next to the Step 1 **Sense demand**
button):

```html
<button id="btnRunLoop">Run the whole loop</button>
```

Then add this click handler as a starting point:

```javascript
document.getElementById("btnRunLoop").onclick = async () => {
  const r = await api("/api/run-loop", { scenario: $("scenario").value });
  if (r.error) return showError("outSense", r.error);
  $("outSense").hidden = false; $("outSense").textContent = r.assessment;
  recommendation = r.recommendation;
  submitItems = (r.proposal.submitItems) || [];
  renderPlan(r.recommendation);     // existing function: fills the Step 2 table
  renderProposal(r.proposal);       // existing function: fills Step 3 and the Step 4 summary
  $("btnApprove").disabled = false; $("btnReject").disabled = false;   // let the person decide
};
```

> [!TIP]
> `renderPlan()` and `renderProposal()` already exist in `index.html`. The Step 2 and
> Step 3 buttons use them. Reuse them here instead of writing the table HTML yourself.

> Keep the approval step. The button must stop before approval: the code runs
> everything *except* the person's decision. Never call `/api/approve` automatically.

### Part D — (Alternative) evaluation pass (optional)

If you prefer to measure answer quality instead:

1. In the portal, open **Evaluation**.
2. Create a small dataset of 3–5 questions with expected answers, for example *"Which
   store has the lowest leaf blower stock?"* → *"Portland"*.
3. Run it against `inventory-optimisation-agent`.
4. Review the **groundedness** score (are answers based on the data?) and the
   **relevance** score (do they answer the question?).

## 🏁 Success criteria

- [ ] You can explain how `/api/run-loop` and `run_planning_workflow` run the full loop
      from one call and stop before approval.
- [ ] The console's **Run the whole loop** button fills Steps 1–3 and stops at Step 4.
      *Quick test:* run it with *"A prolonged heatwave is forecast across the Southwest"*.
      Step 1 shows an assessment within about 10 seconds. Steps 2–3 fill in by themselves,
      and **Approve** / **Reject** become active at Step 4.
- [ ] **Reject** submits nothing. **Approve** adds a `PO-…` to the order book.
- [ ] You can explain when a fixed-order workflow is better than running each step by hand.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `/api/run-loop` returns an error | Check that all three agents work (Challenges 2–4) and that `az login` is still valid. |
| The button submits automatically | Don't call `/api/approve` from this button. Only the Approve button may call it. |
| Nothing appears | Check the browser console. The response contains `assessment`, `recommendation` and `proposal`. |

## 🚀 Go further

- Save the sequence as an **Agent Framework** YAML workflow and run it on a schedule.
- Try a **group chat** version, where the agents decide among themselves who acts next,
  instead of a fixed order.
- Require sign-in for the console, and keep a log of every approval.

## 📚 Learning resources

- [Agent Framework sequential workflows](https://learn.microsoft.com/agent-framework/workflows/orchestrations/sequential)
- [Build a workflow in Microsoft Foundry (Preview)](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/workflow)
- [Evaluate agents in Foundry](https://learn.microsoft.com/azure/ai-foundry/observability/how-to/evaluate-agent)
