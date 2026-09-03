---
title: "Solution 04: Orchestrate the Two-Agent Claims Workflow"
description: "Solution walkthrough for running the two-agent sequential claims workflow"
---

[Home](../../README.md) | [Challenge 04](../../challenges/challenge-04.md) | [Previous solution](../challenge-03/solution-03.md) | [Next solution](../challenge-05/solution-05.md)

## Outcome

This solution runs the intake and intelligence agents in sequence and enters human
review only when the decision is escalated or its confidence is below the configured
threshold.

## Prerequisites

* Complete Challenges 02 and 03
* Confirm that both Foundry agents exist
* Use an interactive terminal in case human review is requested

## Run the solution

From the repository root, run the covered comprehensive policy case:

```bash
cd docs
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg \
  --policy COMP-AUTO-001
```

Run the default liability-only case:

```bash
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg
```

Exercise a different policy and claim amount:

```bash
python claims-sequential-workflow.py ../data/claims/crash1/raw/statements/crash1_front.jpeg \
  --policy COMM-AUTO-001 --claim-id CLM-2026-007 --amount 28000
```

## Expected result

The console displays Steps 1 and 2 in order and then prints an `APPROVED`, `DENIED`, or
`ESCALATED` workflow result. Step 3 appears only when human review is required. For a
low-confidence or escalated result, the workflow enters `PENDING_HUMAN_REVIEW` and
waits until you enter `approve`, `escalate`, or `deny`. Invalid input displays the
prompt again.

## Troubleshooting

* If the project endpoint is missing, configure `FOUNDRY_PROJECT_ENDPOINT` or
  `AI_FOUNDRY_PROJECT_ENDPOINT`
* If a human-review prompt fails in automation, rerun in an interactive terminal
* If an agent is missing, rerun the setup steps from Solutions 02 and 03

## Validation checklist

* [ ] The two agents run in the documented order
* [ ] The workflow reuses the existing `claims-intelligence-agent` Foundry resource
* [ ] The final result contains policy and coverage objects
* [ ] The liability-only execution is denied
* [ ] Human review runs only when its condition is met
* [ ] A requested review waits for valid input before the workflow completes

Continue with [Challenge 05](../../challenges/challenge-05.md) and its
[solution](../challenge-05/solution-05.md).
