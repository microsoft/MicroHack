# Challenge 6 solution: Post-contact analytics and supervisor insights

**[← Previous Solution](../challenge-05/solution-05.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-06.md) - [Next Solution →](../challenge-07/solution-07.md)

**Duration:** 50 minutes

## Part A and B: Content Understanding

Part A uses the **Call center** prebuilt with the lab's `gpt-5.4` deployment. On `KC-CALL-02` it returns a summary (outage since Monday, third call, works from home, known ZZ4 outage, fix Thursday 18:00, automatic compensation, high-priority case), sentiment **Negative**, topics (broadband outage, compensation, escalation, callback) and the people (Priya as account holder, her husband, the agent).

Part B's scorecard project (`contact-call-scorecard` in CU Studio) adds the fields to the Call Center template. Our portal run on `KC-CALL-02` returned: intent *Report outage*, `identity_checked` **true**, `resolved` **true**, `escalated` **true**, `vulnerability_signs` *distressed and relies on broadband for work, but no clear vulnerability disclosed*, `empathy_score` **4**, and a next action to monitor the case and call back. Two of those are good discussion points:

- `identity_checked` is true, yet the caller was the account holder's **husband**. The adviser checked the details and then rightly limited what she shared. A yes/no field can't tell "checked and was the account holder" from "checked and wasn't"; a better schema asks *who* was verified.
- `resolved` is true while the outage is still on. The model read "the customer got what they needed today"; a supervisor might read "the problem is fixed". Tighten the description.

Earlier API runs on all three telco calls:

| Call | sentiment | intent | identity_checked | resolved | escalated | vulnerability_signs | empathy_score |
|---|---|---|---|---|---|---|---|
| `KC-CALL-01` First bill higher | positive | bill query | true | true | false | none | 4 |
| `KC-CALL-02` Broadband down three days | negative | broadband outage | true | true *or* false | true | *works from home* | 4 |
| `KC-CALL-03` Telecare alarm | neutral | internet outage | true | true *or* false | true | alarm pendant relies on the internet; sounded worried | 4 |

The transcript separates the two voices as **Speaker 1** (adviser) and **Speaker 2** (customer), with timestamps. Calls are about 60 to 80 seconds and take under a minute to analyse.

Things to point out:

- **`resolved` changed between runs** for calls 02 and 03. Is a call *resolved* when the outage is still on but the customer got what they needed? The field description doesn't say, so the model guesses. Fix it by tightening the description, for example *True only if nothing is left for the company to do*.
- **`vulnerability_signs` over-flagged call 02:** working from home is an impact, not a vulnerability. Again the description is the fix: list the kinds of vulnerability from article 002.
- **`empathy_score` is the field to trust least.** It's a judgement, and the same score for every call is a sign the model isn't discriminating. Use it to pick calls for a person to review, not to rate advisers.

The same pattern works for every industry: CALL-01 is a routine request, CALL-02 a frustrated customer affected by the week's trend, CALL-03 a vulnerable customer.

## Part C and D: supervisor insights

| Industry | Trend the supervisor should find | Missed identity checks |
|---|---|---|
| telco | `outage_fault`: 12 contacts, all in **ZZ4**, 3 to 6 March | `KC-C1008`, `KC-C1023` |
| energy | `billing_query`: 11 contacts, all in **ZZ2**, 2 to 6 March | `LE-C1005`, `LE-C1020` |
| bank | `scam_report`: 12 contacts across all areas, 3 to 7 March (the parcel-fee text scam) | `HB-C1012`, `HB-C1027` |
| insurance | `storm_damage`: 10 contacts, all in **ZZ3**, 2 to 5 March | `NI-C1010`, `NI-C1025` |
| retail | `late_delivery`: 11 contacts, all in **ZZ5**, 3 to 7 March | `PP-C1007`, `PP-C1022` |

In our telco run `supervisor-insights` listed the reasons with counts (outage/fault 12, moving home 7, billing and payment 6, engineer appointments 3, complaints 2). It identified the ZZ4 spike from 3 to 6 March and named `KC-C1008` and `KC-C1023`. Its recommended actions were tied to that evidence: review the ZZ4 outage communications and coach verification.

In our portal run the answers matched, with one slip worth showing: asked for the spike by day, it listed every ZZ4 contact, including four that were not outages (KC-C1003, KC-C1019, KC-C1023, KC-C1028), then said the cluster was "mainly" outages. The 3 to 6 March numbers were right. That is what *Check one answer against the contacts file* is for.

Ask groups to connect the dots: the trend in the supervisor's week matches the service notice the voice agent found in Challenge 3, and the call they analysed in Part A.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| **Model deployments required** when selecting Call center | Choose the deployments in the **Configure** panel: chat completion `gpt-5.4` (`AnalysisModelDeploymentName`), mini `gpt-5.4-mini`, embedding `text-embedding-3-large`. The portal does not offer the mini model for the full-size slot. Don't select **Deploy models**. |
| Upload area is greyed out and only a sample file shows | The models are not configured yet. Open **Configure** (gear icon) and choose them. |
| *The analyzerId cannot contain '-'* | Use `contactCallScorecard`, not `contact-call-scorecard`. |
| Content Understanding asks for default models every time | Set the defaults once: completion `gpt-5.4-mini`, embedding `text-embedding-3-large`. |
| The supervisor answers about knowledge articles | It was given `contact-knowledge-kb` instead of `contact-insights-kb`. |
| The supervisor finds only one missed check | Retrieval returned part of the digest. Ask the question on its own (*Which contacts scored 1 for verification?*); it usually finds both. |
