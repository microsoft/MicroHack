# Copilot custom instructions (workshop mode)

This repo is used for a workshop/exercise.

## Key goal
Help the developer build the solution from context and instructions, **not** by copying an existing completed implementation.

## Source of truth
- For Challenge 3 (Repair Planner), follow the agent guidance in `.github/agents/agentplanning.agent.md`.
- Use the **Foundry Agents SDK** pattern (`Azure.AI.Projects` + `Microsoft.Agents.AI`), not direct ChatCompletions.

## Do not use solution code as a template
Unless the user explicitly asks to reveal or compare with a solution, **do not open, reference, or reuse code** from any folder intended to contain completed answers, for example:
- `walkthrough/**/RepairPlanner/**`
- `walkthrough/**`
- `**/*solution*/**`
- `**/*Solution*/**`
- `**/reference/**`

If such folders exist in the workspace, treat them as off-limits.

## How to proceed instead
- Ask clarifying questions only when required.
- Implement incrementally in the exercise project.
- Prefer small, verifiable changes; keep logging helpful.

## Smaller-model friendly (CRITICAL)

This workshop must work reliably with smaller models (e.g., GPT-5-mini). Follow these constraints:

### Output constraints
- Prefer producing a small number of **complete files** per request (1-3) over partial snippets
- Keep responses structured: **What you will change**, **Files**, **How to run/verify**
- Avoid optional extras unless explicitly requested (no extra abstractions, no extra models)
- When uncertain, state assumptions explicitly and proceed with a safe default

### Pinned versions (Challenge 3)
Always use these exact NuGet package versions:
- `Azure.AI.Projects` → `2.1.0-beta.4`
- `Azure.Identity` → `1.21.0`
- `Microsoft.Agents.AI` → `1.20.0`
- `Microsoft.Agents.AI.Foundry` → `1.20.0-preview.260831.1`
- `Microsoft.Extensions.AI` → `10.9.0`
- `Microsoft.Extensions.AI.Abstractions` → `10.9.0`
- `Microsoft.Azure.Cosmos` → `3.63.0`
- `Microsoft.Extensions.DependencyInjection` → `10.0.12`
- `Microsoft.Extensions.Logging` → `10.0.12`
- `Microsoft.Extensions.Logging.Console` → `10.0.12`
- `Newtonsoft.Json` → `13.0.4`

### Environment variables (Challenge 3)
- `AZURE_AI_PROJECT_ENDPOINT`
- `MODEL_DEPLOYMENT_NAME`
- `COSMOS_ENDPOINT`
- `COSMOS_KEY`
- `COSMOS_DATABASE_NAME`

### Fault→skills/parts mappings
Use the hardcoded mappings from `.github/agents/agentplanning.agent.md` - implement as in-memory dictionaries in `FaultMappingService`.

## Code style for Python developers

Add brief comments explaining C#-specific idioms:
- `??` and `??=` operators (null coalescing)
- Primary constructors
- `await using` (like Python's `async with`)

## What NOT to do
- ❌ Don't use `Azure.AI.Inference` / `ChatCompletionsClient` - use Foundry Agents SDK
- ❌ Don't generate partial code snippets - generate complete files
- ❌ Don't add extra abstractions not in the spec
- ❌ Don't use different package versions than specified
