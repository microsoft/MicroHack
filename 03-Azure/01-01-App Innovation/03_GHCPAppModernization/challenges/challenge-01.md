# 1. Fundamentals — Custom Agents, Skills & MCP for App Modernization

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

## Goal

Build the AI foundation you will reuse in the next challenges. Learn how **Custom Agents**, **Skills**, and **MCP (Model Context Protocol)** servers fit together, then author your own modernization Custom Agent, package a reusable Skill, and configure MCP for **GitHub Copilot CLI** — all inside the target repository, where both Copilot CLI and the **modernize CLI** pick them up.

> ⚙️ Complete the [environment setup](../docs/environment-setup.md) first. It creates the recommended Codespace (Copilot CLI and modernize CLI preinstalled) and clones the two sample apps into `repos/`.

## Scenario

Before pointing AI at a real .NET or Java application (challenges 2 and 3), you assemble a reusable, gated modernization playbook. Everything is authored once in the target repository under `.github/`, so it travels with the code and works across surfaces:

- an **Agent** (`.github/agents/`) that defines *who* is working and *how* the assess → plan → execute → validate loop runs (with approval gates),
- a **Skill** (`.github/skills/`) that packages the *domain knowledge* (migration rules, breaking-changes checklist) — the modernize CLI auto-detects these skills when it creates a plan,
- an **MCP** configuration (`.github/mcp.json`) that gives the agent extra *tools* to act (Azure resource queries, quotas, deployments, diagnostics).

Use **`repos/PhotoAlbum-Java`** (cloned during environment setup) as the target repository — it is the same app you upgrade in Challenge 2.

> 📖 Read [docs/00-fundamentals.md](../docs/00-fundamentals.md) first (~15 min). It gives you the mental model: *Agent = who/how*, *Skill = what it knows*, *MCP = what it can do*.

## Actions

* Read [docs/00-fundamentals.md](../docs/00-fundamentals.md) and review the base templates in [templates/](../templates/).
* **Author a Custom Agent** — copy [templates/agents/modernization.agent.md](../templates/agents/modernization.agent.md) to `.github/agents/<name>.agent.md` in the target repo, replace every `{{PLACEHOLDER}}`, and keep the tool allow-list least-privilege. Verify it: run `copilot` inside the repo (confirm folder trust when prompted — you are asked once per folder) and pick your agent with `/agent`.
* **Author a Skill** — copy [templates/skills/modernization-skill/SKILL.md](../templates/skills/modernization-skill/SKILL.md) to `.github/skills/<skill-name>/SKILL.md` (lowercase, hyphenated folder name), set the frontmatter `name:` to match the folder, and write an explicit `WHEN:` trigger description plus at least one transformation-rules table. The `description` is what both Copilot CLI and the modernize CLI match against your prompt. Verify it: `/skills list` in Copilot CLI. Optionally use the [skill-creator](../templates/skills/skill-creator/SKILL.md) meta-skill to iterate.
* **Configure MCP for Copilot CLI** — copy [templates/mcp/copilot-cli-mcp.json](../templates/mcp/copilot-cli-mcp.json) to `.github/mcp.json` in the target repo. Verify it: inside `copilot`, run `/mcp list` — the `azure` server appears (project MCP servers load only in trusted folders; the GitHub MCP server is built in and needs no entry).
* **Dry-run skill detection** — from the target repo, run `modernize plan create "<a prompt that matches your skill's description>"` and confirm the generated plan under `.github/modernize/` references your skill with `"location": "project"` in its `tasks.json`. Create the plan only — execution happens in challenges 2 and 3. Finally, commit your authored `.github/` files on the `modernize` branch so the repository is clean for Challenge 2.
* Compare your work against the pre-tailored references shipped in [templates/](../templates/) (`dotnet-modernization.agent.md`, `dotnet-upgrade`, `java-modernization.agent.md`, `java-upgrade`).

## Success criteria

* You can explain, in one sentence each, what an Agent, a Skill, and an MCP server contribute to a modernization workflow.
* A valid Custom Agent (`.agent.md` with YAML frontmatter) exists in `.github/agents/`, has a phased, gated workflow and a least-privilege tool list, and shows up in Copilot CLI's `/agent` picker.
* A valid Skill (`SKILL.md`) exists in `.github/skills/<skill-name>/` with an explicit `WHEN:` trigger description and at least one rules table, and `/skills list` shows it.
* `.github/mcp.json` resolves in Copilot CLI: `/mcp list` shows the `azure` server.
* A modernize CLI plan created from your prompt references your custom skill in its `tasks.json` — and you have **not** executed the plan.

> 💻 **Using VS Code instead of the CLI?** The same `.github/agents/` files are picked up by VS Code's agent picker. MCP is configured differently there: copy [templates/mcp/mcp.json](../templates/mcp/mcp.json) to `.vscode/mcp.json` and run **MCP: List Servers** — the formats are not interchangeable, and Copilot CLI does not read `.vscode/mcp.json`. The `appmod-*` tool families come from the GitHub Copilot app modernization VS Code extensions; install the one for your stack if you work in the IDE.

> Need the detailed, step-by-step walkthrough? See the [Challenge 1 Solution](../walkthrough/challenge-01/solution-01.md).

## Learning resources

* [About custom agents](https://docs.github.com/en/copilot/concepts/agents/about-custom-agents) and the [custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
* [Add agent skills to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills) · [Agent skills specification](https://agentskills.io/specification)
* [Add MCP servers to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
* [Customize the modernization agent with your own skills](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/customization)
* [GitHub Copilot app modernization for .NET](https://learn.microsoft.com/dotnet/azure/migration/appmod/overview)
* [GitHub Copilot app modernization for Java](https://learn.microsoft.com/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java)
* [Model Context Protocol](https://modelcontextprotocol.io/)
