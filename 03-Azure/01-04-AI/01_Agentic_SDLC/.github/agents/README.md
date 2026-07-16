# Custom agents — `.github/agents/`

This folder holds **custom agents** for the repo. This README is a short "anatomy of a custom agent" so you can read one, use one, and build your own — the working example here is [`requirement-refiner.agent.md`](requirement-refiner.agent.md), built for the Challenge 2 requirement-refinement stretch.

## What is a custom agent?

A custom agent is a reusable chat persona: a set of **instructions** plus a scoped list of **tools** that the AI adopts when you switch to it. Instead of re-explaining a role and hand-picking tools every time, you save the configuration once and select it whenever you need it.

- **Where they live:** workspace agents are Markdown files with the `.agent.md` extension in `.github/agents/`. VS Code detects them automatically.
- **Where you use them:** the Copilot Chat **agent dropdown** in VS Code, and — because the same file is portable — in the **GitHub Copilot App / CLI** (background agents) and **cloud agents**.
- **Why bother:** a focused agent gives more consistent results, and a scoped tool list keeps it safe (least privilege) and cheaper (less context, fewer stray tool calls).

## Frontmatter fields

A custom agent is YAML frontmatter (the config) followed by a Markdown body (the system prompt). The common frontmatter fields:

| Field | What it does |
| --- | --- |
| `description` | Short summary of the agent; shown as placeholder text in the chat input. |
| `name` | Display name in the agent dropdown. Defaults to the file name if omitted. |
| `argument-hint` | Optional hint telling the user what to type to get started. |
| `tools` | The tools / tool-sets the agent may use. Keep it minimal — least privilege. |
| `model` | Optional model to run with. **Omit** to use whatever model the user has selected. |
| `handoffs` | Optional next-step buttons that transition to another agent with pre-filled context. |
| `target` | Optional surface (`vscode` or `github-copilot`). **Omit** for the default VS Code surface. |

Only `tools` and the body really shape behaviour; everything else is presentation or portability. Fields are optional — when in doubt, leave one out.

## How this example is built

[`requirement-refiner.agent.md`](requirement-refiner.agent.md) maps to those fields like this:

- **`name: Requirement Refiner`** — what you pick from the agent dropdown.
- **`description`** — one line so you know what it's for before selecting it.
- **`argument-hint`** — nudges you to point it at `assets/workiq/` to start.
- **`tools: ['codebase', 'search', 'web', 'github-remote/search_issues', 'github-remote/create_issue']`** — a **read-only analysis core plus one tightly-scoped write capability**. `codebase` and `search` read repo files and the WorkIQ artifacts; `web` pulls external context — none of them can change your workspace. The two `github-remote/...` entries add exactly one write action (create an issue) and one search action (to dedupe before creating), and nothing else. The guardrail here is deliberate on two fronts: **no file-editing or terminal tools** (it can't touch code or run commands), and the write capability is **scoped to two named tools rather than the whole server**. Note what is *not* here: `github-remote/*` would hand the agent the entire GitHub toolset (closing issues, pushing code, editing PRs…). Least privilege is a design choice — grant only the one or two tools the task needs.
- **Write access ≠ autonomy.** Granting `create_issue` doesn't mean the agent files issues on its own. The body pairs that capability with a **mandatory human-confirmation step**: it confirms the need, title, labels, and target repo, and creates **exactly one** issue only after an explicit yes — with a paste-ready-markdown fallback if the MCP server isn't available. A write tool in `tools` and a human-in-the-loop instruction in the body are two halves of the same guardrail.
- **Referencing MCP tools.** In `tools`, an MCP tool is written as `<serverName>/<toolName>` (e.g. `github-remote/create_issue`); `<serverName>/*` would include *all* of that server's tools. Here `github-remote` is the hosted GitHub MCP server preconfigured in [`.vscode/mcp.json`](../../.vscode/mcp.json) with the `issues` toolset, so `create_issue` and `search_issues` are available without any extra setup.
- **`model` is omitted** on purpose, so it runs with whatever model you've selected (no dependency on a model name that might not exist in your environment).
- **The body** is the system prompt: a **Role**, the **Inputs** it may read, a numbered **Process**, a fixed **Output format** (the "Requirement brief"), and explicit **Guardrails**. The clear headings aren't just for humans — a well-structured prompt gives the agent a reliable routine to follow.

## How to use it

1. Open **Copilot Chat** in VS Code.
2. Select **Requirement Refiner** from the agent dropdown.
3. Give it a starting prompt, e.g. _"Refine a requirement from the signal in `assets/workiq/`."_
4. Work through the refinement with it — confirm the need it proposes, then let it draft the **Requirement brief**. If you want, it can either render a paste-ready GitHub issue or, on your explicit confirmation, **file the issue for you** via the `github-remote` MCP server. Building the feature stays your job.

## Build your own

1. Create `.github/agents/<name>.agent.md`.
2. Add frontmatter — at minimum a `name` and `description`, plus a **minimal** `tools` list (only what the task needs).
3. Write the instruction body: define the role, the process, and any output format and guardrails. Use clear headings.
4. Reload/open Copilot Chat and select your agent from the dropdown to try it.

> Tip: match the tools to the job. Prefer read-only by default — an analysis or advisory agent usually needs nothing more. When a task genuinely needs a write action, scope it to the **minimum** named tools (not a whole MCP server) and keep a **human in the loop** in the instructions. This example stays read-only for analysis but adds just `create_issue` (+ issue search to dedupe), gated behind explicit confirmation — write access without autonomy.
