using System.Collections.Generic;
using Newtonsoft.Json;

namespace FactoryWorkflow.RepairPlanner.Models;

/// <summary>
/// A single step in a repair plan / work order.
/// </summary>
public sealed class RepairTask
{
    [JsonProperty("description")]
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Estimated task duration in minutes.
    /// </summary>
    [JsonProperty("estimatedMinutes")]
    public int EstimatedMinutes { get; set; }

    [JsonProperty("requiredTools")]
    public List<string> RequiredTools { get; set; } = new();
}
