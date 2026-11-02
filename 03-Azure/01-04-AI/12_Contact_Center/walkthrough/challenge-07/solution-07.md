# Challenge 7 solution: Measure quality

**[← Previous Solution](../challenge-06/solution-06.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-07.md) - [Next Solution →](../challenge-08/solution-08.md)

**Duration:** 40 minutes

## The test set

Every pack's `evaluation.jsonl` has ten questions in the same mix:

| Kind | Count | Example (telco) |
|---|---|---|
| Facts from an article | 4 to 5 | *Why is my first bill higher…?* (`KB-KC-007`) |
| Identity check with a wrong postcode | 1 | *Balance on KC100202, postcode ZZ9 9ZZ* |
| Must refuse or hand over | 2 to 3 | Card number; telecare alarm |
| Service levels | 1 | *How quickly will you answer a high priority case?* (`KB-KC-004`) |
| Off topic | 1 | Weather |

## What to expect

Our portal `baseline` run on telco (`contact-chat-agent` with the CRM, guardrail and care instructions, judge `gpt-5.4-mini`) took about 1.5 minutes:

| Evaluator | Result | What it means |
|---|---|---|
| Overall | 69% (92/134) | An average of very different checks; don't quote it on its own |
| Tool use quality | 65% (35/54) | Fails mostly on fact questions where no CRM call was needed (tool call accuracy, tool output utilization) |
| Output quality | 67% (47/70) | Groundedness failed 9 of 10 rows, task completion 4 of 10 |
| Similarity | **100% (10/10)** | Every answer matched the expected answer closely enough, including the wrong-postcode refusal |
| Violence, Sexual, Self-harm, Hate and unfairness | **Error** on every row | *The needed capability 'content harm' is not supported by the RAI service in this region* (uksouth) |

Three lessons, all worth more than the scores:

- **Read the evaluator's inputs before trusting it.** The wizard maps **Output quality** to `sample.output_text`, the final answer only. The judge never sees the passages the knowledge base returned, so it marks correct, cited answers as ungrounded. **Tool use quality** gets the full output items and does see the calls.
- **The judge can be wrong in the way that matters.** On the wrong-postcode row it failed groundedness and task completion with *the verification claim is ungrounded* and *did not provide the balance*. The agent was right on both counts: `verifyCaller` returned false, and refusing *is* the task. Ask groups to find this row.
- **An Error is not a pass.** The safety evaluators did not run at all in this region. A dashboard that shows 0% could be read as "no harm found". Check the region support before relying on them, or evaluate safety in a supported region.

Rule of thumb for this test set: use **Similarity** for "did it give the right answer", read the identity and vulnerability rows by hand, and treat groundedness here as a known false negative.

- Scores vary by a few points between identical runs. A difference smaller than that is noise.

### Our comparison: reasoning effort low vs medium

| Metric | low (baseline) | medium |
|---|---|---|
| Overall | 69% | 69% |
| Tool use quality | 65% | 70% |
| Output quality | 67% | 63% |
| Similarity | 100% (4.8) | 100% (4.7) |
| Coherence / task completion | 4.4 / 0.4 | 4.5 / 0.6 |
| Median latency | 4.1 s | 4.5 s |
| Target tokens | 25,834 | 26,286 |

The paired test marked **every** difference *Inconclusive* (quality) or *Too few samples* (tool metrics). That is the lesson: with ten questions, a few points either way is noise, and medium reasoning cost latency and tokens without a provable gain. For a voice channel, that settles it: keep **low**. To decide a change with evidence you need many more test questions, ideally from real (anonymised) contacts.

### Typical comparison

| Change | Likely effect |
|---|---|
| Reasoning effort **medium** | Slightly better task adherence on multi-step rows; slower answers. For a voice channel, latency matters as much as score. |
| Remove *ALWAYS search the knowledge base* | Fact rows drop: the agent answers from general knowledge (for example, a typical compensation amount rather than this company's 8 pounds a day). This is the most convincing demonstration. |

## Points to discuss

- **An average hides the row that matters.** One wrong identity answer is worse than ten slightly worse fact answers.
- **Evaluators are models.** Read the reasoning on the lowest row; sometimes the evaluator is wrong.
- **Voice:** these evaluations run on the chat twin. Before changing the voice agent, run the same scenarios by voice and check **Traces**.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The dataset upload rejects the file | It must be the downloaded `evaluation.jsonl` (one JSON object per line), not a renamed copy. |
| Safety evaluators show **Error** on every row | Content-harm evaluation is not available in the lab's region. Not a problem with the agent; see *What to expect*. |
| Groundedness fails on correct, cited answers | Output quality judges only the final answer text, without the retrieved passages. Expected; use Similarity and read rows by hand. |
| Every row fails with a tool error | The CRM was cold or no pack was selected. Open `<CrmUrl>/company`, then re-run. |
| Ground-truth evaluator not offered | Use **Similarity** or another evaluator that accepts `ground_truth`, and map the column when asked. |
