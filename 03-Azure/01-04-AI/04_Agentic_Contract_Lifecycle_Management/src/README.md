# src — developer guide

All the source code the participant runs during the microhack lives here. It runs
unchanged in a Codespace / devcontainer or locally. Shared config and Foundry client
helpers live in [`clm_common/`](clm_common/); every entry-point script adds `src/`
(and `src/agents/`) to `sys.path`, so run them from the **repo root**.

## How the pieces fit

| Path | Role | Challenge |
|------|------|-----------|
| [`clm_common/`](clm_common/) | Shared config (`config.py`, `DATA_DIR`), Foundry client, document + tool helpers | all |
| [`agents/intake_drafting_agent.py`](agents/intake_drafting_agent.py) | Grounded, cited, guard-railed drafting agent (Claude Opus 4.8) | 2 |
| [`agents/clause_risk_agent.py`](agents/clause_risk_agent.py) | Clause & Risk specialist (GPT-5.6 Sol) | 4 |
| [`agents/obligation_renewal_agent.py`](agents/obligation_renewal_agent.py) | Obligation & Renewal agent (GPT-5-mini) reading status + renewals | 5 |
| [`kb_setup.py`](kb_setup.py) | Builds the Foundry IQ knowledge source + web-grounding tool over `clm-corpus` | 2 |
| [`sample_prompts.md`](sample_prompts.md) | Prompts to exercise drafting, grounded Q&A, guardrails | 2 |
| [`tracing_setup.py`](tracing_setup.py) | Wires OpenTelemetry → Application Insights | 3 |
| [`evaluators.py`](evaluators.py) | Eval scorecard, Claude-vs-GPT bake-off, quality gate (exit 3) | 3 |
| [`orchestrator.py`](orchestrator.py) | Orchestrator (GPT-5.4) with specialists as tools | 4 |
| [`mcp_server/server.py`](mcp_server/server.py) | MCP server exposing the CLM workflow over stdio | 4 |
| [`.vscode/mcp.json`](.vscode/mcp.json) | VS Code MCP client config (`clm-mcp`) | 4 |
| [`orchestrator_mcp.py`](orchestrator_mcp.py) | Orchestrator consuming the MCP server as a client | 4 |
| [`proactive_alerts.py`](proactive_alerts.py) | Proactive Teams renewal alerts via the Bot Framework | 5 |
| [`manifest/`](manifest/) | Teams / M365 Copilot app package (manifest + icons) | 5 |
| [`red_team.py`](red_team.py) | Automated red-teaming → `redteam_scorecard.json` | 6 |
| [`safety_eval.py`](safety_eval.py) | Safety evaluation + CLM guardrail gate | 6 |
| [`data/`](data/) | The CLM corpus + eval datasets (see [`data/README.md`](data/README.md)) | 1 |
| [`scripts/`](scripts/) | Build-time asset generators (corpus PDFs, banner, icons, diagrams) | — |

## Run it

Run everything from the **repo root** so the shared `src/` modules resolve, e.g.:

```bash
az login
python src/kb_setup.py                       # Challenge 2 — grounding
python src/agents/intake_drafting_agent.py   # Challenge 2 — the drafting agent
python src/orchestrator.py                    # Challenge 4 — orchestration
```

> Config is read from the repo-root `.env` via `clm_common/config.py`. Run
> [`../labautomation/deploy.sh`](../labautomation/deploy.sh) (or `azd up`) first so the
> `.env` is populated and the corpus is seeded.
