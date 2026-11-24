# Tech talk: Ask the shelf

A 22-minute tech talk to open the Agentic Inventory Planning hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 14 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

The talk follows one shelf: the Leaf Blower X2 at the Seattle store, which drains from a normal 30 to 6
on the cover. Three parts follow the hack: **Count** (the Lakehouse and its Fabric Data Agent, Challenge 1),
**Reason** (three prompt agents and their traces, Challenges 2 and 3) and **Sign** (the purchase order and
the human approval gate, Challenges 4 and 5). The sentence to remember: *let the model reason, let the
Lakehouse count, let a person sign.*

The agenda gives the tech talk a 60-minute slot: the talk takes about 22 minutes, which leaves time for
questions and a look at your own Data Agent in the Fabric portal.

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed. To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/02_Inventory_Planning_Fabric
   ```
   Or use **Code, Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 12, **The guess and the count**, is the moment of the talk. The purchase order first prints with
   the $20 fallback cost; ask the room "Does this look right?" and wait before you click. The first click
   looks the costs up in the Lakehouse, the second plays the planner's MODIFY and YES and refills the shelf.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Georgia for headlines, Segoe UI for text and Consolas for data, which come with Windows.
On other systems it falls back to Times New Roman, the system font and Cascadia Mono or SF Mono.

## Where the numbers come from

Every number comes from this hack's own files. Nothing on the slides is a recorded run; values that are
derived or illustrative say so on the slide. [`deck/js/data.js`](deck/js/data.js) lists every number
with its source.

- Slide 2: `DemandHistory` for P004 at the Seattle store (5 a week, then 7 in the last two weeks) and the
  `ExternalSignals` rows SIG01, SIG02 and SIG07, all built by `setup/Setup-InventoryDataAgent.ipynb`
  (the same rows are in `data/*.parquet`). The 6-week average, 5.7, is calculated from those rows.
- Slide 3: on hand from `Inventory` (Seattle 6, Portland 8), the lead time from `Products` (21 days).
  Days on the shelf are derived at the latest weekly rate (7 a week); the slide says it is illustrative.
- Slide 5: the test question and its answer from Challenge 1, task 4g (`challenges/challenge-01.md`);
  safety stock 30 and reorder point 60 follow the formulas in the setup notebook. The SQL is illustrative.
- Slide 6: the three symptoms and fixes from the troubleshooting tables of Challenges 1, 2 and 3.
- Slide 8: agents and tools as configured in Challenges 2, 3 and 4.
- Slide 9: the reorder rule from `challenges/challenge-03.md` and the sample table from
  `walkthrough/challenge-03/solution-03.md` (18, 16 and 8).
- Slide 10: the span names and durations from `walkthrough/challenge-03/solution-03.md`; the bars are illustrative.
- Slide 12: the sample table, the $20 fallback, MODIFY 1 50 and YES from `challenges/challenge-04.md`; unit costs
  from `Products` ($95, $85, also in `challenges/challenge-05.md`). The totals ($840, $3,910, $6,950) are calculated.
- Slide 13: the workflow, the loop condition and the dates (30 November and 1 December 2026) from
  `challenges/challenge-05.md` and `walkthrough/challenge-05/solution-05.md`.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
