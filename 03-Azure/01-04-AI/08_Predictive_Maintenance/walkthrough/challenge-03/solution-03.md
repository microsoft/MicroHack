# Challenge 3 walkthrough - Repair Planner Agent and AI-Driven Development

**[Back to challenge](../../challenges/challenge-03.md)**

This walkthrough adds the exact commands, expected code shapes, expected output, and a validation checklist for [Challenge 3](../../challenges/challenge-03.md). It does not repeat the background, scenario, or objective — see the challenge file for that.

> [!TIP]
> A complete reference implementation is available in [`RepairPlanner/`](./RepairPlanner) next to this file. Use it to compare against what `agentplanning` generates for you, or as a fallback if you get stuck — not as a starting point to copy before trying the prompts yourself.

## Prerequisites

* Challenges 1 and 2 completed: `.env` populated, Anomaly Classification and Fault Diagnosis agents working.
* .NET SDK available (`dotnet --version` from Challenge 1).
* The `agentplanning` custom chat mode/agent available in GitHub Copilot Chat's *Agents* dropdown.

## Task 1: Project setup

```bash
cd src
dotnet new console -n RepairPlanner
cd RepairPlanner
```

Expected result: a new `src/RepairPlanner/` folder containing `RepairPlanner.csproj` and `Program.cs`.

## Task 2: Create the RepairPlanner agent with agentplanning

The exact code `agentplanning` generates for each prompt will vary. The shapes below show what a correct answer typically looks like — use them to sanity-check the agent's output, not as literal code to paste.

### Task 2.2: Create data models

<details>
<summary>Expected shape</summary>

```csharp
using System.Text.Json.Serialization;
using Newtonsoft.Json;

public sealed class WorkOrder
{
    [JsonPropertyName("id")]
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    // ... more properties (workOrderNumber, machineId, title, tasks, partUsages, assignedTo, status)
}
```

Each model uses **both** `System.Text.Json` (`[JsonPropertyName]`) and `Newtonsoft.Json` (`[JsonProperty]`) attributes on every serialized property, since the Cosmos DB SDK used by `CosmosDbService` relies on `Newtonsoft.Json` while the rest of the agent code uses `System.Text.Json`.

</details>

### Task 2.4: Create CosmosDbService

<details>
<summary>Expected shape</summary>

```csharp
using Microsoft.Azure.Cosmos;
using RepairPlannerAgent.Models;

namespace RepairPlannerAgent.Services
{
    public class CosmosDbService
    {
        private readonly CosmosClient _client;
        private readonly Container _techniciansContainer;
        private readonly Container _partsContainer;
        private readonly Container _machinesContainer;
        private readonly Container _workOrdersContainer;

        public CosmosDbService(string endpoint, string key, string databaseName)
        {
            _client = new CosmosClient(endpoint, key);
            var database = _client.GetDatabase(databaseName);

            _techniciansContainer = database.GetContainer("Technicians");
            _partsContainer = database.GetContainer("PartsInventory");
            _machinesContainer = database.GetContainer("Machines");
            _workOrdersContainer = database.GetContainer("WorkOrders");
        }

        public async Task<List<Technician>> GetAvailableTechniciansWithSkillsAsync(List<string> requiredSkills) { /* query logic */ }
        public async Task<List<Part>> GetPartsInventoryAsync(List<string> partNumbers) { /* query logic */ }
        public async Task<string> CreateWorkOrderAsync(WorkOrder workOrder) { /* query logic */ }
    }
}
```

If the generated code doesn't read `COSMOS_ENDPOINT`, `COSMOS_KEY`, and `COSMOS_DATABASE_NAME` from environment variables, ask `agentplanning` to wire that up via configuration rather than hardcoding values.

</details>

### Task 2.5: Create the main agent

<details>
<summary>Expected shape</summary>

