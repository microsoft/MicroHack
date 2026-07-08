# Fundamentals — Custom Agents, Skills & MCP for App Modernization

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

## Goal

Build the AI foundation you will reuse in the next challenges. Learn how **GitHub Copilot Custom Agents**, **Skills**, and **MCP (Model Context Protocol)** servers fit together, then author your own modernization Custom Agent, package a reusable Skill, and configure the MCP tools that let the agent assess, build, and validate a legacy application.

## Scenario

Before pointing AI at a real .NET or Java application (challenges 2 and 3), you assemble a reusable, gated modernization playbook:

- an **Agent** that defines *who* is working and *how* the assess → plan → execute → validate loop runs (with approval gates),
- a **Skill** that packages the *domain knowledge* (migration rules, breaking-changes checklist) the agent pulls in on demand,
- an **MCP** configuration that gives the agent the *tools* to act (assessment, build, CVE scan, deployment).

> 📖 Read [docs/00-fundamentals.md](../docs/00-fundamentals.md) first (~15 min). It gives you the mental model: *Agent = who/how*, *Skill = what it knows*, *MCP = what it can do*.

## Actions

* Read [docs/00-fundamentals.md](../docs/00-fundamentals.md) and review the base templates in [templates/](../templates/).
* **Author a Custom Agent** — copy [templates/agents/modernization.agent.md](../templates/agents/modernization.agent.md) to `.github/agents/<name>.agent.md` in a target repo, replace every `{{PLACEHOLDER}}`, and tighten the tool allow-list so the assessment phase stays read-only (least privilege).
* **Author a Skill** — copy [templates/skills/modernization-skill/SKILL.md](../templates/skills/modernization-skill/SKILL.md) to `.github/skills/<skill-name>/SKILL.md`, and write an explicit `WHEN:` trigger description plus at least one transformation-rules table. Optionally use the [skill-creator](../templates/skills/skill-creator/SKILL.md) meta-skill to iterate.
* **Configure MCP** — copy [templates/mcp/mcp.json](../templates/mcp/mcp.json) to `.vscode/mcp.json`, then run **MCP: List Servers** and confirm the `appmod-*` tools (registered by the App Modernization extensions) appear in the agent's tool picker.
* **Dry-run the loop** — select your Custom Agent in Copilot Chat and prompt it to modernize a sample. Confirm it **stops at Gate 1 (assessment)** and **Gate 2 (plan)** before editing any code.
* Compare your work against the pre-tailored references shipped in [templates/](../templates/) (`dotnet-modernization.agent.md`, `dotnet-upgrade`, `java-modernization.agent.md`, `java-upgrade`).

## Success criteria

* You can explain, in one sentence each, what an Agent, a Skill, and an MCP server contribute to a modernization workflow.
* A valid Custom Agent (`.agent.md` with YAML frontmatter) exists, with a phased, gated workflow and a least-privilege tool list.
* A valid Skill (`SKILL.md`) exists with an explicit `WHEN:` trigger description and at least one rules table.
* `.vscode/mcp.json` is configured and **MCP: List Servers** resolves the servers; the `appmod-*` tools are visible to the agent.
* When run, the agent respects the gates — it does **not** modify code before the assessment and plan are approved.

## Learning resources

* [Custom chat modes / agents in VS Code](https://code.visualstudio.com/docs/copilot/chat/chat-modes)
* [MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
* [GitHub Copilot app modernization for .NET](https://learn.microsoft.com/dotnet/core/porting/github-copilot-app-modernization-overview)
* [GitHub Copilot app modernization for Java](https://learn.microsoft.com/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java)
* [Model Context Protocol](https://modelcontextprotocol.io/)
