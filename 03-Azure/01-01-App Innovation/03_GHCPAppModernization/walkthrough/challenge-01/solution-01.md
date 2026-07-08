# Fundamentals — Custom Agents, Skills & MCP

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-02/solution-02.md)

**Duration:** 30 minutes

## Goal

Author a reusable, gated modernization Custom Agent, package a Skill, and configure the MCP tools that back the assess → plan → execute → validate loop used in the .NET and Java challenges.

## Actions

### Understand the model

1. Read [docs/00-fundamentals.md](../../docs/00-fundamentals.md).
2. Remember the rule of thumb:
   - **Agent** = *who* is working and *how* the workflow runs (role + gates + tool allow-list).
   - **Skill** = *what* the agent knows (loaded only when the task matches — progressive disclosure).
   - **MCP** = *what* the agent can do (tools with typed inputs/outputs).

### Author a Custom Agent

1. Copy [templates/agents/modernization.agent.md](../../templates/agents/modernization.agent.md) into your target repo at `.github/agents/modernization.agent.md`.
2. Replace every `{{PLACEHOLDER}}`: role, application, source/target platform, in/out of scope.
3. Keep the phased workflow with **Gate 1 (after assessment)** and **Gate 2 (after plan)**.
4. Trim the `tools:` allow-list to least privilege — the assess phase should *not* include `editFiles`.
5. Reload VS Code and confirm the agent appears in the Copilot Chat agent picker.

> ✅ Reference answer: [templates/agents/dotnet-modernization.agent.md](../../templates/agents/dotnet-modernization.agent.md) and [templates/agents/java-modernization.agent.md](../../templates/agents/java-modernization.agent.md).

### Author a Skill

1. Copy [templates/skills/modernization-skill/SKILL.md](../../templates/skills/modernization-skill/SKILL.md) to `.github/skills/<skill-name>/SKILL.md`.
2. Write the `description` as a routing contract: start it with an explicit `WHEN:` list of trigger phrases, and add a `NOT for:` line to prevent false triggering.
3. Fill in the **Procedure** with at least one transformation-rules table (source pattern → target pattern → notes) and a verification checklist.
4. (Optional) Use the [skill-creator](../../templates/skills/skill-creator/SKILL.md) meta-skill to test and iterate on the description.

> ✅ Reference answers: [templates/skills/dotnet-upgrade/SKILL.md](../../templates/skills/dotnet-upgrade/SKILL.md) and [templates/skills/java-upgrade/SKILL.md](../../templates/skills/java-upgrade/SKILL.md).

### Configure MCP

1. Copy [templates/mcp/mcp.json](../../templates/mcp/mcp.json) to `.vscode/mcp.json`.
2. Remove servers you don't need; keep `azure` and `github` if relevant.
3. Open the Command Palette → **MCP: List Servers** and start/inspect the servers.
4. Confirm the `appmod-*` tool families appear in the agent's tool picker — they are registered automatically by the GitHub Copilot app modernization extensions (install the extension for your stack; no `mcp.json` entry needed).

### Dry-run the gated loop

1. Select your Custom Agent in Copilot Chat.
2. Prompt: *"Modernize this application following your workflow."*
3. Verify the agent runs the assessment and **stops at Gate 1** with an `ASSESSMENT.md`, then **stops at Gate 2** with a `PLAN.md` — without editing any source code.
4. Approve to continue, or reject the plan once on purpose and watch the agent revise it.

## Success Criteria

- ✅ You can explain Agent vs Skill vs MCP in one sentence each
- ✅ A valid `.agent.md` exists with a gated, phased workflow and a least-privilege tool list
- ✅ A valid `SKILL.md` exists with an explicit `WHEN:` trigger description and a rules table
- ✅ `.vscode/mcp.json` resolves via **MCP: List Servers**; `appmod-*` tools are visible to the agent
- ✅ The agent respects Gate 1 and Gate 2 and does not modify code before approval

## Learning Resources

- [Custom chat modes / agents in VS Code](https://code.visualstudio.com/docs/copilot/chat/chat-modes)
- [MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
- [GitHub Copilot app modernization for .NET](https://learn.microsoft.com/dotnet/core/porting/github-copilot-app-modernization-overview)
- [GitHub Copilot app modernization for Java](https://learn.microsoft.com/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java)
- [Model Context Protocol](https://modelcontextprotocol.io/)
