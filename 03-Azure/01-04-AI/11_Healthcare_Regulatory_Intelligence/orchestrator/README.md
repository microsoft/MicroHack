# Regulatory Intelligence Assistant

[Home](../README.md) | [Challenge 6](../challenges/challenge-06.md)

A small Microsoft Agent Framework program that chains your three saved Foundry prompt agents:

```text
citation-agent  ──►  impact-agent  ──►  briefing-agent
```

| File | Purpose |
|---|---|
| `process_events.py` | **Challenge 6.** Reads change events from the lake, runs the chain once per event, and writes briefings marked *pending human sign-off*. Add `--starter` to use your own chain |
| `workflow.py` | The finished chain, with comments for the Challenge 6 code tour; resolves the latest saved version of each agent unless versions are pinned |
| `starter/workflow.py` | The same file with the three chain-building steps left as TODOs, for participants who want to write it |
| `check_starter.py` | Checks `starter/workflow.py` offline (no Azure calls) and says which TODO to do next |
| `configuration.py` | Reads and validates `.env` / environment variables |
| `main.py`, `azure.yaml` | Optional: host the same chain in Foundry as a hosted agent so people can chat with it |
| `requirements.txt` | Pinned packages (identical to the `orchestrator` extra in `pyproject.toml`) |

## Configuration

Copy `.env.example` to `.env` and set `FOUNDRY_PROJECT_ENDPOINT`. Optional settings:

| Variable | Default |
|---|---|
| `CITATION_AGENT_NAME`, `IMPACT_AGENT_NAME`, `BRIEFING_AGENT_NAME` | `citation-agent`, `impact-agent`, `briefing-agent` |
| `CITATION_AGENT_VERSION`, … | Empty: use the latest saved version |
| `REGINTEL_MANAGED_IDENTITY` | `false` locally; `true` when hosted |

`.env` is ignored by Git and excluded from hosted deployment.

## Run the event processor

From the lab folder in Codespaces or the devcontainer, after `az login`:

```bash
uv run python orchestrator/process_events.py --account <StorageAccountName> --limit 3
```

Every run calls models in your Foundry project, which incurs normal token charges.

## Optional: host the assistant in Foundry (facilitator-led)

This step is not needed to complete the hack. The hosted agent runs with its **own managed identity**. Before deploying, a facilitator must:

1. Confirm the Azure Developer CLI AI agent extensions listed in `azure.yaml` are installed (`azd extension list`).
2. Grant the hosted agent's identity the **Foundry User** role on the project after its first deployment, so it can call the three prompt agents.

Then, from this folder:

```bash
azd auth login --use-device-code
azd env new regintel --no-prompt
azd env set FOUNDRY_PROJECT_ENDPOINT "<FoundryProjectEndpoint>"
azd env set AZURE_SUBSCRIPTION_ID "<subscription id>"
azd env set AZURE_LOCATION "<lab region>"
azd deploy regulatory-intelligence-assistant --no-prompt
```

Test it in the Foundry playground with: `Assess change event EVT-US-EL-2027-007-v1.` Like the event processor, it proposes and never approves.

## Tests

`tests/test_orchestrator.py` validates configuration, builds the real SDK chain with network access blocked, and checks that the event processor writes each briefing once and skips processed events.