```csharp
using Azure.AI.Projects;
using Azure.AI.Projects.OpenAI;
using Microsoft.Agents.AI;

public sealed class RepairPlannerAgent(
    AIProjectClient projectClient,
    CosmosDbService cosmosDb,
    IFaultMappingService faultMapping,
    string modelDeploymentName,
    ILogger<RepairPlannerAgent> logger)
{
    private const string AgentName = "RepairPlannerAgent";

    public async Task EnsureAgentVersionAsync(CancellationToken ct = default)
    {
        var definition = new PromptAgentDefinition(model: modelDeploymentName)
        {
            Instructions = "..."
        };
        await projectClient.Agents.CreateAgentVersionAsync(
            AgentName,
            new AgentVersionCreationOptions(definition),
            ct);
    }

    public async Task<WorkOrder> PlanAndCreateWorkOrderAsync(DiagnosedFault fault, CancellationToken ct = default)
    {
        // 1. Get skills/parts from mapping
        // 2. Query Cosmos DB
        // 3. Build prompt and invoke agent
        // 4. Parse and save work order
    }
}
```

</details>

## Task 3: Test your agent

```bash
export $(grep -v '^#' ../../.env | xargs)
dotnet run
```

<details>
<summary>Expected output</summary>

```text
12:34:56 info: RepairPlannerAgent[0] Creating agent 'RepairPlannerAgent' with model 'gpt-5.4'
12:34:57 info: RepairPlannerAgent[0] Agent version: abc123
12:34:57 info: RepairPlannerAgent[0] Planning repair for machine-001, fault=curing_temperature_excessive
12:34:58 info: CosmosDbService[0] Found 3 available technicians matching skills
12:34:58 info: CosmosDbService[0] Fetched 2 parts
12:34:58 info: RepairPlannerAgent[0] Invoking agent 'RepairPlannerAgent'
12:35:05 info: Program[0] Saved work order WO-2026-001 (id=xxx, status=new, assignedTo=tech-001)

{
  "id": "...",
  "workOrderNumber": "WO-2026-001",
  "machineId": "machine-001",
  "title": "Repair Curing Temperature Issue",
  ...
}
```

</details>

## Troubleshooting

* **`dotnet run` fails with a missing package error:** confirm the generated `.csproj` includes `Microsoft.Azure.Cosmos` and the Foundry Agents SDK packages (`Azure.AI.Projects`, `Microsoft.Agents.AI`). If `agentplanning` didn't add them, run `dotnet add package <PackageName>` manually.
* **`CosmosException: Unauthorized` or `Forbidden`:** confirm `.env` was exported in the current shell (`export $(grep -v '^#' ../../.env | xargs)`) and that `COSMOS_ENDPOINT`/`COSMOS_KEY` resolve to non-empty values.
* **No technicians or parts are found:** confirm `FaultMappingService`'s hardcoded skill/part mapping actually includes the fault type used in your sample data (e.g. `curing_temperature_excessive`), and that the Cosmos DB queries filter on the correct partition key (`/department` for `Technicians`, `/category` for `PartsInventory`).
* **The agent's response can't be parsed into a `WorkOrder`:** check that the agent's instructions ask for a JSON-only response and that both `System.Text.Json` and `Newtonsoft.Json` attributes are present on the model.

## Validation checklist

* [ ] `src/RepairPlanner/` project created and builds (`dotnet build`).
* [ ] Data models (`DiagnosedFault`, `Technician`, `Part`, `WorkOrder`, `RepairTask`, `WorkOrderPartUsage`) exist under `Models/` with dual JSON attributes.
* [ ] `FaultMappingService` maps at least the sample fault type to skills and parts.
* [ ] `CosmosDbService` queries technicians, parts, and creates work orders against the correct containers.
* [ ] `RepairPlannerAgent` registers/ensures an agent version and orchestrates the full planning workflow.
* [ ] `dotnet run` completes and prints a saved work order with a generated work order number.
* [ ] Output compared against [`RepairPlanner/`](./RepairPlanner) reference solution for any steps where you got stuck.

**Next:** [Challenge 4 walkthrough](../challenge-04/solution-04.md)
