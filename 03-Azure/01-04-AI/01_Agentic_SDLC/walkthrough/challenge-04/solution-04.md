# Walkthrough Challenge 4 - Testing & review

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-03/solution-03.md) - [Next Challenge Solution](../challenge-05/solution-05.md)

Duration: 30 minutes

## Prerequisites

Complete [Challenge 3](../challenge-03/solution-03.md). Know the exact test commands for your API track and the frontend.

## Approach

Focus tests on the **cart and backlog features you just built** — not the whole app. Push for quality of tests (edge cases, error handling) over raw count.

Suggested pacing:

```
Run existing tests (baseline green)      ~5 min
Find the gaps with Copilot               ~5 min
Extend coverage (unit + component)      ~12 min
Agent-assisted review                    ~5 min
Fix findings                             ~3 min
```

### Task 1: Establish a green baseline

- Run the existing API and frontend suites and confirm they pass. If the baseline fails on a clean checkout, it's usually an environment issue from Challenge 1 — fix that first (Codespaces), then re-run.

### Task 2: Find the gaps

- Ask Copilot to identify untested code paths in the cart and backlog features you added.

### Task 3: Extend coverage

- 🔑 **Generate tests from the existing types and interfaces** so they stay accurate and compile.
- Prompt explicitly for **edge cases and error handling** — not just happy paths.
- Repo rule: only use test frameworks that **already exist** in the repo.

### Task 4: Agent-assisted review

- Run the code review agent (or Copilot review) on your recent changes.
- Triage findings by the escalation order: **security / data integrity → correctness → performance → maintainability → style.** Fix the top; note the rest. Don't drown in nits.

### Task 5: Fix findings

- Address the security/correctness issues surfaced by tests and review; confirm the suites are green again.

## Optional stretch — model selection & context budgeting

- **Compare models** — generate tests once in Auto and once with an explicitly selected model; record a decision rule for when to use each.
- **Set a context budget** — decide a max number of files and max reference length per file before prompting, and stick to it.
- **Note the trade-off** — capture how the budget affected quality vs. noise. The reflection is the deliverable.

You successfully completed challenge 4! 🚀🚀🚀
