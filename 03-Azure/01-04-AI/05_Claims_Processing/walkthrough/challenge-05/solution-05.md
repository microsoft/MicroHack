---
title: "Solution 05: Harden the Claims Pipeline with FIDES"
description: "Solution walkthrough for blocking prompt injection and data exfiltration"
---

[Home](../../README.md) | [Challenge 05](../../challenges/challenge-05.md) | [Previous solution](../challenge-04/solution-04.md)

## Outcome

This solution applies FIDES controls after the trusted Challenge 04 decision,
then verifies that claimant-authored instructions cannot trigger an unauthorized
payout or disclose private policyholder data.

## Prerequisites

* Complete Challenge 04
* Configure the Foundry endpoint and model environment variables
* Install the required Agent Framework versions

## Run the solution

Synchronize the pinned root environment:

```bash
uv sync
```

Run the clean and adversarial scenarios:

```bash
cd docs
python claims-security-hardening.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --scenario clean
python claims-security-hardening.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --scenario inject-payout
python claims-security-hardening.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --scenario inject-exfiltration
python claims-security-hardening.py ../data/claims/crash1/raw/statements/crash1_front.jpeg --scenario inject-payout --auto-hide
```

## Expected result

Challenge 04 runs before the secured action agent. The injected payout is not
issued, private policyholder data is not sent through the public notification
tool, and the FIDES audit log records attempted protected actions.

## Troubleshooting

* For dependency errors, confirm versions `1.13.0` and `1.10.4` are installed
* If execution stops before FIDES, complete any conditional human review
* If `--auto-hide` fails, verify that `FOUNDRY_QUARANTINE_MODEL` names a deployed
  model

## Validation checklist

* [ ] Challenge 04 completes before secured actions begin
* [ ] The injected payout is blocked
* [ ] SSN and prior-claims data are not exposed
* [ ] The audit log records blocked protected calls
* [ ] Auto-hide prevents raw attack text from reaching the main model
