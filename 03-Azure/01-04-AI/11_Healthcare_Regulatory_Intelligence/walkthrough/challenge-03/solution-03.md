# Challenge 3 solution: Obligation & Impact Extractor

**[← Previous Solution](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-03.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 75 minutes

Caldova's due-date rules (`internal/owners.md`), first match wins: **an SOP time limit counted from today**; otherwise **deadline − 14 days**; otherwise **effective date − 30 days**, only for an effective date after today; otherwise **today + 30 days**. A deadline set for another organisation (CMO-17's reply) is not a Caldova deadline. *Today* is the *Status as of* date in `tracking/task-register.md`: **12 January 2027** after Tuesday's crawl, so rule 4 gives **11 February 2027**. The safety alert took effect on 11 January, before today, so rule 3 does not apply to its RMP action. A past due date means **at risk**. Label text belongs to the Labelling Lead; preparing and submitting the variation belongs to the Regulatory Affairs Lead.

## EU-SA-2027-004: applies to CDX-TAB and CDX-PEN (EU)

| # | Obligation | Deadline | Domain | Citation | Affected items | Owner | Internal due |
|---|---|---|---|---|---|---|---|
| 1a | Update the label text: SmPC 4.4 and 4.8 and the package leaflet | variation by 15 Mar 2027 | labelling | v1 p2, p3 | LBL-EU-TAB v7, LBL-EU-PEN v4, SOP-LAB-001 | Labelling Lead | **1 Mar 2027** (rule 2) |
| 1b | Prepare and submit the EU variation | 15 Mar 2027 | labelling | v1 p3 | SUB-2026-011 (precedent) | Regulatory Affairs Lead | **1 Mar 2027** (rule 2) |
| 2 | Agree a DHPC and send it to prescribers | 1 Mar 2027 | vigilance | v1 p4 | SOP-PV-005 | Pharmacovigilance Lead | **15 Feb 2027** |
| 3 | Add liver injury to the RMP and next PSUR | none stated | vigilance | v1 p5 | SUB-2027-003 (RMP, no date), CAL-401 | Pharmacovigilance Lead | **11 Feb 2027** (rule 4) |

**Must be right in every run:** applicability to both products, the two EU labels, `SUB-2027-003`, `SOP-PV-005` and the four internal due dates above with the rule that produced each one. Participants who added the date rule after a first run (as in our test) should see the dates change from missing to correct.

