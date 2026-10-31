# Challenge 8 solution: From demo to delivery

**[← Previous Solution](../finish/solution-finish.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-08.md)

**Duration:** 45 minutes

## Expected run

Verified end to end against a lab project in October 2026 with azd 1.37.2 and `azure.ai.agents` 1.0.0-beta.23:

| Step | Result | Time |
|---|---|---|
| `azd ai agent init … --project-id … --model-deployment …` | Creates `ops-agent-code/azure.yaml` pointing at the **existing** project; nothing is provisioned. The project service key is the project's name, for example `frontier-operations`. | about 10 s |
| `azd deploy --all --no-prompt` | Publishes skill `reconciliation-code` version 1, then agent `ops-agent-code` version 1 | about 40 s |
| `azd ai agent show --output json` | `kind: prompt`, `harness.type: microsoft_copilot_preview`, `skills: [{name: reconciliation-code, version: "1"}]`, and `tools: [{type: microsoft_copilot_toolset_preview, configs: [{name: web, enabled: false}]}]` | seconds |
| `azd ai agent invoke --new-conversation …` | Lists `reconciliation-code` (plus the harness's built-in skills) and quotes the tolerance rule | about 10 s |
| Part E: change the tolerance, deploy again | Skill version 2 becomes the default; agent version 2 points at it; invoke quotes the new tolerance | about 35 s |
| Clean-up | *Prompt agent "ops-agent-code" deleted* and *Skill "reconciliation-code" deleted* | seconds |

A skill deployed with azd is a `SKILL.md` package, the same format as `publish-skill`, so the harness loads it.

## Points to discuss

- **Same thing, two front doors.** The portal and `azure.yaml` create the same objects. Teams discover in the portal and ship from source control.
- **What a pull request looks like.** A one-line tolerance change in `SKILL.md` is reviewable by a finance person, and the deploy log says which version went live.
- **Why a new skill name.** Deploying an existing skill name creates a new version of that shared skill and makes it the default for everyone who follows the default. Use separate names, or separate projects, for test and production.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `azd ai agent` is an unknown command | Install the extension: `azd extension install azure.ai.agents`. |
| `harness` is ignored, or the agent is created without it | The extension is older than 1.0.0-beta.22 (`azd extension upgrade azure.ai.agents`), or `AZD_ALPHA_ENABLE_AGENTS_MANAGED_HARNESS=true` isn't set in this terminal. |
| `init` asks to create a new project | Pass `--project-id` with the full `FoundryProjectResourceId` and `--no-prompt`. |
| Deploy fails on the skill | `archive` must point at the folder that contains `SKILL.md`, and the front matter `name:` and `description:` must be unquoted. |
| Permission errors | Use the lab account: `az login --use-device-code` and `azd auth login --use-device-code`. The lab account is a Foundry Project Manager on the project. |
| Someone ran `azd down` | It doesn't remove resources it didn't create, but don't run it: ask the facilitator to check the lab. |
