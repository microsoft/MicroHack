using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.AI.Projects;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Foundry;
using Microsoft.Extensions.Logging;
using RepairPlanner.Models;
using RepairPlanner.Services;

namespace RepairPlanner;

/// <summary>
/// Repair Planner Agent: generates work orders for diagnosed faults using a Foundry Prompt Agent.
/// </summary>
/// <remarks>
/// This class uses a "primary constructor" - the parameters after the class name
/// become available as fields throughout the class (similar to Python's __init__).
/// </remarks>
public sealed class RepairPlannerAgent(
    AIProjectClient projectClient,
    CosmosDbService cosmosDb,
    IFaultMappingService faultMapping,
    string modelDeploymentName,
    ILogger<RepairPlannerAgent> logger)
{
    private const string AgentName = "RepairPlannerAgent";
    private const string AgentInstructions = """
        You are a Repair Planner Agent for tire manufacturing equipment.
        Generate a repair plan with tasks, timeline, and resource allocation.
        Return the response as valid JSON matching the WorkOrder schema.
        
        Output JSON with these fields:
        - workOrderNumber, machineId, title, description
        - type: "corrective" | "preventive" | "emergency"
        - priority: "critical" | "high" | "medium" | "low"
        - status, assignedTo (technician id or null), notes
        - estimatedDuration: integer (minutes, e.g. 60 not "60 minutes")
        - partsUsed: [{ partId, partNumber, quantity }]
        - tasks: [{ sequence, title, description, estimatedDurationMinutes (integer), requiredSkills, safetyNotes }]
        
        IMPORTANT: All duration fields must be integers representing minutes (e.g. 90), not strings like "90 minutes".
        
        Rules:
        - Assign the most qualified available technician
        - Include only relevant parts; empty array if none needed
        - Tasks must be ordered and actionable
        """;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        NumberHandling = JsonNumberHandling.AllowReadingFromString,
    };
    private ChatClientAgent? agent;

    /// <summary>
    /// Initializes a Foundry Responses-backed agent.
    /// </summary>
    public async Task EnsureAgentVersionAsync(CancellationToken ct = default)
    {
        agent = projectClient.AsAIAgent(
            model: modelDeploymentName,
            instructions: AgentInstructions,
            name: AgentName,
            description: "Generates work orders for diagnosed faults.");
        logger.LogInformation("Initialized agent '{AgentName}' with model '{Model}'", AgentName, modelDeploymentName);
        await Task.CompletedTask;
    }

    /// <summary>
    /// Plans and creates a work order for the given diagnosed fault.
    /// </summary>
    public async Task<WorkOrder> PlanAndCreateWorkOrderAsync(DiagnosedFault fault, CancellationToken ct = default)
    {
        var requiredSkills = faultMapping.GetRequiredSkills(fault.FaultType);
        var requiredParts = faultMapping.GetRequiredParts(fault.FaultType);

        logger.LogInformation("Planning repair for {MachineId}, fault={FaultType}", fault.MachineId, fault.FaultType);

        var technicians = await cosmosDb.QueryAvailableTechniciansBySkillsAsync(requiredSkills, cancellationToken: ct);
        var parts = await cosmosDb.GetPartsByPartNumbersAsync(requiredParts, cancellationToken: ct);

        var prompt = BuildPrompt(fault, technicians, parts);
        var responseText = await InvokeAgentAsync(prompt, ct);

        var workOrder = ParseWorkOrder(responseText);
        ApplyDefaults(workOrder, fault, technicians, requiredSkills);

        return await cosmosDb.CreateWorkOrderAsync(workOrder, ct);
    }

    private async Task<string> InvokeAgentAsync(string input, CancellationToken ct)
    {
        logger.LogInformation("Invoking agent '{AgentName}'", AgentName);
        agent ??= projectClient.AsAIAgent(
            model: modelDeploymentName,
            instructions: AgentInstructions,
            name: AgentName,
            description: "Generates work orders for diagnosed faults.");
        var response = await agent.RunAsync(input, session: null, options: null, cancellationToken: ct);
        return response.Text ?? "";
    }

    private static WorkOrder ParseWorkOrder(string content)
    {
        // Extract JSON from response (may contain markdown)
        var start = content.IndexOf('{');
        var end = content.LastIndexOf('}');
        var json = (start >= 0 && end > start) ? content[start..(end + 1)] : content;

        return JsonSerializer.Deserialize<WorkOrder>(json, JsonOptions)
            ?? throw new InvalidOperationException("Failed to parse work order from agent response");
    }

    private void ApplyDefaults(WorkOrder wo, DiagnosedFault fault, IReadOnlyList<Technician> techs, IReadOnlyList<string> skills)
    {
        // ??= means "assign if null" (like Python's: wo.SourceFault = wo.SourceFault or fault)
        wo.SourceFault ??= fault;
        wo.MachineId ??= fault.MachineId;
        wo.Type ??= "corrective";
        wo.Priority ??= fault.Severity?.ToLowerInvariant() ?? "medium";
        wo.Status ??= "new";

        // Validate or assign technician
        if (wo.AssignedTo != null && !techs.Any(t => t.Id == wo.AssignedTo))
        {
            logger.LogWarning("Invalid technician {Id}, clearing", wo.AssignedTo);
            wo.AssignedTo = null;
        }

        if (wo.AssignedTo == null && techs.Count > 0)
        {
            var skillSet = skills.ToHashSet(StringComparer.OrdinalIgnoreCase);
            wo.AssignedTo = techs
                .OrderByDescending(t => t.Skills.Count(s => skillSet.Contains(s)))
                .First().Id;
            logger.LogInformation("Assigned technician {Id}", wo.AssignedTo);
        }
    }

    private static string BuildPrompt(DiagnosedFault fault, IReadOnlyList<Technician> technicians, IReadOnlyList<Part> parts) => $"""
        Generate a repair plan for:
        - Machine: {fault.MachineId}
        - Fault Type: {fault.FaultType}
        - Root Cause: {fault.RootCause}
        - Severity: {fault.Severity}
        - Detected: {fault.DetectedAt:O}
        - Metadata: {JsonSerializer.Serialize(fault.Metadata)}

        Available Technicians:
        {JsonSerializer.Serialize(technicians)}

        Available Parts:
        {JsonSerializer.Serialize(parts)}

        Return ONLY valid JSON matching the WorkOrder schema.
        """;
}
