# Organizer VM and Copilot preparation

This is organizer work, not participant preflight. Use it with the
[deployment guide](README.md) and retain private evidence for the actual event.
No configuration below is a tested event toolchain or permission to deploy.

## Prepare and pin both hosts

Resolve and record the tested image, tool/bundle commits and versions, authoring
CLI/MCP dependencies, extensions, PBIR schemas and approved available model.
Prepare the immutable portable packages and distinct host payloads required by
bootstrap before admitting participants. Do not auto-update the event image.

Current upstream Copilot CLI package names are:

```text
/plugin marketplace add microsoft/skills-for-fabric
/plugin install fabric-skills@fabric-collection
/plugin install powerbi-authoring@fabric-collection
```

These are interactive Copilot CLI commands, not PowerShell or a version lock.
Resolve the exact tested bundle/dependency versions before assembling the event
payload. A consumption-only MCP cannot author a notebook, model or populated report.

For the VS Code alternative, prepare the tested Copilot extensions and the same
skill content at project scope using the tested APM path:

```powershell
apm install microsoft/skills-for-fabric --skill spark-authoring-cli --target copilot
apm install microsoft/skills-for-fabric --skill semantic-model-authoring --target copilot
apm install microsoft/skills-for-fabric --skill powerbi-report-authoring --target copilot
```

Verify those names against the pinned upstream commit and lock APM/dependency
resolution before use. Review generated `.vscode/mcp.json` separately. Project
`copilot` MCP targets VS Code; CLI uses its own user-scoped configuration.
CLI installation does not configure VS Code. Review executables, package versions,
interactive authentication and consent. Never embed or copy shared tokens.

## Establish access and prove the journey

Before participant provisioning, verify enabled Power BI service plans, available
seat stock, usage location and propagation; prefer preassigned E5/Pro. Eligible
administrator-acquired trials are only a billing/expiry-sensitive fallback, not
guaranteed procurement. F16 alone does not author-license users.

Preflight workspace creation/assignment and supported item-policy coverage,
including managed SQL endpoints and newly assigned workspaces. Participants
create their own workspace in Challenge 1 and never receive capacity admin.

In the separately authorized disposable pilot, complete all three challenges
through **each host** (AC-11), checking actual server startup, authoring tools,
Fabric/Power BI authentication and required token audiences, execution, queries
and rendering. Record host, OS/image, tools/extensions/plugins/MCP versions,
approved model, schema versions, date and source ref privately. Installation or
config shape alone is not proof of working authoring.

Before admitting participants, verify both scenario datasets, dictionary and
briefs are staged and checksum-valid. Give participants the approved version
record, identity, capacity ID, workspace naming guidance and support route.
They follow the separate participant checklist; missing packages or entitlements
remain organizer responsibilities. The portal is a website, not installed software
or a license. Live acceptance remains NOT VALIDATED until actual evidence exists.
