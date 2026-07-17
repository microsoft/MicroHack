# Walkthrough Challenge 7 - Agentic workflows

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-06/solution-06.md) - [Finish](../../challenges/finish.md)

Duration: 30 minutes

## Prerequisites

Complete [Challenge 6](../challenge-06/solution-06.md). Confirm agentic-workflow / agent capabilities are enabled for your org.

## Approach

The closing challenge: agents don't just build, they **sustain**. Keep it focused — start with a **low-risk task** so you get a working workflow rather than an ambitious half-built one. Make sure you actually **trigger and observe** it.

Suggested pacing:

```
Identify a maintenance task              ~5 min
Author the agentic workflow             ~12 min
Define triggers + guardrails             ~5 min
Test the workflow                        ~5 min
Review the output                        ~3 min
```

### Task 1: Identify a low-risk maintenance task

- Choose a recurring task: **issue triage/labelling** (great first choice), dependency updates, test/lint on change, or docs upkeep. Automate code-changing tasks only once the pattern works.

### Task 2: Author the workflow

- Create a GitHub Agentic Workflow that performs that one task autonomously.

### Task 3: Define triggers and guardrails

- 🔑 Configure exactly **when** it runs (schedule / PR / issue) and **constrain what it may do** — least privilege. The agent should only touch what its task needs.

### Task 4: Test the workflow

- Trigger it against real repo state and watch the agent complete the task. If it doesn't fire, check the trigger config matches the event you're testing and that permissions allow it.

### Task 5: Review the output

- Inspect the agent's actions for correctness and safety before trusting/enabling it broadly. If it did something unexpected, that's the teaching moment — tighten scope and re-run.

## Common blockers

- **Workflow too ambitious (auto-changing code)** → start with triage/labelling.
- **Doesn't trigger** → trigger config mismatch or insufficient permissions.
- **Over-broad permissions** → tighten to least privilege.
- **No-op / nothing to review** → ensure the task is real and the trigger fired against actual state.

## Optional stretch — package a reusable skill / slash command

- Pick a repeatable manual flow (e.g. "read instructions → scaffold tests → run validation").
- Package it as a reusable **skill or slash command** so it's invocable in one step.
- Invoke it against a real task and confirm the steps run.
- Document where **human review stays mandatory** (e.g. before merging generated tests or committing changes).

You successfully completed challenge 7 — and the full Agentic SDLC arc: **plan → build → test → review → deploy → monitor → maintain**, all with agents. 🚀🚀🚀

Head to the [Finish](../../challenges/finish.md) page.
