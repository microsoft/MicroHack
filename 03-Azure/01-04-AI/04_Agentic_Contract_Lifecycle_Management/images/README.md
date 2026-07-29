# Images

All rendered image assets for the CLM microhack. Editable diagram sources are kept in
[`diagrams/`](diagrams/); the challenge screenshots live in per-challenge subfolders.

## Top-level assets

| File | Used in |
|------|---------|
| [`banner.png`](banner.png) | The repo hero banner at the top of the [README](../README.md) |
| [`architecture.png`](architecture.png) | The finalized architecture diagram (also in [`diagrams/`](diagrams/)) |
| [`diagrams/`](diagrams/) | Architecture + user-journey diagrams — see [`diagrams/README.md`](diagrams/README.md) |

## Challenge screenshots

Each `challenge-0N/` folder holds the screenshots embedded in that challenge's
instructions (with `steps/` subfolders for numbered walkthrough steps), so you know
what each step should look like.

| Folder | Challenge |
|--------|-----------|
| [`challenge-01/`](challenge-01/) | Setup & Foundry Foundations |
| [`challenge-02/`](challenge-02/) | Grounded Agent with Foundry IQ + Tools |
| [`challenge-03/`](challenge-03/) | Observability, Tracing & Evaluation |
| [`challenge-04/`](challenge-04/) | Orchestration + MCP Server |
| [`challenge-05/`](challenge-05/) | Publish to M365 Copilot & Teams + Proactive Alerts |
| [`challenge-06/`](challenge-06/) | Safety, Red-Teaming & Continuous Evaluation |

> Regenerate the generated assets with the scripts in
> [`../src/scripts/`](../src/scripts/) — e.g. `python src/scripts/make_banner.py` (banner),
> `python src/scripts/make_icons.py` (Teams app icons), and
> `python src/scripts/make_challenge0_resources.py` (Challenge 1 resource diagram).
