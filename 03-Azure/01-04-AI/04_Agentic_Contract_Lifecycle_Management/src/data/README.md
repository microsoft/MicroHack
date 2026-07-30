# CLM Corpus (Contoso Global)

Seed data for the microhack, kept **under Challenge 1** — where it is provisioned and seeded.
Challenge 1 hosts these PDFs in a **SharePoint** document library and crawls them into Azure AI Search
(via a SharePoint Online indexer) so the **Foundry IQ** knowledge base can ground the agents with cited
answers. Every challenge reads this corpus through `clm_common.config.DATA_DIR` (which points at
`src/data/`).

The contract corpus is delivered as **PDF** — real, text-extractable documents that mirror how
a CLM system ingests exchanged legal paper. The SharePoint indexer extracts text at crawl time; the
Clause & Risk agent also reads drafts locally via `clm_common.documents.read_document_text` (pypdf).

| Folder | Contents | Used by |
|--------|----------|---------|
| `contract_templates/` | Approved **NDA / MSA / SOW** templates (PDF) | Intake & Drafting agent (Ch2) |
| `clause_library/` | `standard_clauses.pdf` — enterprise-standard positions (CL-01…CL-12) | Clause & Risk agent (Ch4) |
| `policies/` | `contracting_policy.pdf` + `delegation_of_authority.pdf` (approval thresholds, signature matrix, no-legal-advice rule) | All agents (grounding + guardrails) |
| `contracts/` | 5 **executed** contracts (PDF), one per row in `contracts_seed.json` | Clause & Risk (Ch4), status/renewal tools |
| `counterparty_drafts/` | `acme_msa_draft.pdf`, `globex_nda_redline.pdf` — **inbound** drafts full of red flags | Clause & Risk agent (Ch4) |
| `playbooks/` | `negotiation_playbook.pdf` — fallback positions + escalation | Intake & Drafting (Ch2), grounding |
| `evaluation/` | `evaluation_dataset.jsonl` + `adversarial_prompts.jsonl` | Evaluation (Ch3), safety (Ch6) |
| `contracts_seed.json` | Structured contract metadata (status, renewal, risk, owner) | Contract-status / renewal tools |

## Regenerating the PDFs

The PDF text lives in a build-time generator so it is reviewable in source control:

```bash
pip install reportlab            # build-time only; not a runtime dependency
python src/scripts/make_corpus_pdfs.py
```

This rewrites every PDF under `src/data/`. The executed contracts and inbound drafts
carry **deliberate, graded deviations** from the clause library (e.g. Soylent: Ireland law +
perpetual confidentiality + 3-month cap; Umbrella: EXPIRED) so the Clause & Risk agent has
real risk to flag.

## Evaluation dataset shape

Each line is one JSON object:

```json
{"query": "...", "ground_truth": "...", "context": "...", "category": "grounded_qa"}
```

Categories: `grounded_qa` (answerable + cited), `clause_risk` (compare to standard),
`refusal` (must decline legal advice), `tool_call` (must call the contract-status tool).
At eval time a `target` callable generates the `response`; evaluators score it against
`context` (groundedness) and `ground_truth` (relevance/correctness).
