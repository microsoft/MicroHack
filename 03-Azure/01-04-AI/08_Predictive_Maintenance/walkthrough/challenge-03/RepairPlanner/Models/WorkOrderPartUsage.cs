using System.Text.Json.Serialization;
using Newtonsoft.Json;

namespace RepairPlanner.Models;

/// <summary>
/// Represents a part usage/reservation line item for a work order.
/// </summary>
public sealed class WorkOrderPartUsage
{
    [JsonPropertyName("partId")]
    [JsonProperty("partId")]
    public string? PartId { get; set; }

    [JsonPropertyName("partNumber")]
    [JsonProperty("partNumber")]
    public string? PartNumber { get; set; }

    [JsonPropertyName("quantity")]
    [JsonProperty("quantity")]
    public int Quantity { get; set; }
}
