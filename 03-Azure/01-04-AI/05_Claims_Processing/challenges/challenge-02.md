# Challenge 2 - Build the Claims Intelligence Agent

[Home](../README.md)

**Expected Duration:** 30 minutes

## Overview
In this challenge, you will build the Claims Intelligence Agent — the core decision-making component of the claims processing pipeline.

Like Challenge 1, this agent is built in two steps: first you create the agent with the Azure AI Foundry SDK, then you give it its enterprise need — real policy documents from your Storage account's `policies` container, instead of hardcoded mock data.

## From Mock Policies to Real Policy Documents

Enterprise claims adjudication starts with the model, but it only becomes useful when the model can read the same policy documents your organization uses. In this challenge, the policy-extraction agent is the generic reasoning component, and the Storage account `policies` container is the enterprise grounding layer that turns it into a real Claims Intelligence Agent.

In short: **policy text → policy-extraction agent → cached structured policy info → coverage decision agent**. The policy documents still hold the source-of-truth content; the agent is the layer that turns those documents into a typed policy object the adjudicator can reason over.

The Claims Intelligence Agent combines Policy Matching and Coverage Validation into a single orchestrated flow:

1. Retrieve the policy document that matches the claim's policy number from the Storage account and cache it.
2. Extract structured policy fields (coverage types, limits, deductibles, exclusions) from the raw policy document using a dedicated Foundry agent.
3. Run multi-factor coverage analysis using an LLM-backed adjudicator.
4. Apply the compliance rules engine to identify exclusions and limits.
5. Score how consistent the reported crash details are with the policy on a 1-100 scale, driving the approve/deny/escalate outcome.
6. Escalate edge cases with structured reasoning and severity levels.
7. Emit a detailed coverage decision with confidence scores, a consistency score, and a full audit trail.

> [!IMPORTANT]
> The supplied agent implementation is complete. Do not modify the Python code in this
> challenge. Run the commands below and validate each result.

## Task 1: Prepare the policy-extraction agent

Raw policy documents are unstructured Markdown. The supplied script uses a dedicated
`policy-extraction-agent` to convert them into structured coverage types, limits,
deductibles, and exclusions.

From the `docs` directory, run:

```bash
cd docs
python claims-intelligence-agent.py --setup-agent
```

The command checks whether `policy-extraction-agent` already exists in your Foundry
project. It creates the agent when needed or reuses the existing agent. Running the
command more than once does not create duplicate agents.

Expected result:

```text
Foundry agent 'policy-extraction-agent' is ready.
```

Open your Foundry project and confirm that `policy-extraction-agent` appears under
**Agents**. The agent has no attached tools because its only responsibility is to
extract structured fields from policy text supplied by the workflow.

## Task 2: Verify the enterprise policy documents

Run the policy verification command from the `docs` directory:

```bash
python claims-intelligence-agent.py --verify-policies
```

The command connects to the container configured by `AZURE_STORAGE_CONNECTION_STRING`
and `AZURE_POLICIES_CONTAINER_NAME`. It downloads the policy documents and discovers
each policy from its `**Policy Code:**` field.

Expected result:

```text
Found 5 policy document(s):
  - COMM-AUTO-001
  - COMP-AUTO-001
  - HV-AUTO-001
  - LIAB-AUTO-001
  - MOTO-001
```

This confirms that the Claims Intelligence Agent can retrieve the real policy documents
uploaded from [`data/policies/`](../data/policies/). Task 3 will select the document that
matches the intake artifact and send its text to the extraction agent from Task 1.

If the command reports that no policy documents were found, ask your coach to
verify the lab deployment and policy upload, then run the verification command
again.

## Task 3: Run the Claims Intelligence Agent

Feed the intake artifact produced by the Claims Intake Agent in [Challenge 1](./challenge-01.md) straight into the Intelligence Agent:

```bash
cd docs
python claims-intelligence-agent.py ../data/claims/crash1/derived/statements/crash1_front.intake.json
```

The command prints the coverage decision to the terminal. It does not save another
local JSON file.

The intake artifact's `policy_number` is `LIAB-AUTO-001` (Liability Only), so this run exercises the exclusion path: a liability-only policy denying a collision claim, with `own_vehicle_damage` or `collision` listed in `exclusions_matched`.

