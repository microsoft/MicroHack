using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using FactoryWorkflow.RepairPlanner.Models;
using FactoryWorkflow.RepairPlanner.Services;

namespace FactoryWorkflow.RepairPlanner;

/// <summary>
/// Factory for creating the RepairPlanner AIAgent with Cosmos DB tools.
/// </summary>
public static class RepairPlannerAgentFactory
{
    // Mock data mappings for fault types to required skills
    private static readonly IReadOnlyDictionary<string, IReadOnlyList<string>> FaultToSkills =
        new Dictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["curing_temperature_excessive"] = new[]
            {
                "tire_curing_press",
                "temperature_control",
                "instrumentation",
                "electrical_systems",
                "plc_troubleshooting",
                "mold_maintenance"
            },
            ["curing_cycle_time_deviation"] = new[]
            {
                "tire_curing_press",
                "plc_troubleshooting",
                "mold_maintenance",
                "bladder_replacement",
                "hydraulic_systems",
                "instrumentation"
            },
            ["building_drum_vibration"] = new[]
            {
                "tire_building_machine",
                "vibration_analysis",
                "bearing_replacement",
                "alignment",
                "precision_alignment",
                "drum_balancing",
                "mechanical_systems"
            },
            ["ply_tension_excessive"] = new[]
            {
                "tire_building_machine",
                "tension_control",
                "servo_systems",
                "precision_alignment",
                "sensor_alignment",
                "plc_programming"
            },
            ["extruder_barrel_overheating"] = new[]
            {
                "tire_extruder",
                "temperature_control",
                "rubber_processing",
                "screw_maintenance",
                "instrumentation",
                "electrical_systems",
                "motor_drives"
            },
            ["low_material_throughput"] = new[]
            {
                "tire_extruder",
                "rubber_processing",
                "screw_maintenance",
                "motor_drives",
                "temperature_control"
            },
            ["high_radial_force_variation"] = new[]
            {
                "tire_uniformity_machine",
                "data_analysis",
                "measurement_systems",
                "tire_building_machine",
                "tire_curing_press"
            },
            ["load_cell_drift"] = new[]
            {
                "tire_uniformity_machine",
                "load_cell_calibration",
                "measurement_systems",
                "sensor_alignment",
                "instrumentation"
            },
            ["mixing_temperature_excessive"] = new[]
            {
                "banbury_mixer",
                "temperature_control",
                "rubber_processing",
                "instrumentation",
                "electrical_systems",
                "mechanical_systems"
            },
            ["excessive_mixer_vibration"] = new[]
            {
                "banbury_mixer",
                "vibration_analysis",
                "bearing_replacement",
                "alignment",
                "mechanical_systems",
                "preventive_maintenance"
            },
        };

    // Mock data mappings for fault types to required parts
    private static readonly IReadOnlyDictionary<string, IReadOnlyList<string>> FaultToParts =
        new Dictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["curing_temperature_excessive"] = new[] { "TCP-HTR-4KW", "GEN-TS-K400" },
            ["curing_cycle_time_deviation"] = new[] { "TCP-BLD-800", "TCP-SEAL-200" },
            ["building_drum_vibration"] = new[] { "TBM-BRG-6220" },
            ["ply_tension_excessive"] = new[] { "TBM-LS-500N", "TBM-SRV-5KW" },
            ["extruder_barrel_overheating"] = new[] { "EXT-HTR-BAND", "GEN-TS-K400" },
            ["low_material_throughput"] = new[] { "EXT-SCR-250", "EXT-DIE-TR" },
            ["high_radial_force_variation"] = Array.Empty<string>(),
            ["load_cell_drift"] = new[] { "TUM-LC-2KN", "TUM-ENC-5000" },
            ["mixing_temperature_excessive"] = new[] { "BMX-TIP-500", "GEN-TS-K400" },
            ["excessive_mixer_vibration"] = new[] { "BMX-BRG-22320", "BMX-SEAL-DP" },
        };
    private const string DefaultInstructions = """
        You are a Repair Planner Agent for factory maintenance operations.
        
        Your role is to analyze diagnosed faults and create detailed repair work orders.
        
        When you receive a fault diagnosis, you should:
        1. Use the GetAvailableTechnicians tool to find technicians with the required skills
        2. Use the GetAvailableParts tool to check parts inventory
        3. Create a detailed repair plan based on the fault and available resources
        4. Use the CreateWorkOrder tool to save the work order to the database
        
        Output your repair plan in a structured format with:
        - Work Order ID (from CreateWorkOrder result)
        - Machine ID (from the input)
        - Fault Type (from the diagnosis)
        - Priority (critical/high/medium/low based on severity)
        - Assigned Technician (from GetAvailableTechnicians)
        - Estimated Duration (in minutes)
        - Repair Tasks (numbered list of steps)
        - Required Parts (from GetAvailableParts)
        - Safety Notes (any precautions)
        
        Always call the tools to get real data from the database.

        List the work order id prominently in your final response.

        """;

    /// <summary>
    /// Creates a RepairPlanner AIAgent with optional Cosmos DB tools.
    /// </summary>
    public static AIAgent Create(
        string azureOpenAIEndpoint,
        string deployment,
        CosmosDbService? cosmosService = null,
        ILoggerFactory? loggerFactory = null)
    {
        var tools = new List<AITool>();

        if (cosmosService != null)
        {
            tools.AddRange(CreateCosmosTools(cosmosService));
        }

        return new AzureOpenAIClient(new Uri(azureOpenAIEndpoint), new AzureCliCredential())
            .GetChatClient(deployment)
            .AsIChatClient()
            .AsBuilder()
            .UseOpenTelemetry(sourceName: "RepairPlannerAgent")
            .Build()
            .AsAIAgent(
                instructions: DefaultInstructions,
                name: "RepairPlannerAgent",
                tools: tools.Count > 0 ? tools : null);
    }

    /// <summary>
    /// Creates the Cosmos DB tools for the RepairPlanner agent.
    /// </summary>
    private static IEnumerable<AITool> CreateCosmosTools(CosmosDbService cosmosService)
    {
        // Tool to get required skills for a fault type (mock implementation)
        yield return AIFunctionFactory.Create(
            (string faultType) =>
            {
                var skills = GetSkillsForFault(faultType);
                // Return mock technicians with matching skills
                var mockTechnicians = new[]
                {
                    new { id = "tech-001", name = "John Smith", skills = skills.Take(3).ToArray(), available = true, department = "Maintenance" },
                    new { id = "tech-002", name = "Jane Doe", skills = skills.Skip(1).Take(3).ToArray(), available = true, department = "Maintenance" },
                    new { id = "tech-003", name = "Bob Wilson", skills = skills.Take(2).ToArray(), available = true, department = "Maintenance" }
                };
                return JsonSerializer.Serialize(mockTechnicians);
            },
            "GetAvailableTechnicians",
            "Gets available technicians with the required skills for a given fault type. " +
            "Parameters: faultType (the diagnosed fault type like 'curing_temperature_excessive', 'building_drum_vibration')");

        // Tool to get required parts for a fault type (mock implementation)
        yield return AIFunctionFactory.Create(
            (string faultType) =>
            {
                var partNumbers = GetPartsForFault(faultType);
                // Return mock parts with inventory info
                var mockParts = partNumbers.Select((pn, i) => new
                {
                    partNumber = pn,
                    name = $"Part {pn}",
                    quantityInStock = 5 + i,
                    available = true,
                    location = $"Warehouse-{(char)('A' + i)}"
                }).ToArray();
                return JsonSerializer.Serialize(mockParts);
            },
            "GetAvailableParts",
            "Gets the required parts for a given fault type from inventory. " +
            "Parameters: faultType (the diagnosed fault type like 'curing_temperature_excessive', 'building_drum_vibration')");

        // Tool to create a work order
        yield return AIFunctionFactory.Create(
            async (string machineId, string faultType, string priority, string assignedTo,
                   int estimatedMinutes, string description, string[] partNumbers) =>
            {
                var workOrder = new WorkOrder
                {
                    Id = $"wo-{DateTime.UtcNow:yyyy}-{Guid.NewGuid().ToString()[..8]}",
                    MachineId = machineId,
                    FaultType = faultType,
                    Priority = priority,
                    AssignedTo = assignedTo,
                    EstimatedDurationMinutes = estimatedMinutes,
                    Description = description,
                    Status = "scheduled",
                    CreatedDate = DateTimeOffset.UtcNow,
                    RequiredParts = partNumbers.Select(p => new PartRequirement { PartNumber = p, Quantity = 1 }).ToList()
                };
                var id = await cosmosService.CreateWorkOrderAsync(workOrder);
                return JsonSerializer.Serialize(new { workOrderId = id, status = "created" });
            },
            "CreateWorkOrder",
            "Creates a new work order in the database. " +
            "Parameters: machineId, faultType, priority (critical/high/medium/low), assignedTo (technician id), " +
            "estimatedMinutes, description, partNumbers (array of required part numbers)");
    }

    /// <summary>
    /// Gets the required skills for a given fault type from the mock mapping.
    /// </summary>
    public static IReadOnlyList<string> GetSkillsForFault(string faultType)
    {
        if (string.IsNullOrWhiteSpace(faultType))
            return Array.Empty<string>();

        return FaultToSkills.TryGetValue(faultType, out var skills)
            ? skills
            : Array.Empty<string>();
    }

    /// <summary>
    /// Gets the required parts for a given fault type from the mock mapping.
    /// </summary>
    public static IReadOnlyList<string> GetPartsForFault(string faultType)
    {
        if (string.IsNullOrWhiteSpace(faultType))
            return Array.Empty<string>();

        return FaultToParts.TryGetValue(faultType, out var parts)
            ? parts
            : Array.Empty<string>();
    }
}
