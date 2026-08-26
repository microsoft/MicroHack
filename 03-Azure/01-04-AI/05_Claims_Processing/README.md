# Agentic Claims Processing Hackathon

This microhack walks through an end-to-end claims workflow built with Microsoft Foundry and Azure Functions.

## What you will build

You start with claim intake and document understanding, then move through policy grounding, sequential orchestration, security hardening, and finally deployment as an HTTP-triggered Azure Function.

```mermaid
flowchart LR
	C1[Challenge 1\nOCR + knowledge grounding] --> C2[Challenge 2\nPolicy coverage decision]
	C2 --> C3[Challenge 3\nSequential workflow]
	C3 --> C4[Challenge 4\nFIDES security fence]
	C4 --> C5[Challenge 5\nAzure Function deployment]
```

## Challenge flow

1. [Challenge 1](./challenges/challenge-01.md) - OCR a claim statement and ground it in Azure AI Search / Foundry IQ knowledge.
2. [Challenge 2](./challenges/challenge-02.md) - Compare the claim against real policy documents and produce a coverage decision.
3. [Challenge 3](./challenges/challenge-03.md) - Combine the intake and decision agents into a sequential workflow with an optional human-review branch.
4. [Challenge 4](./challenges/challenge-04.md) - Harden the workflow against prompt injection and data exfiltration with FIDES.
5. [Challenge 5](./challenges/challenge-05.md) - Expose the secured workflow as an Azure Function with an HTTP trigger and managed identity.

## Repository layout

- `challenges/` contains the step-by-step lab instructions.
- `docs/` contains the Python scripts that support each challenge.
- `functions/` contains the Azure Functions project used in Challenge 5.
- `labautomation/` contains the deployment template and lab setup scripts.
- `data/` contains the sample claim and policy files used throughout the microhack.
- `walkthrough/` contains the numbered solution walkthrough for each challenge.

## Before you start

Use Python 3.11 and [uv](https://docs.astral.sh/uv/) for the participant environment.
From the repository root, install the pinned project dependencies:

```bash
uv sync
```

Activate the generated environment on PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

On Bash, run `source .venv/bin/activate`.

Create the single environment file used by Challenges 1 through 4:

```powershell
Copy-Item .env.example .env
```

On Bash, use `cp .env.example .env`. Replace the placeholders in `.env` with
the credentials supplied by the MicroHack platform or your event coach. Then
authenticate the same event account used for the lab:

```bash
az login
```

After activation, confirm the participant CLI is available:

```bash
python docs/claims-intake-agent.py --help
```

If you run Challenge 5 locally, also install Azure Functions Core Tools v4 and
start Azurite or provide a real storage connection string.

## Coach provisioning

Participants must not run `labautomation/deploy-lab.ps1`. The MicroHack
platform invokes this script and supplies its five-parameter contract,
including the platform-only `Get-MhhStableHash` helper. Coaches should import
the lab through the platform, verify the returned Hackbox credentials, and
provide each participant with the values required by `.env.example`.

## Notes

- Challenge 3 now includes a conditional human-review branch.
- Challenge 4 builds on that workflow with deterministic security enforcement.
- Challenge 5 deploys the secured workflow behind an HTTP endpoint instead of a CLI script.

If you want to start from the beginning, open [challenge-01.md](./challenges/challenge-01.md).
