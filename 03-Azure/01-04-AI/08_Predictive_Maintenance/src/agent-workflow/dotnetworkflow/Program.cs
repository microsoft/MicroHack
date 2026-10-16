using Azure.AI.Projects;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.Exporter;
using FactoryWorkflow;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using System.Diagnostics;
using System.Text.Json;

// ============================================================================
// Application Startup
// ============================================================================

DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

// Configure services
builder.Services.AddHttpClient();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});
builder.Configuration.AddEnvironmentVariables();

// Register Azure AI Project client for Agent Service access
builder.Services.AddSingleton(sp =>
{
    var endpoint = sp.GetRequiredService<IConfiguration>()["AZURE_AI_PROJECT_ENDPOINT"]
        ?? throw new InvalidOperationException("AZURE_AI_PROJECT_ENDPOINT is required");
    return new AIProjectClient(new Uri(endpoint), new AzureCliCredential());
});

builder.Services.AddSingleton<ILoggerFactory>(sp => LoggerFactory.Create(b => b.AddConsole()));

// Configure OpenTelemetry tracing
ConfigureTracing(builder);

var app = builder.Build();
app.UseCors();

// ============================================================================
// API Endpoints
// ============================================================================

app.MapGet("/health", () => Results.Ok(new { Status = "Healthy", Timestamp = DateTimeOffset.UtcNow }));

app.MapPost("/api/analyze_machine", async (
    AnalyzeRequest request,
    AIProjectClient projectClient,
    IConfiguration config,
    ILoggerFactory loggerFactory,
    ILogger<Program> logger) =>
{
    logger.LogInformation("Starting analysis for machine {MachineId}", request.machine_id);

    try
    {
        // ================================================================
        // Step 1: Collect all agents for the workflow pipeline
        // ================================================================
        // The workflow executes agents sequentially, passing text output
        // from each agent to the next. Agent order matters!
        //
        // Pipeline: AnomalyClassification → FaultDiagnosis → RepairPlanner
        //           → MaintenanceScheduler → PartsOrdering
        // ================================================================

        var agents = new List<AIAgent>();

        // Agent Service agents (Azure AI Foundry hosted)
        agents.AddRange(AgentServiceProvider.GetAgents(projectClient, logger));

        // Local agent with Cosmos DB tools
        var repairPlanner = LocalAgentProvider.GetRepairPlannerAgent(config, loggerFactory, logger);
        if (repairPlanner != null) agents.Add(repairPlanner);

        // A2A agents (Python services from Challenge 3)
        agents.AddRange(await A2AAgentProvider.GetAgentsAsync(config, logger));

        logger.LogInformation("Workflow pipeline: [{Agents}]", string.Join(" → ", agents.Select(a => a.Name)));

        // ================================================================
        // Step 2: Build and execute the workflow
        // ================================================================
        // Uses WorkflowBuilder to create a sequential pipeline.
        // TextOnlyAgentExecutor strips MCP tool history between agents
        // to work around SDK deserialization issues.
        // ================================================================

        var telemetryJson = JsonSerializer.Serialize(request);
        var workflowResult = await ExecuteWorkflowAsync(agents, telemetryJson, logger);

        return Results.Ok(workflowResult);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Workflow failed for machine {MachineId}", request.machine_id);
        return Results.Problem(ex.Message);
    }
});

// ============================================================================
// Streaming Endpoint (Server-Sent Events)
// ============================================================================

app.MapPost("/api/analyze_machine/stream", async (
    HttpContext httpContext,
    AIProjectClient projectClient,
    IConfiguration config,
    ILoggerFactory loggerFactory,
    ILogger<Program> logger) =>
{
    // Read request body manually since we're using HttpContext directly
    var request = await httpContext.Request.ReadFromJsonAsync<AnalyzeRequest>();
    if (request == null)
    {
        httpContext.Response.StatusCode = 400;
        await httpContext.Response.WriteAsync("Invalid request body");
        return;
    }

    logger.LogInformation("Starting SSE stream for machine {MachineId}", request.machine_id);

    // Set up SSE response headers
    httpContext.Response.ContentType = "text/event-stream";
    httpContext.Response.Headers.CacheControl = "no-cache";
    httpContext.Response.Headers.Connection = "keep-alive";

    var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    // Helper to send SSE events
    async Task SendEventAsync<T>(T evt) where T : SseEvent
    {
        var json = JsonSerializer.Serialize(evt, jsonOptions);
        await httpContext.Response.WriteAsync($"data: {json}\n\n");
        await httpContext.Response.Body.FlushAsync();
    }

    try
    {
        // Collect agents (same as non-streaming endpoint)
        var agents = new List<AIAgent>();
        agents.AddRange(AgentServiceProvider.GetAgents(projectClient, logger));

        var repairPlanner = LocalAgentProvider.GetRepairPlannerAgent(config, loggerFactory, logger);
        if (repairPlanner != null) agents.Add(repairPlanner);

        agents.AddRange(await A2AAgentProvider.GetAgentsAsync(config, logger));

        // Send workflow_started event
        await SendEventAsync(new SseWorkflowStarted
        {
            AgentPipeline = agents.Select(a => a.Name).ToList()
        });

        // Track agent index for progress updates
        int agentIndex = 0;

        // Set up callback to stream agent completions
        TextOnlyAgentExecutor.SetEventCallback(async (step) =>
        {
            await SendEventAsync(new SseAgentCompleted { Step = step });
            agentIndex++;

            // Send agent_started for next agent if there is one
            if (agentIndex < agents.Count)
            {
                await SendEventAsync(new SseAgentStarted
                {
                    AgentName = agents[agentIndex].Name,
                    AgentIndex = agentIndex
                });
            }
        });

        // Send first agent_started event
        if (agents.Count > 0)
        {
            await SendEventAsync(new SseAgentStarted
            {
                AgentName = agents[0].Name,
                AgentIndex = 0
            });
        }

        // Execute workflow
        var telemetryJson = JsonSerializer.Serialize(request);
        var workflowResult = await ExecuteWorkflowAsync(agents, telemetryJson, logger);

        // Send final workflow_completed event
        await SendEventAsync(new SseWorkflowCompleted { Result = workflowResult });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "SSE workflow failed for machine {MachineId}", request.machine_id);
        await SendEventAsync(new SseWorkflowError { Error = ex.Message });
    }
    finally
    {
        // Clear the callback to avoid memory leaks
        TextOnlyAgentExecutor.SetEventCallback(null);
    }
});

