# Fundamentals — Custom Agents, Skills & MCP

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-02/solution-02.md)

**Duration:** 40 minutes

## Goal

Author a reusable, gated modernization Custom Agent, package a Skill, configure MCP for GitHub Copilot CLI, and dry-run skill detection with the modernize CLI — the foundation of the assess → plan → execute → validate loop used in the .NET and Java challenges.

All files are authored in the **target repository** `repos/PhotoAlbum-Java` (cloned during [environment setup](../../docs/environment-setup.md)). The commands below assume the Codespace terminal, which starts in the hack directory.

## Actions

### Understand the model

1. Read [docs/00-fundamentals.md](../../docs/00-fundamentals.md).
2. Remember the rule of thumb:
   - **Agent** = *who* is working and *how* the workflow runs (role + gates + tool allow-list).
   - **Skill** = *what* the agent knows (loaded only when the task matches — progressive disclosure).
   - **MCP** = *what* the agent can do (tools with typed inputs/outputs).
3. Everything lives under `.github/` in the target repo, so it is versioned with the code: `.github/agents/`, `.github/skills/`, `.github/mcp.json`.

### Author a Custom Agent

1. Copy [templates/agents/modernization.agent.md](../../templates/agents/modernization.agent.md) into the target repo:

   ```bash
   cd repos/PhotoAlbum-Java
   mkdir -p .github/agents
   cp "../../templates/agents/modernization.agent.md" .github/agents/modernization.agent.md
   ```

2. Replace every `{{PLACEHOLDER}}`: role, application, source/target platform, in/out of scope.
3. Keep the phased workflow with **Gate 1 (after assessment)** and **Gate 2 (after plan)** — the gate instructions in the body are what stop the agent from editing code before approval.
4. Trim the `tools:` allow-list to least privilege. The list applies to the whole agent, so keep it minimal: an assessment-only agent needs `read` and `search`; add `edit` and `execute` only when the agent is meant to change code and run builds.
5. Verify in Copilot CLI — start it inside the repo and confirm **folder trust** when prompted (you are asked once per folder), then open the agent picker:

   ```bash
   copilot
   ```

   Type `/agent` and confirm your agent is listed. The sample repo ships with a few pre-existing example agents — yours appears alongside them; ignore the others. You can also invoke it non-interactively:

   ```bash
   copilot --agent=modernization --prompt "Summarize your workflow phases and gates."
   ```

> ✅ Reference answer: [templates/agents/dotnet-modernization.agent.md](../../templates/agents/dotnet-modernization.agent.md) and [templates/agents/java-modernization.agent.md](../../templates/agents/java-modernization.agent.md).

### Author a Skill

1. Copy [templates/skills/modernization-skill/SKILL.md](../../templates/skills/modernization-skill/SKILL.md) into the target repo — the skill folder name must be lowercase and hyphenated:

   ```bash
   mkdir -p .github/skills/java-upgrade-playbook
   cp "../../templates/skills/modernization-skill/SKILL.md" .github/skills/java-upgrade-playbook/SKILL.md
   ```

2. Set the frontmatter `name:` to match the folder (`java-upgrade-playbook`), then write the `description` as a routing contract: start it with an explicit `WHEN:` list of trigger phrases, and add a `NOT for:` line to prevent false triggering. Both Copilot CLI and the modernize CLI use this description to decide when the skill applies — vague descriptions ("improve code") are never matched.
3. Fill in the **Procedure** with at least one transformation-rules table (source pattern → target pattern → notes) and a verification checklist.
4. Verify in Copilot CLI: run `/skills list` and confirm the skill appears as a project skill.
5. (Optional) Use the [skill-creator](../../templates/skills/skill-creator/SKILL.md) meta-skill to test and iterate on the description.

> ✅ Reference answers: [templates/skills/dotnet-upgrade/SKILL.md](../../templates/skills/dotnet-upgrade/SKILL.md) and [templates/skills/java-upgrade/SKILL.md](../../templates/skills/java-upgrade/SKILL.md).

