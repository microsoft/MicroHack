# Tech talk: Three agents and a yes

A 22-minute tech talk to open the Agentic Inventory Planning hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 14 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet and no Azure resources needed. To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/03_Inventory_Planning_Agentic
   ```
   Or use **Code > Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 12, **The whole relay, and one yes**, is the moment of the talk. Let the baton run until it
   stops at the gate (about 16 seconds), ask the room whether they would approve, then click
   **Approve & submit** on the slide (or press the right arrow). **Reject** shows the console's real
   cancel message instead, if someone wants to see the other path first.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Gill Sans MT, Segoe UI and Cascadia Code, which come with Windows and Office.
On other systems it falls back to Gill Sans, the system font and SF Mono or Consolas.

## Where the numbers come from

Nothing on the slides is invented. [`deck/js/data.js`](deck/js/data.js) lists every value with its
source file; paths are relative to this hack's folder.

- Slide 3: the 72 shelves are the seed data in `src/data` (`products.json`, `stores.json`,
  `inventory_overrides.json`), with reorder point, safety stock and status computed by the same rules as
  `_derive_inventory` in `src/inventory_store.py` and `_status` in `src/tools.py`. The result, 14 exposed
  (5 CRITICAL, 9 AT_RISK), matches the console header in `images/challenge-03-approve.png`.
  The signal is `SIG01` in `src/data/external_signals.json`.
- Slide 4: weekly demand from `_derive_demand` in `src/inventory_store.py`, the rule from `calc_reorder` in
  `src/tools.py`, and the recorded plan quantities from `images/challenge-03-approve.png`.
- Slide 6: agents and tools from `src/agents/__init__.py`; read and write tools from `src/tools.py`.
- Slide 7: the four tool calls and the durations (1.17 s, 753 ms, 2 spans, 1 tool call, 1.2 s) from the
  recorded Foundry trace in `images/challenge-02-trace.png`; the call loop is `run()` in `src/agent_runtime.py`.
- Slide 8: the scenario, assessment and quantities from `images/challenge-03-approve.png`; the JSON keys
  from the agent instructions in `src/agents/__init__.py`. The JSON is shortened on the slide.
- Slide 10: the prompt line from `src/agents/__init__.py`, the code from `src/agent_runtime.py`, and the
  trace finding from challenge 4, Part D. The call slipping past the prompt is illustrative: it shows
  what the code does if a model ignores the instruction.
- Slide 11: `src/ui/app.py`, `src/live.py` (3-second change-feed polling, start from Now, the queue),
  `src/mcp_server.py` and `src/mcp_client.py`.
- Slide 12: the run log, its times (9:11:08 PM to 9:11:35 PM, so 27 s from signal to gate) and the
  three purchase-order lines ($27,525) from the recorded event-driven run in
  `images/challenge-05-reactive.png`. The approval outcome and the confirmation text are the documented
  behaviour from challenges 4 and 6 and `submit_purchase_order` in `src/tools.py`; the PO number is shown
  in its format, `PO-yyyymmdd-001`. The animation runs faster than the recorded 27 seconds.
- Slide 13: the challenge list and times from the hack's `README.md`.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
