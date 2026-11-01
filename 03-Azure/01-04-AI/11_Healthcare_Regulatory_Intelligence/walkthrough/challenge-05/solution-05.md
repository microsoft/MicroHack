# Challenge 5 solution: Executive Briefing and human sign-off

**[← Previous Solution](../challenge-04/solution-04.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-05.md) - [Next Solution →](../challenge-06/solution-06.md)

**Duration:** 60 minutes

## Expected portfolio briefing (shape)

**By region**

| Region | Changes | Biggest risk | Nearest regulator date |
|---|---|---|---|
| EU | EU-SA-2027-004, EU-GD-2027-011 | Liver warning on both products | DHPC 1 Mar 2027 |
| UK | UK-SA-2027-002, UK-REG-2027-001, UK-PR-2027-001 | Label variation and PSUR procedure | UK variation 29 Mar 2027 |
| US | US-EL-2027-007, US-REG-2027-003, US-CD-2027-015 v2 | Pen supply depends on CMO-17 | Payer evidence 1 Mar 2027 |

**By portfolio**: CDX-TAB is affected by seven changes (both safety alerts, nitrosamines, payer, pricing, trial summary and PSUR). CDX-PEN is affected by the EU alert and the warning letter.

**Risks**: pen supply (CMO-17 findings, open DEV-2026-114, no second site, overdue re-audit) and the liver-injury label and DHPC timeline should both be RED or AMBER; pricing GREEN or AMBER. Which risk gets RED varies between runs and is a good discussion point.

