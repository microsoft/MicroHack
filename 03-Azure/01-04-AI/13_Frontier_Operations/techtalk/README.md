# Tech talk: First light

A 23-minute tech talk to open the Frontier Operations hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 15 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

The idea of the talk in one line: **the work crosses the line, the decisions stay on it.** A horizon runs
through the deck. Below it is work people do by hand; above it is work agents do; on it, a white diamond
marks where a person decides. Each chapter is a time of day, and in the last scene the month-end process
of the hack crosses the line, step by step, with the evidence from the walkthroughs.

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed. To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/13_Frontier_Operations
   ```
   Or use **Code → Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 11, **Prepare, approve, submit**, asks the room a question: let the three green ticks settle,
   ask who would call it done, then click.
6. Slide 14, **The month crosses the line**, is the moment of the talk. Say "let's move it", then click,
   and let each step cross; two of them stop on the line first. The second click raises the sun.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Constantia, Corbel and Cascadia Mono, which come with Windows. On other systems it falls
back to Cambria or Georgia, Segoe UI or Gill Sans, and Consolas or SF Mono.

## Where the numbers come from

Every number is taken from this hack's walkthroughs, data files or challenge text, and
[`deck/js/data.js`](deck/js/data.js) lists each one with its source. The company, its partners and its
people are fictional, as in the hack.

- Slide 3: four people, three days, every month is from the hack's [README](../README.md). The cost uses the
  example values in [challenge 7, Part D](../challenges/challenge-07.md) (400 pounds a person-day).
- Slide 4: [`data/packs/distribution/statements/brightwell.csv`](../data/packs/distribution/statements/brightwell.csv)
  and the planted lines in [`walkthrough/expected-results.md`](../walkthrough/expected-results.md).
- Slide 6: the first run in [solution 1](../walkthrough/challenge-01/solution-01.md) (56 s, 222,069 tokens).
  The step names are the playground's; their descriptions are summarised.
- Slide 7: [solution 2](../walkthrough/challenge-02/solution-02.md): 4 of 6 without the skill, 6 of 6 with it,
  and 15 of 30 against 30 of 30 for the API runs.
- Slide 8: [challenge 3](../challenges/challenge-03.md) and [solution 3](../walkthrough/challenge-03/solution-03.md):
  91 s, 26 of 30, then 30 of 30 after a 23 s redo. The brief is quoted, shortened, from the trace in
  `images/challenge-03-subagent-brief.png`. "2 of 6" for Northgate follows from the score output in
  `images/challenge-03-score-after-redo.png`, where all four misses are Northgate's.
- Slide 10: [challenge 4](../challenges/challenge-04.md) and [solution 4](../walkthrough/challenge-04/solution-04.md).
- Slide 11: [challenge 5](../challenges/challenge-05.md), [solution 5](../walkthrough/challenge-05/solution-05.md)
  and `images/challenge-05-portal-cases.png`. The chat is shortened; the references are real.
- Slide 12: [challenge 6](../challenges/challenge-06.md) and [solution 6](../walkthrough/challenge-06/solution-06.md).
- Slide 13: [solution 7](../walkthrough/challenge-07/solution-07.md) and the token split in challenge 7, Part C.
- Slide 14: the evidence of slides 8, 10 and 11, and the API run with the skill in solutions 3 and 7
  (3 min 39 s, 30 of 30). The money is solution 7's worked example (4,800 pounds today, about 250 pounds of
  review and approval), built on the hack's illustrative assumptions. The person-day blocks that fade as
  each step crosses are illustrative.

Product facts (the Microsoft Copilot harness, skills, toolboxes, Browser Automation, guardrails and egress
rules) follow the hack's own text and its Microsoft Learn links.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
