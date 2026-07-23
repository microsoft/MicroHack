# Challenge 4 — Replenishment Action + Human-in-the-Loop

**[← Previous](challenge-03.md)** - [Home](../README.md) - [Next Challenge →](challenge-05.md)

## 🎯 Objective

Build the third hosted agent: it proposes a purchase order, then a **human approves
or rejects it in code** before the one side-effecting tool runs. This is the gate
that turns an AI assistant into an AI agent that genuinely acts.

## 🧭 Context

Someone has to actually place the order — but purchase orders need a human sign-off.
Your Replenishment Action Agent **proposes**; a person **decides**; the tool **acts**.

## ✅ Tasks

### Part A — Read the agent & the gate (20 min)

Open [`src/agents/__init__.py`](../src/agents/__init__.py) → `REPLENISHMENT`. It has
two tools: `get_product` (to look up unit costs) and `submit_purchase_order` (the
only side effect). Its instructions tell it to **propose** a PO as JSON and to
**never** submit without approval.

Now open [`src/agent_runtime.py`](../src/agent_runtime.py). The set
`APPROVAL_REQUIRED = {"submit_purchase_order"}` makes the runtime **refuse to
auto-execute** that tool: if the model asks for it, `run()` returns a
`ToolApprovalRequest` instead of acting. The human decision happens in
[`src/orchestrator.py`](../src/orchestrator.py) → `approve()`, which only runs the
tool after a person says yes.

> [!NOTE]
> The approval here isn't *simulated in a prompt* — the acting tool is **structurally
> blocked** until a human approves.

### Part B — Build the proposal (20 min)

In the console, after Steps 1–2, click **Build PO proposal**. That first click
**creates the `replenishment-action-agent` hosted agent**, then runs it: **Step 3**
renders a per-line purchase-order proposal with a total, and **Step 4 (Approve &
act)** unlocks. Nothing is submitted yet — the agent only *proposes*. The **Approve**
/ **Reject** buttons appear for the human gate you test next, and **Step 4 shows a
summary of exactly what you're approving** — the per-line PO and total — so the
decision is fully informed.

### Part C — Approve in the console (25 min)

> [!IMPORTANT]
> This is the payoff: the whole loop, with the human gate, in the UI.

1. With the proposal at **Step 3** and the **Approve** / **Reject** buttons at **Step 4** (from Part B):
2. Click **Reject** first — confirm *"Order cancelled. No action taken."* and that
   the order book does **not** change.
3. Refresh the page, re-run Steps 1–3, then click **Approve & submit** — the
   confirmation `✅ Purchase order PO-… submitted and recorded in the order book.`
   appears and the new order shows up in the **order book** panel (a real Cosmos write).

![Planner console at the approval gate — Step 4 shows the per-line PO summary with Approve / Reject before the write](../images/challenge-03-approve.png)

### Part D — Trace the acting run (10 min)

In the portal, open the `replenishment-action-agent` **Traces** tab and its latest
run. You'll see the `get_product` unit-cost lookups — but **no** `submit_purchase_order`
call, because the runtime blocks it and hands control to the human before it can run.

## 🏁 Success criteria

- [ ] `replenishment-action-agent` exists with `get_product` + `submit_purchase_order`.
- [ ] The proposal is a per-line cost table with a total.
- [ ] **Reject** writes nothing; **Approve** appends a `PO-…` to the order book.
- [ ] You can explain, pointing at the code, *why* the agent can't submit on its own.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| An order is written without approval | Confirm `submit_purchase_order` is in `APPROVAL_REQUIRED`. |
| Unit costs all show `$20` | The `get_product` lookup failed — check the trace; `$20` is the fallback only. |
| Proposal isn't valid JSON | Reinforce *"Return ONLY the JSON"* in the instructions. |
| Approve does nothing | Ensure `submitItems` is populated in the proposal (see the agent instructions). |

## 🚀 Go further

- Add a **spend cap**: reject any proposal above a threshold and escalate.
- Capture the approver's **name and reason** and echo them in the confirmation.
- Query the Cosmos `orders` container directly (portal Data Explorer) to see your
  submitted PO persisted alongside the seed orders.

## 📚 Learning resources

- [Human-in-the-loop tool approvals for agents](https://learn.microsoft.com/agent-framework/agents/tools/tool-approval)
- [Agent development lifecycle](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/development-lifecycle)
