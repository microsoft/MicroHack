# Challenge 3 - Orchestrate the Three-Agent Claims Workflow

[Home](../README.md)

**Expected Duration:** 45 minutes

## Overview

Challenges 1 and 2 created three Foundry agents. This challenge runs those existing
agents in sequence without redefining their instructions or duplicating their policy
rules:

1. `claims-intake-agent` from Challenge 1
2. `policy-extraction-agent` from Challenge 2
3. `coverage-decision-agent` from Challenge 2

The name "Claims Intelligence Agent" refers to the Challenge 2 application component
that coordinates policy extraction and coverage adjudication. It is not a fourth
Foundry agent.

In short: **accident statement image -> intake agent -> structured claim -> policy
extraction agent -> structured policy -> coverage decision agent -> conditional human
review -> final decision**.

```mermaid
flowchart TD
        A[Accident statement image] --> B[claims-intake-agent<br/>Step 1]
        B --> C[Structured claim]
        C --> D[policy-extraction-agent<br/>Step 2]
        D --> E[Structured policy]
        E --> F[coverage-decision-agent<br/>Step 3]
        F --> G{Escalated or low confidence?}
        G -- No --> H[Final decision]
        G -- Yes --> I[Human review<br/>Step 4]
        I --> H
```

The structured intake and policy objects stay in memory. The workflow prints the final
decision and does not create another local JSON file.

## Prerequisites

- Complete [Challenge 1](./challenge-01.md) and [Challenge 2](./challenge-02.md).
- Keep the repository-root `.env` configuration used by those challenges.
- Synchronize the root Python environment if you have not already done so:

```bash
uv sync
```

- Confirm that `claims-intake-agent`, `policy-extraction-agent`, and
    `coverage-decision-agent` appear under **Agents** in your Foundry project. The
    coverage agent is created the first time you complete Challenge 2 Task 3.


## Task 1: Confirm the three Foundry agents (no action needed)

Open your Foundry project and confirm that these agents are available:

- `claims-intake-agent`
- `policy-extraction-agent`
- `coverage-decision-agent`

> [!IMPORTANT]
> The supplied workflow implementation is complete. Do not modify the Python code. The
> workflow reuses the agents above and does not create replacement agents.

The workflow calls each agent for one responsibility. Human review is regular workflow
logic and does not appear as an agent in Foundry.

## Task 2: Run the sequential workflow

```bash
cd docs
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --policy COMP-AUTO-001
```

This runs the approval path against the comprehensive policy. The workflow passes the
intake result and structured policy in memory, then prints the final decision.

Test the default liability-only denial path:

```bash
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg
```

Override the claim identifier and amount when needed:

```bash
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --policy COMM-AUTO-001 --claim-id CLM-2026-007 --amount 28000
```

If the decision is escalated or its confidence is below the configured threshold, the
workflow prompts you to approve, escalate, or deny it before printing the final result.

## How the workflow operates

| Step | Foundry resource | Input | Output |
|---|---|---|---|
| 1 | `claims-intake-agent` | OCR text from the accident statement | Structured claim and grounded statement context |
| 2 | `policy-extraction-agent` | Matching Markdown policy document | Typed policy coverage, limits, deductibles, and exclusions |
| 3 | `coverage-decision-agent` | Structured claim and structured policy | Approved, denied, or escalated coverage decision |
| 4 | None | Escalated or low-confidence decision | Human-confirmed or overridden final status |

The workflow cannot start Step 2 until the intake result supplies a policy number. Step
3 reuses the policy object produced by Step 2, so it does not extract the policy twice.

## Expected console output

```text
Claims Sequential Workflow
  Endpoint : https://<resource>.services.ai.azure.com/api/projects/<project>
  Model    : gpt-5.4
    Image    : <repo>/data/claims/crash1/raw/statements/crash1_front.jpeg
  Policy   : COMP-AUTO-001
  Claim ID : CLM-2026-001

    [Step 1] claims-intake-agent running...
    [Step 1] Intake complete.
    [Step 2] policy-extraction-agent running...
    [Step 2] Policy extraction complete.
    [Step 3] coverage-decision-agent running...
    [Step 3] Coverage decision complete.

--- Final Decision ---
{
    "claim_id": "CLM-2026-001",
    "status": "APPROVED",
    "policy_info": {
        "policy_number": "COMP-AUTO-001"
    },
    "coverage_decision": {
        "is_covered": true,
        "applicable_deductible": 500.0,
        "approved_amount": 14500.0,
        "confidence_score": 0.97,
        "requires_escalation": false
    }
}

============================================================
CHALLENGE 3 COMPLETE
============================================================
    Step 1 - claims-intake-agent        complete
    Step 2 - policy-extraction-agent    complete
    Step 3 - coverage-decision-agent    complete
    Step 4 - human review (conditional) not required
```

## Validation checklist

- The console lists the three agent steps in order.
- No agent named `claims-intelligence-agent` is created by Challenge 3.
- The final output contains `policy_info` from the extraction agent and
    `coverage_decision` from the decision agent.
- `status` is `APPROVED`, `DENIED`, or `ESCALATED`.
- `approved_amount` uses the deductible and limit extracted from the real policy file.
- The liability-only command returns `DENIED` with `collision` or
    `own_vehicle_damage` in `exclusions_matched`.
- Human review runs only for an escalated or low-confidence decision.

## Next step

Continue with [Challenge 4](./challenge-04.md) to harden this pipeline against prompt injection and data exfiltration using FIDES.
