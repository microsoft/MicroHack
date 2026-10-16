namespace FactoryWorkflow;

/// <summary>
/// Request payload for the /api/analyze_machine endpoint.
/// </summary>
/// <param name="machine_id">The machine identifier to analyze</param>
/// <param name="telemetry">Raw telemetry data from the machine sensors</param>
public record AnalyzeRequest(string machine_id, System.Text.Json.JsonElement telemetry);

/// <summary>
/// Complete workflow response containing results from all agents in the pipeline.
/// </summary>
public class WorkflowResponse
{
    /// <summary>
    /// Results from each agent in execution order.
    /// </summary>
    public List<AgentStepResult> AgentSteps { get; set; } = new();

    /// <summary>
    /// Final output message from the last agent in the workflow.
    /// </summary>
    public string? FinalMessage { get; set; }
}

/// <summary>
/// Execution details for a single agent in the workflow pipeline.
/// </summary>
public class AgentStepResult
{
    /// <summary>
    /// Name of the agent that executed this step.
    /// </summary>
    public string AgentName { get; set; } = string.Empty;

    /// <summary>
    /// Tool/function calls made by this agent during execution.
    /// </summary>
    public List<ToolCallInfo> ToolCalls { get; set; } = new();

    /// <summary>
    /// Accumulated text output from the agent.
    /// </summary>
    public string TextOutput { get; set; } = string.Empty;

    /// <summary>
    /// Indicates that the agent execution itself failed.
    /// </summary>
    public bool IsError { get; set; }

    /// <summary>
    /// Final message from this agent (passed to the next agent in the workflow).
    /// </summary>
    public string? FinalMessage { get; set; }
}

/// <summary>
/// Information about a tool/function call made by an agent.
/// </summary>
public class ToolCallInfo
{
    /// <summary>
    /// Name of the tool that was called.
    /// </summary>
    public string ToolName { get; set; } = string.Empty;

    /// <summary>
    /// Unique identifier for this tool call.
    /// </summary>
    public string? CallId { get; set; }

    /// <summary>
    /// Arguments passed to the tool (serialized).
    /// </summary>
    public string? Arguments { get; set; }

    /// <summary>
    /// Result returned by the tool (truncated for response size).
    /// </summary>
    public string? Result { get; set; }
}

// ============================================================================
// Server-Sent Events (SSE) Types
// ============================================================================
// Prefixed with "Sse" to avoid conflicts with Microsoft.Agents.AI.Workflows types

/// <summary>
/// Base class for all SSE events sent during workflow execution.
/// </summary>
public abstract class SseEvent
{
    public string Type { get; init; } = string.Empty;
    public DateTimeOffset Timestamp { get; init; } = DateTimeOffset.UtcNow;
}

/// <summary>
/// Emitted when the workflow starts executing.
/// </summary>
public class SseWorkflowStarted : SseEvent
{
    public SseWorkflowStarted() => Type = "workflow_started";
    public List<string> AgentPipeline { get; set; } = new();
}

/// <summary>
/// Emitted when an agent begins processing.
/// </summary>
public class SseAgentStarted : SseEvent
{
    public SseAgentStarted() => Type = "agent_started";
    public string AgentName { get; set; } = string.Empty;
    public int AgentIndex { get; set; }
}

/// <summary>
/// Emitted when an agent completes processing.
/// </summary>
public class SseAgentCompleted : SseEvent
{
    public SseAgentCompleted() => Type = "agent_completed";
    public AgentStepResult Step { get; set; } = new();
}

/// <summary>
/// Emitted when the entire workflow completes.
/// </summary>
public class SseWorkflowCompleted : SseEvent
{
    public SseWorkflowCompleted() => Type = "workflow_completed";
    public WorkflowResponse Result { get; set; } = new();
}

/// <summary>
/// Emitted when an error occurs during workflow execution.
/// </summary>
public class SseWorkflowError : SseEvent
{
    public SseWorkflowError() => Type = "workflow_error";
    public string Error { get; set; } = string.Empty;
}