Optional — override the policy number to test the approval path:

```bash
python claims-intelligence-agent.py ../data/claims/crash1/derived/statements/crash1_front.intake.json --policy-number COMP-AUTO-001
```

Optional — override the claim amount to test the escalation path:

```bash
python claims-intelligence-agent.py ../data/claims/crash1/derived/statements/crash1_front.intake.json --policy-number LIAB-AUTO-001 --claim-amount 95000
```

When the adjudicator returns `"requires_escalation": true`, confirm that `state.errors` contains an `ESCALATION_REQUIRED` entry with severity `WARN`.

## What the agent does

1. Retrieves the raw policy document for the claim's policy number from the Storage account `policies` container and caches it.
2. Runs the `policy-extraction-agent` to parse structured coverage fields from the raw policy text into a `PolicyInfo` object, and caches that too.
3. Builds a contextualized decision prompt combining claim details and policy fields.
4. Submits the prompt to the LLM adjudicator, which evaluates type match, limits, deductibles, exclusions, and crash-to-policy consistency simultaneously.
5. Parses the structured JSON response into a typed `CoverageDecision` object:
   - Approved amount after deductible
   - Matched exclusions
   - Risk flags and confidence score
   - `consistency_score`: a 1-100 rating of how well the crash details line up with what the policy should cover, and therefore whether the claim should be approved
6. Escalates to `ESCALATED` status and records a `WARN`-severity error when the adjudicator signals manual review is needed.
7. Appends a complete audit trail entry for every significant action, including agent name, action type, outcome, and structured metadata (including the consistency score).

## Expected output shape

```json
{
  "claim_id": "CLM-2026-001",
  "status": "APPROVED",
  "policy_info": {
    "policy_number": "COMP-AUTO-001",
    "policy_type": "Comprehensive Auto Insurance",
    "coverage_types": ["collision", "comprehensive", "bodily_injury_liability", "property_damage_liability"]
  },
  "coverage_decision": {
    "is_covered": true,
    "coverage_percentage": 100,
    "applicable_deductible": 500.00,
    "approved_amount": 14500.00,
    "exclusions_matched": [],
    "reasoning": "The loss is consistent with a covered collision claim. Applying the collision deductible of $500 to the $15,000 claim results in an approved payment of $14,500.",
    "risk_flags": [],
    "confidence_score": 0.97,
    "consistency_score": 96,
    "requires_escalation": false
  },
  "audit_trail": [
    {
      "agent_name": "policy-extraction-agent",
      "action": "retrieve_policy",
      "status": "completed",
      "message": "Retrieved policy Comprehensive Auto Insurance",
      "metadata": { "retrieval_score": 1.0 }
    },
    {
      "agent_name": "coverage-decision-agent",
      "action": "validate_coverage",
      "status": "completed",
      "message": "Coverage decision: APPROVED",
      "metadata": {
        "approved_amount": 14500.00,
        "confidence_score": 0.97,
        "consistency_score": 96,
        "risk_flags": []
      }
    }
  ],
  "intelligence_duration_ms": 18118
}
```

## Validation checklist

- Policy retrieval succeeds from the Storage account `policies` container and the cache is populated on the first call.
- The `policy-extraction-agent` and `coverage-decision-agent` both appear under your Foundry project's agents.
- The LLM adjudicator returns a valid JSON decision with all required fields.
- `approved_amount` reflects the claim amount minus the applicable deductible, capped at the policy limit.
- The audit trail contains at least two entries: `retrieve_policy` and `validate_coverage`.
- Escalation path sets `status` to `ESCALATED` and populates `errors`.
- A liability-only policy correctly denies a collision claim and lists `own_vehicle_damage` or `collision` in `exclusions_matched`.
- `consistency_score` is an integer between 1 and 100 that agrees with the decision: scores below 30 do not coincide with `is_covered: true`, and scores of 90+ do not require escalation unless a hard policy limit is exceeded.

## Next step

Continue with [Challenge 3](./challenge-03.md) to orchestrate the three Foundry agents from Challenges 1 and 2 as one sequential workflow.

