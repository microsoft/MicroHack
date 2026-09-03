---
title: "Solution 02: Build the Claims Intake Agent"
description: "Solution walkthrough for indexing claim statements and running the grounded Claims Intake Agent"
---

[Home](../../README.md) | [Challenge 02](../../challenges/challenge-02.md) | [Next solution](../challenge-03/solution-03.md)

## Outcome

This solution indexes the ten supplied claim statement images, creates the
`crash-statements-kb` knowledge base, and runs the Claims Intake Agent against a
sample statement.

## Prerequisites

* Receive a provisioned lab and its credentials from the MicroHack platform or coach
* Run `uv sync` from the repository root
* Copy `.env.example` to the repository-root `.env` and add the supplied values
* Authenticate to Azure for `DefaultAzureCredential`

## Run the solution

From the repository root, populate the search index:

```bash
cd docs
python index_crash_statements.py
```

Confirm that all ten statement images were indexed:

```bash
curl "$FOUNDRY_IQ_SEARCH_ENDPOINT/indexes/crash-statements/docs/\$count?api-version=2023-11-01" \
  -H "api-key: $FOUNDRY_IQ_SEARCH_KEY"
```

Create the Foundry IQ knowledge source and knowledge base:

```bash
python create_knowledge_base.py
```

Run the intake agent and save its output:

```bash
python claims-intake-agent.py ../data/claims/crash1/raw/statements/crash1_front.jpeg \
  --output ../data/claims/crash1/derived/statements/crash1_front.intake.json
```

## Expected result

The index count is `10`. The generated intake artifact reports `status:
success` and contains OCR text, extracted claim data, Foundry IQ search results,
and an agent summary. At least one result should reference
`crash1_front.jpeg`.

## Troubleshooting

* For missing Mistral configuration, check the `MISTRAL_DOCUMENT_AI_*`
  environment variables returned by the deployment
* For missing search credentials, check `FOUNDRY_IQ_SEARCH_ENDPOINT` and
  `FOUNDRY_IQ_SEARCH_KEY`
* For zero matches, rerun the indexing command and use a statement JPEG rather
  than a vehicle-damage photograph

## Validation checklist

* [ ] The search index contains ten documents
* [ ] The `crash-statements-kb` knowledge base exists
* [ ] The `claims-intake-agent` appears in the Foundry project
* [ ] The intake artifact contains OCR, extracted data, search results, and an agent summary
* [ ] At least one matching statement is returned

Continue with [Challenge 03](../../challenges/challenge-03.md) and its
[solution](../challenge-03/solution-03.md).
