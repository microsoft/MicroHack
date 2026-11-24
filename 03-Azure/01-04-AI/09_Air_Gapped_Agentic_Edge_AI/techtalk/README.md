# Tech talk: Nothing crosses the line

A 22-minute tech talk to open the Air-Gapped Agentic Edge AI hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 15 animated sheets (Reveal.js), with a timed, first-person script in the speaker notes |

Every slide is a sheet of one engineering drawing. The air gap is drawn as a sealed line with a single
gate: what is allowed in crosses once, checked, and everything else stops at the line in red.

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed. To download only this hack instead of all of MicroHack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/09_Air_Gapped_Agentic_Edge_AI
   ```
   Or use **Code → Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each sheet draws itself when you arrive. When a sheet has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built sheet: **Pause** (and Resume), **Replay** (from the start
   of the sheet) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Sheet 12, **Rev B: sealed**, is the moment of the talk: let the probe hit the line, then click to
   inject the fault, and click again when the decision has landed to show the spindle slowing down.

With reduced motion turned on in the operating system, every step appears at once.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every sheet prints in its final state.

The deck uses Franklin Gothic Medium, Franklin Gothic Medium Cond, Segoe UI and Lucida Console, which
come with Windows. On other systems it falls back to Arial Narrow, the system font and Monaco.

## Where the numbers come from

Every number on the slides comes from the hack's own files and recorded runs. Nothing was measured for
the talk. [`deck/js/data.js`](deck/js/data.js) lists each value with its source file.

- Sheet 4: the host size from the Readme; the names from the manifests in `resources/manifests/`.
- Sheet 6: the transfer manifest is assembled from `model-deployment-cpu.yaml`, `edge-agent-deployment.yaml`,
  `inject-critical-fault.yaml`, `resources/infra/cloud-init-k3s.yaml`, `local-sop-configmap.yaml` and
  challenge 3. The manifest itself is a way of reading those files, not a file in the hack.
- Sheet 7: the 177-model catalog, the 5.15 GB download and its 6 to 7 minutes from challenge 3 and
  solution 3 (challenge 3 also quotes 5.38 GB); the store reference from `img/bastion-challenge-03-storing.png`.
  The positions of the dots are illustrative.
- Sheet 8: the decoded token and the 54 + 29 token completion from `img/bastion-challenge-04-sat-and-inference.png`.
- Sheet 10: the readings from `img/bastion-challenge-02-aio-anomaly.png` (ticks 330 to 336) and
  `img/bastion-challenge-05-cut-the-cord.png` (ticks 357 to 360); the filter from `aio-anomaly-dataflow.yaml`;
  the latencies from the challenge 5 screenshot; the 5-second period and every-6th-tick anomaly from solution 2.
- Sheet 11: `resources/manifests/04-airgap-policy/deny-external-egress.yaml` and solution 5.
- Sheets 12 and 13: the probe error, the decisions, the 8011.3 ms inference and the 4200 to 1680 rpm
  actuation from `img/bastion-challenge-05-cut-the-cord.png`; the fault values from `inject-critical-fault.yaml`;
  the thresholds from SOP-CNC-042. The failure path on sheet 13 is illustrative: the recording did not break the model.
- Sheet 14: the Readme (production topologies) and `challenges/finish.md`.
- Sheet 15: the machine wait per challenge from the Readme.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
