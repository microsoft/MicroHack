using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;
using Microsoft.Extensions.AI;
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;

namespace FactoryWorkflow;

/// <summary>
/// Custom agent executor that only passes TEXT output between agents in a sequential workflow.
/// This works around the Azure.AI.Projects SDK bug where MCP tool call history in
/// conversation messages causes deserialization errors when passed to subsequent agents.
/// 
/// The executor is Executor{string, string} so outputs can directly chain to next agent's input.
/// Agent step details (tool calls, etc.) are collected via the static StepResults property.
/// </summary>
public sealed class TextOnlyAgentExecutor : Executor<string, string>
{
    private readonly AIAgent _agent;

    // Static collector for step results - ConcurrentQueue preserves FIFO order
    private static readonly ConcurrentQueue<AgentStepResult> _stepResults = new();

    // Callback for streaming events - set via SetEventCallback before workflow execution
    private static Func<AgentStepResult, Task>? _onStepCompleted;

    public static IEnumerable<AgentStepResult> StepResults => _stepResults.ToArray();

    public static void ClearResults()
    {
        while (_stepResults.TryDequeue(out _)) { }
    }

    /// <summary>
    /// Sets a callback that fires when each agent step completes (for SSE streaming).
    /// </summary>
    public static void SetEventCallback(Func<AgentStepResult, Task>? callback)
    {
        _onStepCompleted = callback;
    }

    public TextOnlyAgentExecutor(AIAgent agent) : base($"{agent.Name}")
    {
        _agent = agent ?? throw new ArgumentNullException(nameof(agent));
    }

    public string AgentName => _agent.Name;

    public override async ValueTask<string> HandleAsync(string input, IWorkflowContext context, CancellationToken cancellationToken = default)
    {
        var agentStep = new AgentStepResult { AgentName = _agent.Name };

        try
        {
            // Create a clean message with only text input (no MCP tool history)
            var messages = new List<ChatMessage> { new ChatMessage(ChatRole.User, input) };

            // Run the agent
            var response = await _agent.RunAsync(messages, null);

            // Extract text output and tool calls from response
            string? outputText = null;
            if (response.Messages != null)
            {
                foreach (var msg in response.Messages)
                {
                    if (msg.Role == ChatRole.Assistant)
                    {
                        foreach (var content in msg.Contents)
                        {
#pragma warning disable MEAI001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.
                            if (content is TextContent tc && !string.IsNullOrWhiteSpace(tc.Text))
                            {
                                outputText = tc.Text;
                                agentStep.TextOutput += tc.Text;
                            }
                            else if (content is McpServerToolCallContent mcp)
                            {
                                agentStep.ToolCalls.Add(new ToolCallInfo
                                {
                                    ToolName = mcp.Name,
                                    CallId = mcp.CallId,
                                    Arguments = SerializeArguments(mcp.Arguments)
                                });
                            }
                            else if (content is McpServerToolResultContent mcpr)
                            {
                                Console.WriteLine("Received MCPServerToolResultContent ");

                                var matchingCall = agentStep.ToolCalls.LastOrDefault(t => t.CallId == mcpr.CallId);
                                if (matchingCall != null)
                                {
                                    // Extract readable content from the Output (which is List<AIContent>)
                                    matchingCall.Result = ExtractOutputText(mcpr.Outputs);
                                }
                            }
                            else if (content is FunctionCallContent fcc)
                            {
                                agentStep.ToolCalls.Add(new ToolCallInfo
                                {
                                    ToolName = fcc.Name,
                                    CallId = fcc.CallId,
                                    Arguments = SerializeArguments(fcc.Arguments)
                                });
                            }
#pragma warning restore MEAI001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.
                        }
                    }
                    else if (msg.Role == ChatRole.Tool)
                    {
                        foreach (var content in msg.Contents)
                        {
#pragma warning disable MEAI001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.
                            if (content is FunctionResultContent frc)
                            {
                                var matchingCall = agentStep.ToolCalls.LastOrDefault(t => t.CallId == frc.CallId);
                                if (matchingCall != null)
                                {
                                    matchingCall.Result = frc.Result?.ToString()?.Substring(0, Math.Min(500, frc.Result?.ToString()?.Length ?? 0));
                                }
                            }

#pragma warning restore MEAI001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.
                        }
                    }
                }
            }

            agentStep.FinalMessage = outputText ?? "";
            Console.WriteLine($"Agent {_agent.Name} completed with {agentStep.ToolCalls.Count} tool calls.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Agent {_agent.Name} failed: {ex.Message}");
            agentStep.IsError = true;
            agentStep.FinalMessage = $"Error: {ex.Message}";
            agentStep.TextOutput = $"Error: {ex.Message}";
        }

        // Store step result for later collection (ConcurrentQueue preserves order)
        _stepResults.Enqueue(agentStep);

        // Notify SSE callback if registered (for streaming progress to frontend)
        if (_onStepCompleted != null)
        {
            await _onStepCompleted(agentStep);
        }

        // Return just the text for the next agent
        return agentStep.FinalMessage ?? "";
    }

    /// <summary>
    /// Serializes tool arguments to JSON string. Handles Dictionary and other types.
    /// </summary>
    private static string? SerializeArguments(object? arguments)
    {
        if (arguments == null) return null;

        // If it's already a string (pre-serialized JSON), return as-is
        if (arguments is string s) return s;

        // Serialize dictionaries and other objects to JSON
        try
        {
            return JsonSerializer.Serialize(arguments);
        }
        catch
        {
            return arguments.ToString();
        }
    }

    /// <summary>
    /// Extracts readable text from MCP tool output
    /// </summary>
    private static string? ExtractOutputText(object? output)
    {
        if (output == null) return null;

        StringBuilder result = new();

        // Handle IEnumerable<AIContent> (the actual type of mcpr.Output)
        if (output is IEnumerable<AIContent> contentList)
        {
            var textParts = new List<string>();
            foreach (var item in contentList)
            {
                if (item is TextContent textContent && !string.IsNullOrWhiteSpace(textContent.Text))
                {
                    textParts.Add(textContent.Text);
                }
                else
                {
                    // For other content types, try to serialize to JSON
                    try
                    {
                        var json = JsonSerializer.Serialize(item, new JsonSerializerOptions { WriteIndented = false });
                        textParts.Add(json);
                    }
                    catch
                    {
                        textParts.Add(item?.ToString() ?? "");
                    }
                }
            }
           result.Append(string.Join("\n", textParts));
        }
        return result.ToString();
    }
}
