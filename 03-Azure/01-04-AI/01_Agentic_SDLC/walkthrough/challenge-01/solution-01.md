# Walkthrough Challenge 1 - Deliver the cart feature

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-00/solution-00.md) - [Next Challenge Solution](../challenge-02/solution-02.md)

Duration: 30 minutes

## Prerequisites

Complete [Challenge 0](../challenge-00/solution-00.md) — a working app and a responding Copilot — before starting.

## Approach

The emphasis is **using Copilot well**, not just writing code. Aim for a minimal, working cart (add / update qty / remove / total), not a perfect one.

Suggested pacing:

```
Understand current state (Copilot explain)   ~5 min
Design cart behaviours                        ~3 min
Implement API endpoints                      ~10 min
Wire up the UI                                ~8 min
Validate end to end                           ~4 min
```

### Task 1: Understand what already exists

- Ask Copilot to explain the existing cart-related code in the frontend and API and to point out what's missing. Note the repo patterns you must follow: repository pattern, DTOs/types, error handling, consistent HTTP status codes (see `.github/instructions/api.instructions.md`).

### Task 2: Design the behaviours first

- Decide the specific behaviours — add, update quantity, remove, total — then implement one at a time rather than everything at once.

### Task 3: Implement the API

- 🔑 **Paste (or open) the existing model/DTO types into your prompt** so Copilot's suggestions match the codebase and stay type-safe.
- Persist cart state **through the API using the repository pattern** — don't fake persistence in the client.

### Task 4: Wire a thin UI early

- Get a minimal UI wired to the API early so you can validate the whole loop, then refine. If you're deep in the API at ~20 minutes with no UI, wire the thin UI now.

### Task 5: Validate end to end

- Exercise add / update qty / remove in the running app and confirm the displayed total updates correctly.

## Common blockers

- **Output drifts from repo style** → reference the existing DTO/model types in the prompt.
- **Sprawling diff touching unrelated files** → keep changes incremental and scoped; revert unrelated edits.
- **Endpoint not persisting** → follow the repository pattern, not in-memory/client-only storage.
- **Trying to build payment now** → payment is a follow-on (Challenge 2); capture it and stay scoped.

## Optional stretch — structured prompting

- Build a reusable **prompt template**: objective / constraints / files in scope / output format.
- Feed context in priority order and **stop** once it's enough: directly edited files → adjacent tests → docs only if needed.
- Run the same request with a vague prompt and keep the better result — and be able to say *why* it was better.

You successfully completed challenge 1! 🚀🚀🚀
