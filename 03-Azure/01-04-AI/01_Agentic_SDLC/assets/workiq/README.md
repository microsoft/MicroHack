# WorkIQ — mock organizational knowledge

**WorkIQ** is this hackathon's stand-in for **Microsoft 365 organization knowledge, context & insights** — the kind of signal an agent could pull from Teams chats, support systems, and stakeholder email. None of it is real; it's a small, deliberately **messy** slice of "what the org is talking about" so you can practise turning ambient organizational chatter into implementable work.

This folder exists for the **Challenge 2 optional stretch** (requirement refinement). It gives you something *raw* to refine — there is no clean story, no spec, and no acceptance criteria for you to copy. That's the point.

## What's in here

| File | What it mocks |
| --- | --- |
| [`teams-thread-launch-promo.md`](teams-thread-launch-promo.md) | A Microsoft Teams thread across a few people ahead of the Octocat Supply launch |
| [`support-tickets-digest.md`](support-tickets-digest.md) | A digest of raw customer support tickets (customer voice, unedited) |
| [`stakeholder-email-launch-priorities.md`](stakeholder-email-launch-priorities.md) | A short launch-week priorities email from a stakeholder |

## How to use it

1. **Point your agent at this folder** as organizational context (open the files, or reference `assets/workiq/` in your prompt).
2. **Synthesize across the artifacts** — read the chat, the tickets, and the email together and look for a need that shows up in *more than one* place.
3. **Separate signal from noise.** Not everything here is new or actionable. Some of it restates work that's **already on the backlog** ([`assets/backlog.md`](../backlog.md)); some of it is just people being people. Your job is to find the genuine, *unmet* need that isn't already planned.
4. **Refine it into issue-ready work** — turn that need into a crisp requirement: a **problem statement**, **testable acceptance criteria**, and a small set of **scoped tasks** that fit the challenge timebox. Optionally open it as a GitHub Issue.

> There is **no answer key**. A good refinement is judged on the *quality of the refinement* — a clear problem, testable criteria, sensible scope — not on guessing a "correct" feature. Keep it small enough to actually deliver.
