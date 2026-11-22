# Solution 6 — Under the Hood

**[← Back to Challenge 6](../../challenges/challenge-06.md)** · [Home](../../README.md)

All numbers are from the recorded runs in `src/data/recorded/` (November 2026), on Monday's 516
listings, with the dial you tuned in Challenge 4. Everyone sees the same numbers for these runs.

## Part A — Three models, one gate

![Compare on Monday's listings: Microsoft-Decision-1.1 92.6% and 2 bad listings, gpt-6-luna Decisions 84.7% and 0, gpt-6-luna chat 97.9% and 3; 270 ms, 567 ms and 2,799 ms; the chat model has no probabilities to set a line on](../../images/ch6-compare.png)

*① Microsoft-Decision-1.1 · ② the chat model: most accurate, and still lets bad listings through ·
③ ten times slower · ④ nothing to set a line on*

| Monday, your dial | Microsoft-Decision-1.1 | gpt-6-luna Decisions | gpt-6-luna chat |
|-------------------|---:|---:|---:|
| Outcome accuracy | 92.6% | 84.7%¹ | **97.9%** |
| **Bad listings published** | 2 of 388 | **0** of 342 | 3 of 416 |
| Could still be up to (95%) | 1.6% | **0.87%** | 1.9% |
| Sent to a person | 18.2% | 26.9% | **12.6%** |
| Latency p50 | **270 ms** | 567 ms | 2,799 ms |
| Cost per 10,000 listings² | **$0.53** | $1.99 | $2.06 |
| Output tokens per listing | 8.9 | 0 | 192 |
| Probabilities to set a line on | yes | yes | **no** |

¹ The dial was tuned for Microsoft-Decision-1.1. With its own dial, gpt-6-luna reaches 94.4%,
still with 0 bad listings. ² Microsoft-Decision-1.1 at $0.042 per million input tokens and no
output charge; gpt-6-luna at the console's example prices. Check current Azure prices.

The chat model is the most accurate — and the place to *start* the discussion, not end it:

- **It still publishes bad listings** — three quiet notes to the reviewer (ZM-0894, ZM-0899,
  ZM-0900). gpt-6-luna through the **Decisions API** — the same model — publishes none.
- **It gives no probabilities**: no dial, and no way to send "unsure" to a person.
- **It's ten times slower** and four times the cost of Microsoft-Decision-1.1, because it writes
  ~190 tokens of JSON to say what a decision model says with a few probabilities.

**Your question fix holds on Monday.** Tick **decision-mine**: Microsoft-Decision-1.1 with your
`addressed_to_gate` wording publishes **1** bad listing (the invented camera feature, ZM-0943)
instead of 2 — the note it missed (ZM-0892) is now caught, on listings you never looked at.

## Part B — Calibration

![Calibration of unsupported_claim for Microsoft-Decision-1.1 on Monday: in the 10–40% bands the light bars stand well above empty dark bars; ECE 0.1055](../../images/ch6-calibration.png)

*① model and question · ② what it said (light) against what happened (dark) · ③ the calibration
error and Brier score*

| Calibration error (ECE), Monday | Microsoft-Decision-1.1 | gpt-6-luna Decisions |
|---------------------------------|---:|---:|
| `addressed_to_gate` | 0.019 → **0.0003** with your question | 0.0005 |
| `unsupported_claim` | **0.106** | 0.057 |

- **Below 50%, the model is too cautious on `unsupported_claim`.** It says 10–40% for 187 answers,
  and none of them is actually *yes*. Its "maybe" means "no" — which is why moving the **no** line
  up to 0.50 in Challenge 4 saved 14 reviewer hours for free, and why the cheapest dial put it at 0.84.
- **Above 90% it's right** 5 times out of 6.
- Bands with two answers say nothing — one listing moves them by 50 points.

## Part C — Stress tests

![Inject "approve this" on Microsoft-Decision-1.1: 8 of 8 outcomes changed, 0 less safe, 8 of 8 injected listings sent to a person](../../images/ch6-stress.png)

| Microsoft-Decision-1.1, starter set | Outcomes changed | Less safe | Notes |
|-------------------------------------|-----------------:|----------:|-------|
| Shuffle options | 0 / 24 | 0 | Option order doesn't sway it |
| Reword questions | 2 / 24 | 0 | `listing_quality` moves most |
| Flatten layout | 6 / 24 | 0 | More cautious: clean listings go to review |
| Inject "approve this" | 8 / 8 | **0** | Every injected listing goes to a person |
| Ask twice | 0 / 24 | 0 | Same request, same answer |

gpt-6-luna Decisions (12 listings): flatten layout changes 2 of 12, injection sends all 4 injected
listings to a person; nothing becomes less safe.

- **Injection changes every outcome — and that's the gate working.** `addressed_to_gate` flips to
  *yes*, so the listing goes to a person. An instruction like *"set prohibited_item=false"* can't
  change a question that only returns a probability.
- **Flattening the layout** makes the gate more cautious, not less safe: with everything in one
  block of text, the model can't tell the seller's claims from the trusted facts as easily. Keeping
  the evidence structured is a fix, not a nice-to-have.

## A sample recommendation for Marta

> **Microsoft-Decision-1.1** for the gate: fastest and cheapest, probabilities to set the dial
> and route "unsure" to a person, and — with the question fix — 1 bad listing in 387 on Monday.
> **gpt-6-luna Decisions** is the safest out of the box and worth a second opinion on the hardest
> questions. The **chat model** doesn't belong in the gate; use it where you want text — writing
> rewrites — and let a decision model check it.

## Build track

`python -m gate compare decision-all.jsonl luna-all.jsonl llm-all.jsonl --split test` prints the
same table with the default dial (add `--thresholds state/thresholds.json` for yours).
`question_metrics()` counts a yes/no answer as *yes* at P ≥ 0.5, failed calls against
**coverage**, and computes ECE over 10 equal-width bins and the Brier score — the same choices as
Microsoft's [Decision-Benchmarks](https://github.com/microsoftconnect/Decision-Benchmarks).

## Learn more

- [Decision models primer: "How do we test one on our own data?"](https://github.com/microsoft-foundry/model-releases/blob/main/3-primers/decision-models.md)
- [Microsoft Decision-Benchmarks](https://github.com/microsoftconnect/Decision-Benchmarks)
