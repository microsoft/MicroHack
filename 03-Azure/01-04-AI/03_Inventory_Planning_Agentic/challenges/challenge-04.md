# Challenge 4 — Orchestrate the Loop (Stretch)

**[← Previous](challenge-03.md)** - [Home](../README.md) - [Next Challenge →](challenge-05.md)

> [!NOTE]
> Optional stretch for teams that finish early. It builds on the three agents from
> Challenges 1–3. Skip without penalty — Challenges 0–3 are the core.

## 🎯 Objective

Chain the three agents into one **sequential workflow** so the entire
sense → plan → approve → act loop runs from a single entry point, pausing only at
the human-approval gate. Then wire the console's one-click **"Run the whole loop"**.

## 🧭 Context

Planners don't want to click four buttons — they want to type one sentence and have
the system run the loop, stopping only for approval.

## ✅ Tasks

### Part A — Read the workflow (10 min)

Open [`src/workflow.py`](../src/workflow.py) → `run_planning_workflow`. It takes a
scenario and an `approve` callback (the human gate) and runs
`sense → plan → propose → [human] → approve`. This mirrors the Microsoft Agent
Framework **sequential** pattern: deterministic hand-off with a gate before the
terminal action.

### Part B — Read the workflow endpoint (10 min)

The console already exposes the workflow through one endpoint. Open
[`src/ui/app.py`](../src/ui/app.py) → `/api/run-loop`: it calls
`run_planning_workflow(scenario, approve=lambda _p: False, ...)` — running
`sense → plan → propose` server-side in one shot and returning all three stages,
**without** submitting (the human still approves at Step 4). This is the sequential
workflow driving the whole loop from a single call.

### Part C — Add the one-click UI button (25 min)

Wire a **"Run the whole loop"** button in
[`src/ui/static/index.html`](../src/ui/static/index.html) that:

1. `POST`s the chosen scenario to **`/api/run-loop`**, then
2. fills Steps 1–3 from the response (`assessment`, `recommendation`, `proposal`) and
   **stops at Step 4** for the human's **Approve / Reject**.

First add the button element (for example next to the Step 1 **Sense demand**
button):

```html
<button id="btnRunLoop">Run the whole loop</button>
```

Then attach a handler to get you started:

```javascript
document.getElementById("btnRunLoop").onclick = async () => {
  const r = await api("/api/run-loop", { scenario: $("scenario").value });
  if (r.error) return showError("outSense", r.error);
  $("outSense").hidden = false; $("outSense").textContent = r.assessment;
  recommendation = r.recommendation;
  submitItems = (r.proposal.submitItems) || [];
  renderPlan(r.recommendation);     // existing helper — fills the Step 2 table
  renderProposal(r.proposal);       // existing helper — fills Step 3 and the Step 4 summary
  $("btnApprove").disabled = false; $("btnReject").disabled = false;   // open the human gate
};
```

> [!TIP]
> `renderPlan()` and `renderProposal()` already exist in `index.html` — they power the
> manual Step 2/3 buttons. Reuse them here instead of hand-rolling table markup.

> Keep the human gate: the button must still stop at approval — the whole point is
> that automation runs everything *except* the human decision. Never auto-call
> `/api/approve`.

### Part D — (Alternative) evaluation pass (optional)

If you'd rather evaluate quality: in the portal **Evaluation**, build a small
dataset of 3–5 questions with expected answers (e.g. *"Which store has the lowest
leaf blower stock?"* → *"Portland"*), run it against `inventory-optimisation-agent`,
and review **groundedness** and **relevance**.

## 🏁 Success criteria

- [ ] You can explain how `/api/run-loop` + `run_planning_workflow` drive the full
      loop from one call, pausing at approval.
- [ ] The console's **Run the whole loop** button fills Steps 1–3 and stops at Step 4.
      *Quick test:* run it with *"A prolonged heatwave is forecast across the Southwest"* —
      Step 1 shows an assessment within ~10 s and Steps 2–3 populate on their own, with
      **Approve / Reject** live at Step 4.
- [ ] **Reject** submits nothing; **Approve** appends a `PO-…` to the order book.
- [ ] You can explain when a deterministic workflow beats manual step-by-step driving.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `/api/run-loop` returns an error | Ensure all three agents work (Challenges 1–3) and `az login` is valid. |
| The button submits automatically | Don't call `/api/approve` from the button; only from the Approve button. |
| Nothing renders | Check the browser console — the response keys are `assessment`, `recommendation`, `proposal`. |

## 🚀 Go further

- Export the sequence as an **Agent Framework** YAML workflow and run it as a routine.
- Add a **group-chat** variant where agents hand off dynamically instead of in a fixed order.
- Publish the console behind auth and add an audit log of every approval.

## 📚 Learning resources

- [Agent Framework sequential workflows](https://learn.microsoft.com/agent-framework/workflows/orchestrations/sequential)
- [Build a workflow in Microsoft Foundry (Preview)](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/workflow)
- [Evaluate agents in Foundry](https://learn.microsoft.com/azure/ai-foundry/observability/how-to/evaluate-agent)