**Deadlines** (regulators' dates only): DHPC 1 Mar, US payer evidence 1 Mar, EU guidance on trial summaries applies 1 Mar, EU variation 15 Mar, UK variation 29 Mar, UK payment rate and US tier change 1 Apr, UK PSUR rule 1 Jul, nitrosamines 1 Aug. **Coverage:** all eight applicable changes, with EU-GD-2027-019 listed as out of scope.

Why no internal dates here: in our test run the briefing agent recalculated internal dates for ten rows at once and got several wrong (for example the DHPC internal date as 1 March and the UK forecast as 30 January). The impact agent calculates them per change, and the sign-off tool records them.

**Progress** (before any sign-off): TASK-2026-041 in progress; TASK-2026-044 **open and at risk**; TASK-2026-047 done.

EU-GD-2027-019 is omitted because it does not apply.

## Expected sign-off record for EU-SA-2027-004

```json
{
  "change": "EU-SA-2027-004 v1",
  "decision": "approved",
  "approver_role": "Regulatory Affairs Lead",
  "approved_by": "Alex Example",
  "note": "Approved with DHPC brought forward",
  "tasks": [
    {"title": "Update EU label text with the liver-injury warning (4.4, 4.8, leaflet)", "domain": "labelling", "region": "EU", "owner_role": "Labelling Lead", "due": "2027-03-01", "citation": "EU-SA-2027-004 v1 p2"},
    {"title": "Agree DHPC with the regulator and send to prescribers", "domain": "vigilance", "region": "EU", "owner_role": "Pharmacovigilance Lead", "due": "2027-02-15", "citation": "EU-SA-2027-004 v1 p4"},
    {"title": "Add liver injury to the RMP and next PSUR", "domain": "vigilance", "region": "EU", "owner_role": "Pharmacovigilance Lead", "due": "2027-02-11", "citation": "EU-SA-2027-004 v1 p5"}
  ]
}
```

Recording it prints `Tasks created: TASK-2027-001, TASK-2027-002, TASK-2027-003`: one ID per task. Plans that also list the variation submission (Regulatory Affairs Lead, labelling, 2027-03-01) or split the RMP and PSUR get four or five IDs, which is fine. The DHPC task is usually `TASK-2027-002`, the one Part C marks as done, and the decision is written to `lake-raw/tracking/audit-log.jsonl` with a SHA-256 of the exact JSON that was approved.

## Expected refusals (Part D)

| Attempt | Message contains |
|---|---|
| `US-CD-2027-015 v1` | `was superseded on 2027-01-12. Re-assess the current version` |
| Citation `p9` | `is not a paragraph in the lake` |
| `approved_by: briefing-agent` | `must be the person who made the decision, not an agent` |
| Same sign-off twice | `already has a recorded decision` |
| Warning-letter plan without `quality_approval_by` | `Manufacturing tasks also need 'quality_approval_by'` |
| Bare `APPROVE` (the agent still writes JSON, with `approved_by` empty) | `'approved_by' is empty. A decision needs a person` |
| Domain `regulatory submissions` | `unknown domain` |
| Citation range such as `p2–p3` | `is not a paragraph in the lake` |

The tool checks the content of the record before it checks for an earlier decision, so participants who try the `p9` citation on the plan they already approved still see the citation error.

Discussion answer: instructions guide a model, but they can be ignored or misread. **Code enforces the rules every time**, and an auditor can read and test it (see `tests/test_signoff.py`).

## Model settings

`briefing-agent` uses **Reasoning Effort: medium**, like `impact-agent`. See [Challenge 3 solution](../challenge-03/solution-03.md#model-settings-why-medium-reasoning) for the comparison and why temperature is not offered.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| The briefing covers only some of the changes | The agent retrieved a few strong matches and stopped. In early test runs it missed the warning letter or the trial summary; in a later run, the UK pricing change | The instructions make it check every current document in `change-log.md` against *By region* and the closing line; with that check, 5 of our last 6 test runs covered all eight, and the sixth missed only the trial-summary guidance. Counting the IDs is part of the review. Check the instructions were saved and ask again in a new chat |
| The out-of-scope veterinary guidance appears in *By region* or *Deadlines*; the deadlines table lists publication dates or tasks; the nitrosamine rule is linked to the pen | Normal run-to-run variation in a long one-page summary | Treat it as a review exercise: the briefing is a draft for leadership, so ask participants to find what is wrong before it is sent. The nitrosamine rule covers tablets and capsules only |
| Plan shows domain *regulatory submissions* | Older versions of `owners.md` listed submissions as a sixth domain. It now says submissions are recorded under the domain of the change | If an agent still does it, the sign-off tool refuses it: ask for `MODIFY <task #> domain labelling` |
| A due date is the regulator's own deadline (for example 2027-03-15), or a day off (2027-02-14) | The model skipped or slipped on the subtraction | The Rule column shows the arithmetic: check it before approving and use MODIFY. In our final test runs 3 of 4 plans had every date right |
| Sign-off refuses a citation such as `EU-SA-2027-004 v1 p2–p3` | The agent cited a range of paragraphs | The instructions ask for one paragraph per citation. MODIFY the task to one paragraph, for example `p2`, or edit the JSON before running the tool |
| Asked for a plan again, the agent says the tasks are *already captured in the task register* | Correct: the instruction not to repeat existing tasks | Nothing to fix. Use `regintel task` to update progress instead |
| The agent says "tasks created" | It ignored the instruction "Never claim that tasks were created" | Nothing exists until the sign-off command succeeds |
| JSON contains extra text or comments | Copied more than the JSON block | Copy only the JSON block; the tool reports invalid JSON clearly |
| `owner_role must be one of …` | The agent used a role that is not in `owners.md` | MODIFY the task |
| Progress not visible to the agent: it lists only the three 2026 tasks | The indexer was not re-run after `signoff` or `task`. The lake is correct; the index is stale | Re-run `caldova-lake-indexer`, wait for Success, start a **new** chat. If the row under the answer shows only `message` (no `kb-caldova-regulatory-…` call), the agent answered from the conversation, not the lake |
| Cloud Shell timed out between steps | Cloud Shell without storage starts empty | Clone again; `--account` makes the tool download the state and the task register first |
