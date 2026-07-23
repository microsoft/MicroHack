# Images

`architecture.png` is the rendered hack diagram embedded in the [README](../README.md).
It is the only diagram artifact committed to the repo.

> The editable source (`architecture.excalidraw`) is kept **locally** and excluded from
> the repo via `.gitignore` — only the rendered `architecture.png` ships. To update the
> diagram, open `architecture.excalidraw` at [aka.ms/excalidraw](https://aka.ms/excalidraw),
> edit it, and **export it to PNG** over `images/architecture.png`.

## Challenge screenshots

These PNGs are embedded in the challenge instructions so you know what each step
should look like. Each one shows a real step of the planner console (or the Foundry
portal) from the sense → plan → approve → act loop:

| File | Shows |
|------|-------|
| `challenge-01-console.png` | Planner console after **Step 1** — the demand assessment, with Step 2 unlocked. |
| `challenge-02-console.png` | Planner console **Step 2** — the reorder recommendation table with CRITICAL rows. |
| `challenge-02-trace.png` | Foundry **Traces** view of an `inventory-optimisation-agent` run: the `invoke_agent` span and the `execute_tool` call showing `calc_reorder` / `query_inventory` with their parameters. |
| `challenge-03-approve.png` | Planner console at the **approval gate** — the purchase-order proposal plus Step 4's summary of exactly what's being approved, with Approve / Reject. |
| `challenge-05-reactive.png` | The event-driven loop (Challenge 6): an injected signal auto-runs sense → plan → propose live, with the natural-language edit boxes and the informed approval gate. |

To refresh one, run the matching step in the planner console (or open the agent's
**Traces** tab in the Foundry portal for the trace) and re-save it under the same file
name. Keep them legible in the rendered Markdown.
