# Finish solution: Estimate the impact and clean up

**[← Previous Solution](../challenge-08/solution-08.md)** - [Home](../../README.md) - [Challenge](../../challenges/finish.md)

**Duration:** 15 minutes

## Worked example

There is no single right answer. With the assumptions in the challenge and a routine share of 50%:

| Step | Calculation | Result |
|---|---|---|
| Routine contacts | 1,200,000 × 50% | 600,000 |
| Resolved by the agent | 600,000 × 50% | 300,000 |
| Saving per contact | 6.00 − 0.60 | 5.40 pounds |
| Yearly saving | 300,000 × 5.40 | **about 1.6 million pounds** |

Good groups challenge the assumptions: containment of 50% is optimistic for a first release; some "resolved" contacts come back; and the agent's cost should include the platform, not just tokens.

## Quality checks

Each pack's week has 30 contacts with **two** missed identity checks. A 2% sample reviews fewer than one contact a week, so it has roughly a 4% chance of catching either of them. Post-contact analytics scores every call, so both are found in the same week. That is the strongest argument in this hack, and it doesn't depend on any containment assumption.

## Handoffs

The customer no longer repeats their story. For a vulnerable customer that is the difference between a regulator's example of good practice and a complaint. Groups should mention the regulator for their industry: Ofcom (telco), Ofgem (energy), the FCA (bank and insurance) and consumer law (retail).

## Before going live

Expect answers such as: an evaluation on far more than ten questions, including real anonymised transcripts; no failures on identity rows; tested handoff for every vulnerability type in article 002; latency targets for voice; and a pilot with human review of every call.

## Clean up

Facilitators delete the lab resource group. If you're testing outside the platform, also **purge** the soft-deleted Foundry account, or its model quota stays reserved:

```bash
az cognitiveservices account purge -l <location> -n <FoundryAccountName> -g <ResourceGroupName>
```
