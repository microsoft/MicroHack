# Scripts

Utility scripts for running the Agentic SDLC Hackathon.

## `seed-backlog.sh` / `seed-backlog.ps1` — Seed the Challenge 2 backlog

These scripts create the [Challenge 2 backlog](../hackathon/backlog.md) as real **GitHub Issues** in a
repo, so teams pick from a real, prioritised, labelled list instead of inventing a backlog. The seeded
issues are also what an MCP server can pull as **real backlog context** in the Challenge 2 optional stretch.

Both scripts do the same thing — use the `.sh` on macOS/Linux and the `.ps1` on Windows.

### What they do

- Ensure the labels `backlog`, `priority:high`, `priority:medium`, and `priority:low` exist (created if
  missing; existing labels are tolerated).
- Create one issue per backlog item, with a title, a body derived from `hackathon/backlog.md`
  (description + acceptance criteria + affected layers), and the `backlog` + priority labels.
- Skip any item whose title already matches an **open** issue, so the scripts are safe to re-run.
- Print a summary of labels ensured, issues created, and issues skipped.

By default **8 issues** are seeded — one per item in `hackathon/backlog.md`. To change the set, edit the
backlog items in the script (and keep it in sync with `hackathon/backlog.md`).

### Prerequisites

- **GitHub CLI** installed — https://cli.github.com/
- **Authenticated** with `repo` scope — `gh auth login`

If `gh` is missing or unauthenticated, the scripts stop with a clear, actionable message before making
any changes.

### Usage

**Bash (macOS / Linux):**

```bash
# Seed the current repo (the one gh resolves for this directory)
./scripts/seed-backlog.sh

# Target a specific team repo or fork
./scripts/seed-backlog.sh --repo octo-org/team-1

# Preview only — prints what would be created, no API calls
./scripts/seed-backlog.sh --dry-run
```

**PowerShell (Windows):**

```powershell
# Seed the current repo
./scripts/seed-backlog.ps1

# Target a specific team repo or fork
./scripts/seed-backlog.ps1 -Repo octo-org/team-1

# Preview only — no API calls
./scripts/seed-backlog.ps1 -DryRun
```

> On macOS/Linux you may need to make the script executable first: `chmod +x scripts/seed-backlog.sh`.

### When to run it (event flow)

- **Pre-event, per team repo/fork.** As part of repo prep (see `docs/.proctor/PROCTOR_GUIDE.md` →
  PRE-EVENT ADMIN SETUP), run the seeder against each team's repo/fork so the backlog is already there
  when teams reach Challenge 2.
- **Do a `--dry-run` first** to confirm the target repo and see the list before creating anything.
- It's safe to re-run if a repo was missed or you want to top up after manual edits — duplicates are
  skipped by title.
