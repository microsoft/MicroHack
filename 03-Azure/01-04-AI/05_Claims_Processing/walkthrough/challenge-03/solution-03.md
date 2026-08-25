---
title: "Solution 03: Orchestrate the Claims Workflow"
description: "Solution walkthrough for running the three-agent sequential claims workflow"
---

[Home](../../README.md) | [Challenge 03](../../challenges/challenge-03.md) | [Previous solution](../challenge-02/solution-02.md) | [Next solution](../challenge-04/solution-04.md)

## Outcome

This solution runs the intake, policy extraction, and coverage decision agents
in sequence and enters human review only when the decision is escalated or its
confidence is below the configured threshold.

## Prerequisites

* Complete Challenges 01 and 02
* Confirm that all three Foundry agents exist
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

The console displays Steps 1 through 3 in order and then prints an `APPROVED`,
`DENIED`, or `ESCALATED` workflow result. Step 4 appears only when human review
is required.

## Troubleshooting

* If the project endpoint is missing, configure `FOUNDRY_PROJECT_ENDPOINT` or
  `AI_FOUNDRY_PROJECT_ENDPOINT`
* If a human-review prompt fails in automation, rerun in an interactive terminal
* If an agent is missing, rerun the setup steps from Solutions 01 and 02

## Validation checklist

* [ ] The three agents run in the documented order
* [ ] No separate `claims-intelligence-agent` Foundry resource is created
* [ ] The final result contains policy and coverage objects
* [ ] The liability-only execution is denied
* [ ] Human review runs only when its condition is met

Continue with [Challenge 04](../../challenges/challenge-04.md) and its
[solution](../challenge-04/solution-04.md).
