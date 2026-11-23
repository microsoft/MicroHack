# Challenge 2 — Truth Check

**[← Previous](challenge-01.md)** - [Home](../README.md) - [Next Challenge →](challenge-03.md)

## 📖 The story — Saturday

Banned products and hidden phone numbers are out. Priya from Trust & Safety sends over her draft
of the **truth check**: does a listing match the manufacturer's facts, show the right photo, ask
a sensible price — and is there anything in it aimed at the reviewer rather than the shopper?

Before you switch it on, you test her draft. And once it's on, one kind of listing still slips
through — because of how a single question is worded.

## 🎯 What you'll build and learn

| | |
|---|---|
| 🔨 **You build** | The **Truth check**: five yes/no questions plus two checks in code — and a better version of the question that misses. |
| 🧠 **You learn** | How to **ask a question a model answers well**: one idea per question, plain words, give it what it needs, keep exact maths in code — and test every change. |

The evidence the model sees has two parts. `seller_listing` is written by the seller, so it's
**untrusted**. `manufacturer_facts` is **trusted**. Every question says which part to use.

## ✅ Tasks

### 🧭 Explore — in tab **2 · Truth check**

#### Part A — Test Priya's draft (15 min)

Priya's draft asks **one choice question**: is the listing *consistent*, *contradicted*,
*unsupported* or *not assessable* compared with the facts?

1. **Predict** how often it will be right on the 24 starter listings, then click **Test Priya's draft**.
2. Look at the listings it got wrong: how did the model **split** its probability?
3. Read why it fails. The gate asks **two yes/no questions** instead: *does anything contradict
   the facts?* and *does it claim something the facts don't mention?* Why does that help?

![Priya's draft: right on 45.8% of the starter set, 13 of 24 wrong; the model splits its probability between unsupported and consistent](../images/ch2-draft.png)

#### Part B — Build: add the Truth check (5 min)

Click **Add the Truth check to my gate**. Watch the scorecard: bad listings drop a lot — and,
for the first time, people have work to do. How many reviewer hours a day now?

#### Part C — The mystery: what still gets through? (10 min)

1. The mystery card now lists what still goes live with the Truth check on. What kind of listing is it?
2. Open **ZM-0050** and read the description **to the end**. Ask the gate's questions. What does
   `addressed_to_gate` say?

#### Part D — Fix the question (15 min)

The question describes text that **asks** the gate to do something ("approve this", "skip the
check"). The note in ZM-0050 doesn't ask anything — it **claims** a check already happened.
Decision models read literally.

1. In **Reword the question that missed it**, extend `addressed_to_gate` so it also covers
   **notes claiming the listing was already checked, approved or verified**. Keep it one idea.
   Click **Save**.
2. Click **Test my wording on the starter set**. Did the question get better? Did any outcome
   change — and was it the one you wanted? Did anything get **worse**?

![Fixing addressed_to_gate: the new wording, then the test on the starter set — whole gate 100% (was 95.8%), bad listings 0 (was 1), ZM-0050 now goes to review](../images/ch2-fix-question.png)

> [!IMPORTANT]
> A better question for one listing can be a worse question for others. That's why you test on
> the whole starter set — and then on a thousand listings.

#### Part E — Build: carry the fix into the rehearsal (5 min)

Click **Re-score with my question**. It re-asks only the question you changed on the 1,040
rehearsal and Monday listings (2–3 minutes). Your scorecard now uses your answers. What happened
to bad listings live — and what did it cost in reviewer hours?

![Re-score with my question: bad listings live per 10,000 down by 96 to 95, reviewer hours up by 3](../images/ch2-rescore.png)

#### Part F — Why is the price check code? (5 min)

Open the **ZM-0066** link — a desk lamp at €13.54 — which asks *"Is the price less than 40% of
the usual price?"*. The model answers about **50%**: a coin toss. Open **Show me the code**: it
was never given the usual price. The gate compares prices in [code](../src/gate/rules.py) — one
division, always right, free. **Keep exact maths in code.**

#### Part G — Your Decision Design Card (5 min)

Take your decision from Challenge 1. Is it really one question, or two or three ideas in one?
Write the sharpest version on today's card.

### 🛠️ Build *(optional, for developers)*

```bash
python -m gate evaluate --starter --draft     # Priya's draft
python -m gate evaluate --starter             # the current questions
python -m gate launch --pieces safety,truth
```

1. Fix `addressed_to_gate` in [`gate/questions.py`](../src/gate/questions.py) and test it with
   `python -m gate ask ZM-0050`. Then carry it into your rehearsal, like the console's
   **Re-score with my question**:
   ```bash
   python -m gate rescore                          # re-asks only what you changed (~2 minutes)
   python -m gate launch --pieces safety,truth     # the first line now says "your re-scored questions"
   ```
   The hosted console keeps its own edits; your Cloud Shell or codespace has its own copy. (A
   console you start yourself from `src` saves edits in `state/questions.json`, which the command
   line uses too.)
2. **Multi-select.** Write a script that checks one listing for *several* problems at once, with
   one `noul` question per problem (contact details, a warranty promise, a note to the reviewer)
   in one request, and prints *selected*, *not selected* or *needs review* at 0.80 / 0.20 — the
   pattern from the [Microsoft-Decision-1.1 quickstart](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/introducing-microsoft-decision-1-1-build-faster-more-efficient-ai-applications-w/4573877).
3. **A new rule.** Zava wants used products to say so in the title. Add a yes/no question to
   `QUESTIONS` and a rule in `decide()` (inside `if t.on("truth"):`) that sends such listings to
   review. Test it with `python -m gate ask`.

## 🏁 Success criteria

- [ ] You tested Priya's draft and can explain why one question for every claim fails.
- [ ] Your gate has the **Truth check**.
- [ ] You improved `addressed_to_gate`, ZM-0050 now goes to review, and nothing got worse on the starter set.
- [ ] You re-scored, and can say what the fix did to bad listings live and to reviewer hours.
- [ ] You can explain why the price check is code, not a question.
- [ ] You saved a **Decision Design Card**.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| **Test my wording** says you haven't saved a change | Click **Save** under the question first. |
| Your edit made a listing worse | That's a real result. Make the wording more specific, or **Reset** and try again. |
| **Re-score** says there is nothing to re-score | Your wording matches the original. Save an edit first. |
| A test takes several minutes | Everyone shares the subscription's quota and the client paces itself. Wait; don't click twice. |
| The mystery card says to add the Truth check first | Click **Add the Truth check to my gate** in Part B. |

## 💡 What you learned

**One idea per question.** Plain words. Give the model what it needs to know — and keep exact
checks in code. And **test every change**: on the starter set first, then on a thousand
listings. A question fix removes a whole kind of mistake; it's the most powerful lever you have.

## 📚 Learning resources

- [Decision models primer: "How do we make the answers trustworthy?"](https://github.com/microsoft-foundry/model-releases/blob/main/3-primers/decision-models.md)
- [Microsoft-Decision-1.1 — question types and best practices](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision)
- [TypeSafe: model jaggedness — what decision models are weak at](https://docs.typesafe.ai/model-jaggedness.md)

[Walkthrough and expected results](../walkthrough/challenge-02/solution-02.md)
