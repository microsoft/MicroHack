using Azure.AI.Projects;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.A2A;
using Microsoft.Extensions.Logging;
using FactoryWorkflow.RepairPlanner;
using FactoryWorkflow.RepairPlanner.Services;
using A2A;

namespace FactoryWorkflow;

/// <summary>
/// Provides agents hosted in Azure AI Foundry (Agent Service).
/// These are v2 Prompt Agents created and managed in the Azure AI Foundry portal.
/// </summary>
public static class AgentServiceProvider
{
    /// <summary>
    /// Retrieves agents from Azure AI Foundry Agent Service.
    /// - AnomalyClassificationAgent: Classifies telemetry anomalies by severity
    /// - FaultDiagnosisAgent: Diagnoses root causes of detected anomalies
    /// </summary>
    public static List<AIAgent> GetAgents(AIProjectClient projectClient, ILogger logger)
    {
        var agents = new List<AIAgent>();

        // AnomalyClassificationAgent - classifies severity of telemetry anomalies
        var anomalyAgent = projectClient
            .AsAIAgent("AnomalyClassificationAgent")
            .AsBuilder()
            .UseOpenTelemetry(sourceName: "AnomalyClassificationAgent")
            .Build();
        agents.Add(anomalyAgent);
        logger.LogInformation("Retrieved Agent Service agent: {AgentName}", anomalyAgent.Name);

        // FaultDiagnosisAgent - diagnoses root causes using knowledge base
        var faultAgent = projectClient
            .AsAIAgent("FaultDiagnosisAgent")
            .AsBuilder()
            .UseOpenTelemetry(sourceName: "FaultDiagnosisAgent")
            .Build();
        agents.Add(faultAgent);
        logger.LogInformation("Retrieved Agent Service agent: {AgentName}", faultAgent.Name);

        return agents;
    }
}

/// <summary>
/// Provides locally-hosted agents that use Azure OpenAI directly.
/// These agents have custom tools (e.g., Cosmos DB) that aren't available in Agent Service.
/// </summary>
public static class LocalAgentProvider
{
    /// <summary>
    /// Creates the RepairPlannerAgent which uses Cosmos DB tools for work order management.
    /// This agent runs locally using Azure OpenAI and has access to:
    /// - GetAvailableTechnicians: Query technicians from Cosmos DB
    /// - GetAvailableParts: Query parts inventory from Cosmos DB
    /// - CreateWorkOrder: Create work orders in Cosmos DB
    /// </summary>
    public static AIAgent? GetRepairPlannerAgent(
        IConfiguration config,
        ILoggerFactory loggerFactory,
        ILogger logger)
    {
        var aoaiEndpoint = config["AZURE_OPENAI_ENDPOINT"];
        var aoaiDeployment = config["AZURE_OPENAI_DEPLOYMENT_NAME"] ?? "gpt-5.4";
        var cosmosEndpoint = config["COSMOS_ENDPOINT"];
        var cosmosKey = config["COSMOS_KEY"];
        var cosmosDatabase = config["COSMOS_DATABASE"] ?? "FactoryOpsDB";

        if (string.IsNullOrEmpty(aoaiEndpoint))
        {
            logger.LogWarning("AZURE_OPENAI_ENDPOINT not configured - RepairPlannerAgent will be skipped");
            return null;
        }

        try
        {
            // Create Cosmos DB service for the tools (if configured)
            CosmosDbService? cosmosService = null;
            if (!string.IsNullOrEmpty(cosmosEndpoint) && !string.IsNullOrEmpty(cosmosKey))
            {
                cosmosService = new CosmosDbService(
                    cosmosEndpoint, cosmosKey, cosmosDatabase,
                    loggerFactory.CreateLogger<CosmosDbService>());
                logger.LogInformation("CosmosDbService created for RepairPlannerAgent tools");
            }

            var agent = RepairPlannerAgentFactory.Create(
                aoaiEndpoint, aoaiDeployment, cosmosService, loggerFactory);

            logger.LogInformation("Created local agent: {AgentName} at {Endpoint}", agent.Name, aoaiEndpoint);
            return agent;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not create RepairPlannerAgent - skipping");
            return null;
        }
    }
}

/// <summary>
/// Provides agents via the Agent-to-Agent (A2A) protocol.
/// These agents are hosted in a separate Python service and communicate via HTTP.
/// </summary>
public static class A2AAgentProvider
{
    /// <summary>
    /// Retrieves agents from A2A-compatible endpoints (Python services from Challenge 3).
    /// - MaintenanceSchedulerAgent: Schedules maintenance windows based on technician availability
    /// - PartsOrderingAgent: Orders required parts for repairs
    /// </summary>
    public static async Task<List<AIAgent>> GetAgentsAsync(IConfiguration config, ILogger logger)
    {
        var agents = new List<AIAgent>();

        // MaintenanceSchedulerAgent - schedules maintenance windows
        var maintenanceSchedulerUrl = config["MAINTENANCE_SCHEDULER_AGENT_URL"];
        if (!string.IsNullOrEmpty(maintenanceSchedulerUrl))
        {
            var agent = await ResolveA2AAgentAsync(maintenanceSchedulerUrl, "MaintenanceSchedulerAgent", logger);
            if (agent != null) agents.Add(agent);
        }
        else
        {
            logger.LogWarning("MAINTENANCE_SCHEDULER_AGENT_URL not configured - MaintenanceSchedulerAgent will be skipped");
        }

        // PartsOrderingAgent - orders required parts
        var partsOrderingUrl = config["PARTS_ORDERING_AGENT_URL"];
        if (!string.IsNullOrEmpty(partsOrderingUrl))
        {
            var agent = await ResolveA2AAgentAsync(partsOrderingUrl, "PartsOrderingAgent", logger);
            if (agent != null) agents.Add(agent);
        }
        else
        {
            logger.LogWarning("PARTS_ORDERING_AGENT_URL not configured - PartsOrderingAgent will be skipped");
        }

        return agents;
    }

    private static async Task<AIAgent?> ResolveA2AAgentAsync(string url, string agentName, ILogger logger)
    {
        try
        {
            var cardResolver = new A2ACardResolver(new Uri(url.TrimEnd('/') + "/"));
            var agent = await cardResolver.GetAIAgentAsync();
            logger.LogInformation("Retrieved A2A agent: {AgentName} at {Url}", agent.Name, url);
            return agent;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to resolve A2A agent {AgentName} at {Url}", agentName, url);
            return null;
        }
    }
}
