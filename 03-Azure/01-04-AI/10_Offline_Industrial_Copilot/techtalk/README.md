# Tech talk: Pull the cable

A 22-minute tech talk to open the Offline Industrial Copilot hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 13 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed (fitting, for this hack). To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/10_Offline_Industrial_Copilot
   ```
   Or use **Code → Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 11, **Pull the cable**, is the moment of the talk: wait on the green lamps, say "let's pull it",
   then click.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Bahnschrift and Cascadia Mono, which come with Windows. On other systems it falls back
to DIN Alternate or the system font.

## Where the numbers come from

Every number on the slides comes from a recorded run of this hack on 23 November 2026
(Snapdragon X Elite laptop, Foundry Local 0.14.0), and is also in the walkthroughs.
[`deck/js/data.js`](deck/js/data.js) lists them with their source.

- Slide 3: the answer and its time are from the offline run in challenge 6. The path to the cloud is illustrative.
- Slide 6: `benchmark.py` (challenge 2). The qwen2.5 NPU error is described in solution 2.
- Slide 7: `check_routing.py holdout` with and without the router (challenges 3 and 5), with the real misses.
- Slide 8: `evaluate_retrieval.py` and `evaluate_retrieval.py agent` (challenge 4); the SOP is `resources/data/sops/SOP-CNC-001_spindle_vibration.md`.
- Slide 9: the studio export from an Azure Machine Learning workspace, compared with `resources/shortcut/fault_classifier.onnx` (same SHA-256), and `predict_fault` times.
- Slide 11: `copilot.py` with the internet blocked, then after restarting Foundry Local offline (challenge 6).

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