app.Run();

// ============================================================================
// Workflow Execution
// ============================================================================

static async Task<WorkflowResponse> ExecuteWorkflowAsync(
    List<AIAgent> agents,
    string input,
    ILogger logger)
{
    // Create executors that pass only text between agents
    var executors = agents.Select(a => new TextOnlyAgentExecutor(a)).ToList();
    //var executors = agents;
    // Clear results from any previous run
    TextOnlyAgentExecutor.ClearResults();

    // Build sequential workflow: agent1 → agent2 → agent3 → ...
    var workflowBuilder = new WorkflowBuilder(executors[0]);
    for (int i = 1; i < executors.Count; i++)
    {
        //workflowBuilder.BindExecutor(executors[i]);
        workflowBuilder.AddEdge(executors[i - 1], executors[i]);
    }
    workflowBuilder.WithOpenTelemetry(
                // Set `EnableSensitiveData` to true to include message content in traces
                configure: cfg => cfg.EnableSensitiveData = true);
    workflowBuilder.WithOutputFrom(executors[^1]);

    var workflow = workflowBuilder.Build();
    logger.LogInformation("Workflow built with {Count} agents", executors.Count);

    // Execute the workflow
    var run = await InProcessExecution.RunStreamingAsync<string>(workflow, input);


    // Extract final output from workflow events
    string? finalOutput = null;
    await foreach (var evt in run.WatchStreamAsync())
    {
        if (evt is WorkflowOutputEvent outputEvent && outputEvent.Is<string>(out var text))
        {
            finalOutput = text;
        }
    }

    // Build response from collected step results
    return new WorkflowResponse
    {
        AgentSteps = TextOnlyAgentExecutor.StepResults.ToList(),
        FinalMessage = finalOutput ?? TextOnlyAgentExecutor.StepResults.LastOrDefault()?.FinalMessage
    };
}

// ============================================================================
// Telemetry Configuration
// ============================================================================

static void ConfigureTracing(WebApplicationBuilder builder)
{
    const string SourceName = "FactoryWorkflow";

    var resourceBuilder = ResourceBuilder.CreateDefault()
        .AddService(
            serviceName: builder.Environment.ApplicationName,
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString())
        .AddAttributes([
            new KeyValuePair<string, object>("deployment.environment", builder.Environment.EnvironmentName),
        ]);

    builder.Services.AddOpenTelemetry()
            .WithTracing(tracingBuilder =>
             {
                 tracingBuilder
                    .SetResourceBuilder(resourceBuilder)
                    .AddSource(SourceName, "ChatClient")
                    .AddSource("*Microsoft.Agents.AI*") // Agent Framework telemetry
                    .AddSource("AnomalyClassificationAgent", "FaultDiagnosisAgent", "RepairPlannerAgent")
                    .AddSource("MaintenanceSchedulerAgent", "PartsOrderingAgent")
                    .AddHttpClientInstrumentation()
                    .AddAspNetCoreInstrumentation();

                 if (!string.IsNullOrEmpty(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]))
                 {
                     tracingBuilder.AddOtlpExporter();
                 }

                 var appInsightsConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
                 if (!string.IsNullOrWhiteSpace(appInsightsConnectionString))
                 {
                     tracingBuilder.AddAzureMonitorTraceExporter(options =>
                         options.ConnectionString = appInsightsConnectionString);
                 }
             })
            .WithMetrics(metricsBuilder =>
            {
                metricsBuilder
                    .AddMeter("Microsoft.Agents.AI*") // Agent Framework metrics
                    .AddHttpClientInstrumentation();
            });
}
