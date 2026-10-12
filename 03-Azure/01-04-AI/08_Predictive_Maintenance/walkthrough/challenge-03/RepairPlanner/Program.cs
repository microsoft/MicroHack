using System;
using System.Text.Json;
using Azure.AI.Projects;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RepairPlanner;
using RepairPlanner.Models;
using RepairPlanner.Services;

// ============================================================================
// Dependency Injection Setup
// Similar to Python's dependency injection frameworks, we register services
// in a container and resolve them later. This wires up all the components.
// ============================================================================
var services = new ServiceCollection();

services.AddLogging(builder =>
{
    builder.ClearProviders();
    builder.AddSimpleConsole(o =>
    {
        o.SingleLine = true;
        o.TimestampFormat = "HH:mm:ss ";
    });
    builder.SetMinimumLevel(LogLevel.Information);
});

// AI Project Client
var aiProjectEndpoint = GetRequiredEnvVar("AZURE_AI_PROJECT_ENDPOINT");
services.AddSingleton(_ => new AIProjectClient(new Uri(aiProjectEndpoint), new DefaultAzureCredential()));

// Cosmos DB
var cosmosOptions = new CosmosDbOptions
{
    Endpoint = GetRequiredEnvVar("COSMOS_ENDPOINT"),
    Key = GetRequiredEnvVar("COSMOS_KEY"),
    DatabaseName = GetRequiredEnvVar("COSMOS_DATABASE_NAME"),
};
services.AddSingleton(cosmosOptions);

services.AddSingleton(_ =>
{
    var clientOptions = new CosmosClientOptions
    {
        ConnectionMode = ConnectionMode.Gateway,
    };
    return new CosmosClient(cosmosOptions.Endpoint, cosmosOptions.Key, clientOptions);
});

services.AddSingleton<CosmosDbService>(sp =>
{
    var client = sp.GetRequiredService<CosmosClient>();
    var logger = sp.GetRequiredService<ILogger<CosmosDbService>>();
    return new CosmosDbService(
        client,
        cosmosOptions.DatabaseName,
        logger,
        cosmosOptions.TechniciansContainerName,
        cosmosOptions.PartsInventoryContainerName,
        cosmosOptions.WorkOrdersContainerName);
});

// Fault mapping service
services.AddSingleton<IFaultMappingService, FaultMappingService>();

// Repair Planner Agent
services.AddSingleton(sp => new RepairPlannerAgent(
    sp.GetRequiredService<AIProjectClient>(),
    sp.GetRequiredService<CosmosDbService>(),
    sp.GetRequiredService<IFaultMappingService>(),
    GetRequiredEnvVar("MODEL_DEPLOYMENT_NAME"),
    sp.GetRequiredService<ILogger<RepairPlannerAgent>>()));

// ============================================================================
// Run the workflow
// ============================================================================
// "await using" ensures the provider is disposed (like Python's "async with")
await using var provider = services.BuildServiceProvider();
var logger = provider.GetRequiredService<ILoggerFactory>().CreateLogger("Program");

// Get the planner and ensure the agent version is registered
var planner = provider.GetRequiredService<RepairPlannerAgent>();
await planner.EnsureAgentVersionAsync();

// Sample fault for demonstration
var sampleFault = new DiagnosedFault
{
    MachineId = "machine-001",
    FaultType = "curing_temperature_excessive",
    Severity = "high",
    RootCause = "Heater element likely failing or thermocouple drift causing overshoot.",
    DetectedAt = DateTimeOffset.UtcNow,
    Metadata =
    {
        ["temperatureC"] = 195,
        ["setpointC"] = 170,
        ["pressureBar"] = 150,
    },
};

try
{
    var saved = await planner.PlanAndCreateWorkOrderAsync(sampleFault);
    logger.LogInformation(
        "Saved work order {WorkOrderNumber} (id={Id}, status={Status}, assignedTo={AssignedTo})",
        saved.WorkOrderNumber,
        saved.Id,
        saved.Status,
        saved.AssignedTo ?? "<unassigned>");  // ?? means "if null, use this instead" (like Python's "or")

    Console.WriteLine(JsonSerializer.Serialize(saved, new JsonSerializerOptions { WriteIndented = true }));
}
catch (Exception ex)
{
    logger.LogError(ex, "Repair planning workflow failed.");
    Environment.ExitCode = 1;
}

// Helper to get required environment variables (like os.environ.get() but throws if missing)
static string GetRequiredEnvVar(string name) =>
    Environment.GetEnvironmentVariable(name)
    ?? throw new InvalidOperationException($"Missing required environment variable: {name}");