### Configure MCP for Copilot CLI

1. Copy [templates/mcp/copilot-cli-mcp.json](../../templates/mcp/copilot-cli-mcp.json) to `.github/mcp.json` in the target repo:

   ```bash
   cp "../../templates/mcp/copilot-cli-mcp.json" .github/mcp.json
   ```

2. Start `copilot` in the repo. Project-level MCP servers are only loaded in trusted folders — you confirmed folder trust during the agent step (if not, confirm it now).
3. Run `/mcp list`: the `azure` server from `.github/mcp.json` appears. The GitHub MCP server is built into Copilot CLI and needs no configuration entry (depending on the CLI version it may not show in the list).
4. Know the configuration levels: `.github/mcp.json` is the shared, committed project config; `.mcp.json` is a local, per-checkout override; `~/.copilot/mcp-config.json` holds your personal servers (manage it with `/mcp add` or `copilot mcp add`). Project definitions take precedence over personal ones.

> 💻 **VS Code route:** VS Code uses its own format and file — copy [templates/mcp/mcp.json](../../templates/mcp/mcp.json) to `.vscode/mcp.json` and run **MCP: List Servers** in the Command Palette. The two formats are not interchangeable — Copilot CLI does not read `.vscode/mcp.json`. The `appmod-*` tool families are registered by the GitHub Copilot app modernization VS Code extensions (install the one for your stack; no MCP entry needed).

### Dry-run skill detection with the modernize CLI

1. From the target repo root, create a plan with a prompt that matches your skill's description — create the plan only, do **not** execute it:

   ```bash
   modernize plan create "upgrade this app to the latest Java LTS and Spring Boot version" --plan-name fundamentals-dry-run
   ```

   Answer the clarifying questions the agent asks. Plan generation takes a few minutes.

2. Confirm your skill was detected — the plan's `tasks.json` references project skills by name:

   ```bash
   grep -rn "java-upgrade-playbook" .github/modernize*
   ```

   Expected (inside `tasks.json`):

   ```json
   "skills": [
     { "name": "java-upgrade-playbook", "location": "project" }
   ]
   ```

   > If grep reports `No such file or directory`, no plan folder exists yet — make sure `modernize plan create` completed successfully before searching.

3. If the skill is not referenced: make the skill `description` more specific (or the prompt closer to it), then re-run with `--overwrite`. Check that the YAML front matter parses and the skill name contains no spaces.
4. **Stop here.** Executing plans is the subject of challenges 2 and 3. Commit your authored files so the repository is clean before Challenge 2 (the modernize CLI git-ignores its own plan folders, so they stay out of the commit):

   ```bash
   git add .github
   git commit -m "Add modernization agent, skill, and MCP config"
   ```

## Success Criteria

- ✅ You can explain Agent vs Skill vs MCP in one sentence each
- ✅ A valid `.agent.md` exists in `.github/agents/` with a gated, phased workflow and a least-privilege tool list, and `/agent` in Copilot CLI lists it
- ✅ A valid `SKILL.md` exists in `.github/skills/<skill-name>/` with an explicit `WHEN:` trigger description and a rules table, and `/skills list` shows it
- ✅ `/mcp list` in Copilot CLI shows the `azure` server from `.github/mcp.json`
- ✅ A modernize CLI plan references your skill in `tasks.json` with `"location": "project"`, and no plan has been executed

## Learning Resources

- [About custom agents](https://docs.github.com/en/copilot/concepts/agents/about-custom-agents) · [Custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Add agent skills to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills) · [Agent skills specification](https://agentskills.io/specification)
- [Add MCP servers to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [Customize the modernization agent with your own skills](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/customization)
- [GitHub Copilot app modernization for .NET](https://learn.microsoft.com/dotnet/azure/migration/appmod/overview)
- [GitHub Copilot app modernization for Java](https://learn.microsoft.com/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java)
- [Model Context Protocol](https://modelcontextprotocol.io/)
