# Tech talk: Say it once

A 23-minute tech talk to open the Contact Center Agents hack.
By **Digvijay Chauhan**, Solution Engineer, Microsoft.

| | |
|---|---|
| [`deck/index.html`](deck/index.html) | The talk: 14 animated slides (Reveal.js), with a timed, first-person script in the speaker notes |

## Present the talk

1. Get the talk, then open `deck/index.html` in Edge or Chrome. Everything is in the folder:
   no server, no install, no internet needed. To download only this hack:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack.git
   cd MicroHack && git sparse-checkout set 03-Azure/01-04-AI/12_Contact_Center
   ```
   Or use **Code → Download ZIP** on GitHub and unzip it.
2. Press **S** for the speaker view (notes and timer), **F** for full screen, **Esc** for the overview.
3. Each slide builds by itself when you arrive. When a slide has more to show, it stops and a small
   **Click to continue** cue appears at the top right: press the right arrow (or click) when you are ready.
   The notes mark every click with **[click]**.
4. The controls at the top right of every built slide: **Pause** (and Resume), **Replay** (from the start
   of the slide) and **Show all** (the final state at once). Going back shows the previous state without
   replaying it.
5. Slide 12, **Margaret's call**, is the moment of the talk. It plays a recorded call from the hack in real
   time (62 seconds) with its sound, so check the room's audio first. The **Sound on** button on the slide
   turns the sound off and on; Pause also pauses the sound. Let the call play, then click twice: the call
   becomes a whisper card, then a person picks up.

With reduced motion turned on in the operating system, every step appears at once, without sound.

**PDF of the slides:** open `deck/index.html?print-pdf` in Edge or Chrome and print to PDF
(landscape, no margins, background graphics on). Every slide prints in its final state.

The deck uses Trebuchet MS, Segoe UI and Consolas, which come with Windows. On other systems it falls back
to Lucida Grande, the system font and Menlo.

## Where the numbers come from

Everything on the slides comes from this hack's files. [`deck/js/data.js`](deck/js/data.js) lists every
value with its source.

- **Every waveform is a real recording**: the telco pack's calls in `data/packs/telco/calls/`.
  [`deck/tools/extract_waveforms.py`](deck/tools/extract_waveforms.py) (ffmpeg and numpy) measures their
  loudness every 0.1 s and finds the speaker turns from the pauses, and writes `deck/js/waves.js`.
  `deck/media/KC-CALL-03.mp3` is a copy of the pack's recording. The shapes on slide 6, the earlier calls on
  slide 3 and the adviser's voice on slide 12 are illustrative, and labelled so.
- Slide 3: `KC-CALL-02.txt` and the problems listed in the hack's Readme.
- Slide 4: `KC-CALL-01`, `KB-KC-007` and Challenge 2 (the realtime model, the voice and the instructions).
- Slide 6: the telco voice and chat tests in `walkthrough/challenge-03/solution-03.md`.
- Slide 7: the portal test with the guardrail applied and the blocklist trap, in `walkthrough/challenge-04/solution-04.md`.
- Slide 9: `data/packs/telco/insights/KC-CONTACTS.md`, `walkthrough/challenge-06/solution-06.md` and
  `walkthrough/finish/solution-finish.md` (the 2% sample and its 4% chance).
- Slide 10: the portal runs in `walkthrough/challenge-07/solution-07.md`.
- Slide 12: the sound, waveform and words are `KC-CALL-03`. The signals are what Content Understanding found
  in that call (solution 6). The tool calls, the handoff reference `KC-HO-0103` and the whisper card come from
  the voice agent and agent-assist with the same customer (solutions 4 and 5, and
  `images/challenge-05-whisper-card.png`). The moment each signal appears is aligned to the words that justify it.
- Slide 13: the challenge table in the hack's Readme.

The slides use [Reveal.js](https://revealjs.com) 6.0.2 (MIT licence, in `deck/vendor/`).
