# Walkthrough Challenge 2 - Backlog feature (agentic loop)

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-01/solution-01.md) - [Next Challenge Solution](../challenge-03/solution-03.md)

Duration: 60 minutes

## Prerequisites

Complete [Challenge 1](../challenge-01/solution-01.md). If the backlog has been seeded as GitHub Issues, have the Issues tab open.

## Approach

This is the centrepiece: run a full **plan → implement → test → review** loop. The easiest mistake is over-scoping — pick a feature you can finish *with tests*, not the most ambitious one.

Suggested pacing:

```
Choose a backlog item                    ~5 min
Plan with an agent                      ~10 min
Implement across the stack              ~25 min
Add tests                               ~12 min
Agent-assisted review                    ~8 min
```

### Task 1: Choose a backlog item

- Pick one from `assets/backlog.md` — payment integration for the cart, order history, product search/filtering, or inventory management are good candidates. If seeded as Issues, pick a real labelled issue.

### Task 2: Plan with the agent first

- 🔑 **Don't dive straight into code.** Have the agent decompose the work into steps and produce a file/layer map (frontend, API, database) before you implement. A team that skips planning is missing the point of the challenge.

### Task 3: Implement across the stack

- Build the smallest demonstrable slice, consistent with existing patterns and type-safe.
- For anything touching payment/config, use **environment-variable-driven configuration — no secrets in source.**

### Task 4: Add tests

- Cover the new logic with unit tests (API/repository) and component tests where relevant. Letting the agent draft tests first (TDD-style) is fine. Don't let implementation eat the whole hour — reserve time for tests.

### Task 5: Agent-assisted review

- Before calling it done, ask Copilot to review your change for correctness, security, and data integrity, and fix what it surfaces.

## Optional stretch — harnesses, MCP & requirement refinement

- **Compare harnesses** — run the planning step in Copilot CLI vs. the Copilot App / IDE chat; write a decision rule for quick fix vs. multi-file change.
- **Wire in an MCP server** — connect the GitHub MCP server to pull real backlog context (issues, PRs); note what stays local-only vs. what the server can see.
- **Refine a requirement from WorkIQ signal** — point the agent at `assets/workiq/` (Teams thread, support-ticket digest, stakeholder email). Synthesize across the artifacts, **separate a genuinely-new need from noise and from work already on the backlog**, and shape it into an issue-ready requirement: problem statement → acceptance criteria → scoped tasks (optionally a GitHub Issue). There is deliberately **no answer key** — realistic noise is mixed in, and the skill being assessed is the refinement, not guessing a specific feature. A good refinement has a clear problem statement, testable acceptance criteria, timebox-sized scope, and evidence the new need was separated from backlog/noise. The **Requirement Refiner** custom agent (`.github/agents/`) can guide this and will not name a "correct" feature.

## Common blockers

- **Over-scoped feature** → cut to the smallest demonstrable, testable slice.
- **Thrashing in code with no plan** → stop, produce a step list + file/layer map first.
- **Hard-coded secrets** → move to environment-variable config.
- **No tests by ~45 min** → have the agent draft tests now.

You successfully completed challenge 2! 🚀🚀🚀
