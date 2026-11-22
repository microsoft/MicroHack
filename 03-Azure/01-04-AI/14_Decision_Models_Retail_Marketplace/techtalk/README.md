# Tech talk: Launch Day at Zava

A 25-minute tech talk to open the hack, and a companion guide for participants.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 14 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |
| [`Decision_Models_101_Companion_Guide.pdf`](Decision_Models_101_Companion_Guide.pdf) | The companion guide to hand out (9 pages) |
| [`companion-guide.md`](companion-guide.md) | The same guide as Markdown (the source of the PDF) |

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed. To download only this hack instead of all of MicroHack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/14_Decision_Models_Retail_Marketplace
   ```
   Or use **Code → Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive, on the timings in the notes. The controls at the top
   right of every slide: **Replay**, **Replay now** (skips the opening pause), **Pause**,
   **Show result** and **Motion** (on or off). Using a slide's own buttons or handles hands it over to you.
4. Slide 9 waits for you: ask the room, then click **Audit the outcome** and **Fix the question**.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

## Where the numbers come from

- Slides 1, 3, 5, 7, 8 and 11 use the hack's recorded Microsoft-Decision-1.1 and gpt-6-luna runs
  (`src/data/recorded/`). `deck/js/data.js` is generated from them; to regenerate it after the
  recorded runs change, run from `src`: `python ../techtalk/deck/tools/extract_data.py`.
- Slides 2, 9 and 10 use the numbers in the walkthroughs (rehearsal, Monday and live runs).
- Slide 6 uses Microsoft's Ignite 2026 announcements (17 and 18 November 2026), as cited on the slide.
- The banking and manufacturing examples on slide 12 are illustrative designs, not measured results.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