**May vary between runs** (normal for a language model; don't fail a run for missing one): `CAL-401`, `SOP-LAB-001`, `SOP-PV-003`, extra actions such as *align medical review*, and the points below. In our test runs `CAL-401` appeared in one run and not the next.

Good answers also notice:

- A label variation normally takes **6 weeks** (`submissions.md`). Starting on 11 January finishes around 22 February, inside the 1 March internal date but with little slack.
- **History** (`history.md`): in 2026 Caldova updated EU, UK and US labels together. The US labels (`LBL-US-TAB`, `LBL-US-PEN`) are *not* required by this EU alert; aligning them is a question for experts.

## US-EL-2027-007: applies to CDX-PEN through CMO-17

- `quality-records.md`: CMO-17 fills **all** EU and US CDX-PEN supply, there is **no second site**, and deviation **DEV-2026-114** (particles in lot P-2611) is open. The letter's finding 1 is about particles [v1 p2].
- `SOP-QA-010`: assess a regulator finding within **14 calendar days**: 12 January + 14 = **26 January 2027** (rule 1). Owner: **Quality Head**. Check the arithmetic in the answer: models often slip on date calculations, which is one reason a person reviews every date at sign-off. Caldova's rules use calendar days to keep the calculation simple.
- Existing task **TASK-2026-044** (CMO-17 re-audit, due 15 December 2026) is **at risk**. The agent should escalate it, not duplicate it.
- The 15-working-day response [v1 p4] is **CMO-17's** obligation, not Caldova's. Good answers keep the two apart.

## UK-REG-2027-001: applies (UK authorisation holder)

- No product is named, but Caldova holds `PL 54321/0001` in the UK.
- `SOP-PV-003` says 70 or 90 days and must be changed: effective **1 July 2027**, so the internal due date is **1 June 2027**. Owner: Pharmacovigilance Lead.
- `SUB-2027-002` (data lock 31 July 2027, planned 20 October = 81 days) breaks the new **60-day** rule. It must be submitted by **29 September 2027**.

## EU-GD-2027-019: does not apply

Veterinary medicines only [v1 p1, p3]. Caldova has no veterinary products. No actions should be proposed. The monitor tagged it `labelling` because of the word *carton*; tags help filtering but are not a decision.

## Other changes, for coaches

| Change | Expected result |
|---|---|
| UK-SA-2027-002 | CDX-TAB only (`LBL-UK-TAB`); variation by 29 Mar 2027, internal due 15 Mar 2027; serious cases reported within 15 days |
| EU-GD-2027-011 | CAL-301 ended 30 Jun 2026; plain-language summary **not started**; due 30 Jun 2027 (12 months after the trial ended), internal due 16 Jun 2027 (rule 2); update SOP-CT-002; owner: Clinical Disclosure Lead. Agents often use the guidance's 1 March effective date instead (rule 3, 30 Jan 2027), because the deadline has to be worked out from `studies.md`. Accept it only if the Rule column says so and the approver agrees; it is a good review point |
| US-REG-2027-003 | CDX-TAB; confirm by 1 Aug 2027, internal due 18 Jul 2027 (rule 2: *by 1 August* is a deadline). The rule also takes effect on 1 August, so some runs apply rule 3 and give 2 Jul 2027; the Rule column shows which. CAPA-2026-031 in progress; **existing TASK-2026-041**; owner: Quality Head |
| US-CD-2027-015 v2 | CDX-TAB; evidence by 1 Mar 2027, internal due 15 Feb 2027; update MA-US-DOSSIER v3; tier 3 from 1 Apr 2027; owner: Market Access Lead |
| UK-PR-2027-001 | CDX-TAB; MA-UK-FORECAST assumes 15.3%, now 18.5% from 1 Apr 2027; internal due 2 Mar 2027; owner: Market Access Lead |

## Part E: measuring the agent

Expected results with the current data and instructions, from our test runs:

| Setting | Warning letter, fully right | Notes |
|---|---|---|
| medium | almost always 3 of 3 | Our 7-run comparison across three changes: 7 of 7 with every date right |
| low | usually 2 or 3 of 3 | Same comparison: 6 of 7. Misses are a wrong or missing SOP-QA-010 date, or 2027-02-11 (today + 30) instead of 2027-01-26 |

With only three runs each, teams may see no difference, or even low ahead of medium. That is the point of the discussion: a handful of runs cannot prove much, so real evaluation needs a fixed set of questions with expected answers, run many times. The coach tables in this walkthrough are such a set, and Foundry evaluations can run it automatically.

If a team's medium runs miss check 4, look at the trace: `internal/sops.md` was not retrieved. Point back to Part D.

Make sure every team sets **Reasoning Effort** back to **medium** and saves before Challenge 5.

## Model settings: why medium reasoning

`gpt-5.4-mini` is a reasoning model. The agent's **Parameters** panel offers **Reasoning Effort** but not **temperature**: the model accepts a temperature only when reasoning effort is `none`, so the portal hides it. We compared settings on the same fresh lab, asking `impact-agent` to assess EU-SA-2027-004 (3 runs), US-EL-2027-007 (2) and UK-REG-2027-001 (2):

| Setting | Runs with every due date right | Output tokens per answer |
|---|---|---|
| Reasoning `none`, temperature 0 | 3 of 7 (missed SOP-QA-010 twice, wrong subtractions) | about 1,600 |
| Reasoning `low` (portal default) | 6 of 7 | about 2,300 |
| Reasoning `low`, tools set to *Required* | 7 of 7, but every EU-SA run left out the variation task | about 2,100 |
| Reasoning `medium` | **7 of 7**, complete | about 9,500 |

For `briefing-agent`, medium covered all eight changes in 2 of 2 briefings (low: 1 of 2) and takes about 70 seconds instead of 20.

Teaching point: temperature 0 makes an answer **repeatable**, not **right**. A model that does not reason gives the same wrong date every time. What reduced the errors was letting the model think (reasoning effort) and giving it clear rules and findable records, not removing randomness.

If participants left an agent on low, answers are still mostly right; ask them to switch to medium when they see a date that does not match its rule. A Standard deployment of 200K tokens per minute is plenty for one participant. Running several medium agents at once, as in Challenge 6, can hit the limit: wait a minute and run again.

## Troubleshooting

| Symptom | Fix |
|---|---|
| The agent says the warning letter does not apply | Ask: "Which products does CMO-17 make for Caldova?" If it can, it should find `quality-records.md`. Reinforce the instruction to search **internal records** too |
| Invented record IDs (for example `SOP-PV-009`) | Compare with `internal/sops.md`; check that the trace retrieved internal files |
| Dates without the rule | Ask for the "How the date was calculated" column; it must quote the owners.md rule |
| Warning letter action due 2027-02-11 (today + 30 days), or another date, instead of 2027-01-26 | The agent never retrieved `SOP-QA-010`, so it could not apply the SOP time limit. The instructions tell it to search `internal/sops.md` for each action; check they were saved. Ask *Which SOP governs assessing a regulator finding at a contract manufacturer?* to show the retrieval it missed |
| Proposes a new nitrosamine task | It missed `tracking/task-register.md`; ask it to check existing tasks |
