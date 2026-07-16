# Walkthrough Challenge 0 - Dev environment & repo overview

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-01/solution-01.md)

Duration: 30 minutes

## Prerequisites

Please ensure you have satisfied the [General prerequisites](../../Readme.md#general-prerequisites) before continuing.

## Approach

The aim here is a smooth, fast start — a good setup means the rest of the day goes into building, not fighting toolchains.

### Task 1: Get the code and open an environment

- Open your team's copy of this MicroHack in **GitHub Codespaces** (fastest, nothing to install), a local **VS Code Dev Container**, or locally.
- 💡 If local setup takes more than ~15 minutes, **switch to Codespaces** rather than fighting a local toolchain.
- Confirm you're on the intended working branch.

### Task 2: Verify runtimes and enable Copilot

- In Codespaces / the Dev Container, Node.js 24, Python 3.13, .NET 10, and Java 17 are preinstalled. Locally, install only the runtime for your chosen API track plus Node.js.
- Sign in to GitHub Copilot in the IDE. **Proof that it works** is a real Chat response about a file you have open — not just the extension being installed. If suggestions are empty, sign out/in, confirm your seat is assigned, and open a real source file so the agent has context.

### Task 3: Explore the repo

- 🔑 The quickest way to satisfy this is to **ask Copilot Chat to summarise the repository structure and the main entry points**.
- Identify: `src/` (the app — frontend + four API variants + shared SQLite schema, plus `src/docs/` architecture guidance), `infra/` + `scripts/` (Azure deployment), `assets/` (Challenge 2 backlog & WorkIQ inputs), `.github/` (Copilot custom instructions & agents). Read `src/README.md`.

### Task 4: Run the app locally

- Start the frontend and one API (see `src/README.md` — `make dev` / per-variant targets). Load a page in the browser and confirm the API responds.
- Pick the API language your team is most comfortable with; the choice doesn't affect the concepts in later challenges.

## Optional stretch — repo-wide agent context

Create an `AGENTS.md` and/or `.github/copilot-instructions.md` with:
- **Conventions** — concrete, repo-specific rules (naming, repository pattern, DTO/type usage), not generic advice.
- **Validation commands** — the exact build/test commands for your track and the frontend.
- **Scope rules** — explicit "do not touch" boundaries (generated files, infra, unrelated services).

Then, in a **fresh** Copilot Chat, ask something that relies on a convention **without restating it** and confirm the instructions were applied. This pays off directly in Challenges 1–3.

You successfully completed challenge 0! 🚀🚀🚀
