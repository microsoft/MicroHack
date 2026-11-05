# Module 0 — Fundamentals: Custom Agents, Skills, and MCP for App Modernization

This module gives you the mental model you need before touching the challenges. Read time: ~15 minutes.

---

## 1. The Big Picture

Modernization is a **multi-step, knowledge-heavy workflow**: assess → plan → execute → validate. AI coding agents are good at executing steps, but out of the box they lack:

| Gap | Solved by |
|-----|-----------|
| A defined *role*, scope, and guardrails for the workflow | **Custom Agent** |
| Reusable *domain knowledge* (migration rules, upgrade recipes, conventions) | **Skill** |
| *Tools* to act on the real world (run AppCAT, build, scan CVEs, deploy) | **MCP server** |

```mermaid
flowchart LR
    U[User prompt] --> A["Custom Agent<br/>(role + workflow + guardrails)"]
    A -->|loads knowledge on demand| S["Skills<br/>(SKILL.md files)"]
    A -->|calls tools| M["MCP Servers<br/>(assessment, build, CVE, deploy)"]
    M --> R[(Real systems:<br/>code, Azure, registries)]
```

**Rule of thumb:**
- *Agent* = **who** is working and **how** the workflow runs.
- *Skill* = **what** the agent knows (loaded only when relevant — progressive disclosure).
- *MCP* = **what** the agent can do (tools with typed inputs/outputs).

---

## 2. Custom Agents (`.agent.md`)

A Custom Agent is a markdown file with YAML frontmatter, placed in `.github/agents/` in the target repo (picked up by GitHub Copilot CLI, VS Code, and the Copilot coding agent) or at user level in `~/.copilot/agents/` (Copilot CLI only). It defines:

| Element | Purpose |
|---------|---------|
| `description` | When the agent should be picked (shown in agent picker / used for routing) |
| `tools` | Allow-list of tools the agent may use (limits blast radius) |
| Body (markdown) | System-prompt-like instructions: persona, workflow stages, gates, output format |

### Why custom agents matter for modernization

- **Phased workflows with gates** — e.g., "do not modify code until the assessment report is approved by the user."
- **Tool restriction** — an *assessment* agent gets read-only tools; an *execution* agent gets build/edit tools.
- **Consistency across teams** — every team modernizes with the same playbook.

### Minimal anatomy

```markdown
---
description: One-line routing description for this agent
tools: ['read', 'search', 'execute', 'edit']
---

# Role
You are a <role> specialized in <scenario>.

# Workflow
1. Assess … (STOP and ask for approval)
2. Plan …
3. Execute …
4. Validate …

# Guardrails
- Never … / Always …
```

> Tool names are environment-specific, but the portable aliases `read`, `search`, `edit`, and `execute` work across Copilot CLI, VS Code, and the coding agent — unrecognized names are simply ignored. MCP tools are referenced as `<server>/<tool>` or `<server>/*`.

---

## 3. Skills (`SKILL.md`)

A Skill is a folder containing a `SKILL.md` (plus optional supporting files: scripts, rule books, examples). Repo-level skills live in `.github/skills/<skill-name>/SKILL.md`; personal skills in `~/.copilot/skills/` (Copilot CLI). The agent reads the skill **only when the task matches its description** — this keeps context lean (progressive disclosure).

| Element | Purpose |
|---------|---------|
| `name` | Unique skill identifier — lowercase, hyphenated, no spaces |
| `description` | **Critical**: trigger phrases — "WHEN: upgrade Spring Boot, fix CVE…" — that route tasks to this skill |
| Body | The actual instructions: steps, rules, decision tables, command references |
| Supporting files | Migration rulebooks, code-mapping tables, validation scripts |

### Skills are the modernize CLI's customization mechanism

The **modernize CLI** automatically scans `.github/skills/` when you run `modernize plan create "<prompt>"`: it compares your prompt with each skill's `description`, incorporates matching skills into the plan, and records them in the plan's `tasks.json` (`"skills": [{"name": …, "location": "project"}]`). This is how organization-specific migration patterns are applied consistently across repositories — and it is exactly what you verify at the end of Challenge 1. GitHub Copilot CLI picks up the same folder (`/skills list`).

