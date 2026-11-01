# Challenge 4 solution: Regulatory Q&A Assistant

**[← Previous Solution](../challenge-03/solution-03.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-04.md) - [Next Solution →](../challenge-05/solution-05.md)

**Duration:** 45 minutes

## Expected answers

| Question | Expected answer | Sources |
|---|---|---|
| UK label of the injection pen? | No change needed: CDX-PEN is **not authorised in the UK**. The UK alert affects `LBL-UK-TAB`, with a variation by 29 March 2027 | (products.md, CDX-PEN); [UK-SA-2027-002 v1 p2] |
| Next UK PSUR? | Data lock 31 July 2027 + 60 days = **29 September 2027**. The planned 20 October date (`SUB-2027-002`) would be late, and `SOP-PV-003` still says 70/90 days | [UK-REG-2027-001 v1 p2]; (submissions.md, SUB-2027-002); (sops.md, SOP-PV-003) |
| Which payer policy version? | **v2**, published 12 January 2027; v1 is superseded | [US-CD-2027-015 v2 p1] |
| Dose with liver disease? | Not in the lake; no advice; ask a qualified medical professional or the Pharmacovigilance Lead | n/a |

## What good drafts look like

- **Email** to the Labelling Lead: subject naming EU-SA-2027-004; what changed; affected labels `LBL-EU-TAB` and `LBL-EU-PEN`; variation deadline 15 March 2027 and internal due date 1 March; citations p2 and p3; a request to start SOP-LAB-001.
- **Change request** for SOP-PV-003: current text "within 70 or 90 days"; proposed text "within 60 days of the data lock point from 1 July 2027"; reason UK-REG-2027-001 v1 p2; also affects SUB-2027-002; owner Pharmacovigilance Lead; due 1 June 2027.
- **Notice (DHPC)**: audience prescribers; key message liver injury reported; check liver function before treatment and after 3 months; states that the regulator must agree the text first [EU-SA-2027-004 v1 p4].
- **Label update** for LBL-EU-TAB section 4.4: current "Hypersensitivity; pregnancy"; proposed addition of a liver-injury warning with liver function tests before starting and after 3 months [v1 p2]; marked "Requires medical and regulatory review".

Reject a draft that invents clinical detail not in the source (for example, a frequency of liver injury), invents IDs, or says it was sent.

What our test run produced: all four drafts were well structured and marked for review, and the change request was exactly right. The label update and the DHPC both added *monitor for signs and symptoms of liver injury*, which is not in `EU-SA-2027-004 v1 p2`; the label update also gave the regulator's 15 March deadline instead of the internal 1 March date. These are good discussion points for Part D: plausible additions are the hardest errors to spot.

## Troubleshooting

| Symptom | Fix |
|---|---|
| The assistant gives dosing advice | Strengthen the "no medical advice" line and the "can't find it" rule; test again in a new chat |
| Drafts lack the DRAFT marker | Ask again with "use the draft format from your instructions"; check the instructions were saved |
| Answers and drafts show only numbered markers (①, ②…) | Expected: in our test runs the assistant cited with markers even when told to write paragraph labels | Accept it: each marker opens the lake file. Paragraph labels are enforced where they matter, by the sign-off tool in Challenge 5 |
| UK pen answer says "yes" | It relied on the EU alert naming both products. Ask it to check `products.md`; this is a good teaching moment about geography |
