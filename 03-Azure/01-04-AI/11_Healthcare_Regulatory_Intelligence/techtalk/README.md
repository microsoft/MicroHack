# Tech talk: Follow the paragraph

A 23-minute tech talk to open the Healthcare Regulatory Intelligence hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 15 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

The talk follows one fictional safety alert from a regulator's website to a signed-off plan, in three
parts that mirror the hack: **code is exact** (the change monitor), **agents read and reason** (the
citation, impact and Q&A agents) and **people decide** (sign-off and the audit trail).

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install and no internet needed. To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/11_Healthcare_Regulatory_Intelligence
   ```
   Or use **Code, Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 13, **One alert, exactly the right records**, is the moment of the talk: ask the room which of
   the seven records the alert changes, wait, then click and let the paragraphs reach their records.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Sitka (headlines and quoted regulation text), Segoe UI and Consolas, which come with
Windows. On other systems it falls back to Cambria or Georgia, the system sans-serif and the system
monospace font.

## Where the numbers come from

Nothing on the slides was measured for the talk. Every number, date, ID and quoted text comes from this
hack's data, walkthroughs and code; [`deck/js/data.js`](deck/js/data.js) lists the counts with their source.
Everything in the hack, and therefore in the talk, is fictional: no real regulator, company, product or patient.

- Slides 1, 7, 11 and 13: the alert text is `data/portals/monday/eu-medicines-regulator/safety/EU-SA-2027-004.html`.
- Slide 2: the ten pages in `data/portals/monday`, and the story in the hack README.
- Slide 4: the expected Monday monitor output (run 1 and the repeat run) in `walkthrough/challenge-01/solution-01.md`,
  and the news mirror `data/portals/monday/eu-medicines-regulator/news/2027-01-11-caldivex.html`.
- Slide 5: `US-CD-2027-015` on Monday and Tuesday in `data/portals`, run 3 and the "stricter" misreading in
  `walkthrough/challenge-02/solution-02.md`. The agent's wording is paraphrased.
- Slide 7: the expected citation card in `walkthrough/challenge-02/solution-02.md`; the answer wording is illustrative.
- Slide 8: `US-EL-2027-007`, `data/internal/quality-records.md`, `data/internal/sops.md`, `data/tracking/tasks.json`
  and the expected assessment in `walkthrough/challenge-03/solution-03.md`.
- Slide 9: the four rules in `data/internal/owners.md` and the expected dates in `walkthrough/challenge-03/solution-03.md`.
- Slide 10: the comparison of model settings (7 runs each, output tokens) in `walkthrough/challenge-03/solution-03.md`.
  Which runs missed is not recorded, so the slide draws the passes first.
- Slide 11: the invented sentence is quoted from the test run in `challenges/challenge-04.md`; the other two
  draft sentences are illustrative.
- Slide 13: `data/internal/labels.md`, `sops.md`, `submissions.md`, the expected plan in
  `walkthrough/challenge-03/solution-03.md` and the example sign-off (approver "Alex Example") in
  `walkthrough/challenge-05/solution-05.md`.
- Slide 14: the error messages are those of `regintel/lake.py`, as listed in `walkthrough/challenge-05/solution-05.md`.
- Slide 15: the challenge titles and durations from the hack README.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