### Modernization-specific skill examples

- "Struts → Spring MVC transformation rules"
- ".NET Framework → .NET 10 breaking-changes checklist"
- "Containerization plan generator for legacy apps"
- "Integration test layers for migrated apps (TestContainers → smoke → Azure → behavioral)"

**Skill vs Agent:** A skill is *knowledge a task can pull in*; an agent is *an actor that orchestrates tasks*. Agents typically reference several skills.

---

## 4. MCP — Model Context Protocol

MCP is an open protocol that exposes **tools, resources, and prompts** from a server to any MCP-capable client. Each client reads its own configuration file — the formats are **not interchangeable**:

| Client | Configuration location | Format |
|---|---|---|
| **GitHub Copilot CLI** (used in this hack) | `.github/mcp.json` (committed, shared) or `.mcp.json` (local override) in the repo; `~/.copilot/mcp-config.json` (personal) | top-level `mcpServers`, `type: "local"` or `"http"` |
| VS Code | `.vscode/mcp.json` (workspace) or user settings | top-level `servers`, `type: "stdio"` or `"http"` |

Copilot CLI does not read `.vscode/mcp.json` — author each configuration in its own client's file and format. The **GitHub MCP server is built into Copilot CLI** — you only configure additional servers, such as Azure. Copilot CLI example (`.github/mcp.json`):

```json
{
  "mcpServers": {
    "azure": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"],
      "tools": ["*"]
    }
  }
}
```

In Copilot CLI, verify with `/mcp list`; project-level servers load only after you confirm folder trust. Manage personal servers with `/mcp add` or `copilot mcp add`.

### Modernization-specific MCP tooling

The **modernize CLI** ships its assessment, planning, build, and CVE capabilities built in — you don't configure MCP for it. In **VS Code**, the GitHub Copilot **app modernization** extensions register equivalent `appmod-*` MCP tools the agent can call directly:

| Tool family (examples) | Stage | What it does |
|---|---|---|
| `appmod-run-assessment-*`, `appmod-dotnet-run-assessment` (AppCAT) | Assess | Scans code for cloud-readiness & migration issues |
| `appmod-get-plan`, `appmod-recommend-migration-tasks` | Plan | Generates plan.md / tasks.json |
| `appmod-dotnet-build-project`, `appmod-install-maven`, `appmod-install-jdk` | Execute | Build & toolchain management |
| `appmod-dotnet-cve-check`, `appmod-cve-assessment` | Validate | Dependency vulnerability scans |
| `appmod-generate-k8s-manifest`, `appmod-plan-generate-dockerfile`, `appmod-scan-docker-image` | Deploy | Containerization & deployment artifacts |
| Azure MCP server (`azure-mcp`) | Deploy | Resource queries, quotas, deployments, diagnostics |

> You don't need to write an MCP server for this MicroHack — you will **configure** existing ones and let your custom agent call them.

---

## 5. Putting It Together — the Modernization Loop

```mermaid
sequenceDiagram
    participant User
    participant Agent as Custom Agent
    participant Skill as Skills
    participant MCP as MCP Tools

    User->>Agent: "Modernize this app to .NET 10 / Java 25"
    Agent->>MCP: run assessment (AppCAT / appmod)
    MCP-->>Agent: findings report
    Agent->>User: 🚦 GATE — approve plan?
    User->>Agent: approved
    Agent->>Skill: load migration rules / upgrade recipes
    Agent->>MCP: build, fix, iterate
    Agent->>MCP: CVE scan + tests
    Agent->>User: summary + validation evidence
```

Key design principles you will apply in the challenges:

1. **Gates before writes** — the agent must pause for approval after assessment and after planning.
2. **Least-privilege tools** — only list the tools each phase needs.
3. **Skills as triggers, not dumps** — write descriptions with explicit "WHEN:" trigger phrases.
4. **Evidence-based completion** — the agent must show build output + test results + CVE scan before claiming success.

➡️ Continue to the [templates](../templates/) and then [Challenge 1 — Fundamentals](../challenges/challenge-01.md).
