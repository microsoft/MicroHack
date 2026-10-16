using System.Collections.Generic;
using System.Text.Json.Serialization;
using Newtonsoft.Json;

namespace RepairPlanner.Models;

/// <summary>
/// Represents a parts inventory item stored in Cosmos DB.
/// </summary>
public sealed class Part
{
    [JsonPropertyName("id")]
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partNumber")]
    [JsonProperty("partNumber")]
    public string PartNumber { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    [JsonProperty("name")]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Cosmos partition key in sample dataset.
    /// </summary>
    [JsonPropertyName("category")]
    [JsonProperty("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("compatibleMachines")]
    [JsonProperty("compatibleMachines")]
    public List<string> CompatibleMachines { get; set; } = new();

    [JsonPropertyName("manufacturer")]
    [JsonProperty("manufacturer")]
    public string? Manufacturer { get; set; }

    [JsonPropertyName("quantityInStock")]
    [JsonProperty("quantityInStock")]
    public int QuantityInStock { get; set; }

    [JsonPropertyName("unit")]
    [JsonProperty("unit")]
    public string? Unit { get; set; }

    [JsonPropertyName("reorderLevel")]
    [JsonProperty("reorderLevel")]
    public int ReorderLevel { get; set; }

    [JsonPropertyName("unitCost")]
    [JsonProperty("unitCost")]
    public decimal UnitCost { get; set; }

    [JsonPropertyName("leadTimeDays")]
    [JsonProperty("leadTimeDays")]
    public int LeadTimeDays { get; set; }

    [JsonPropertyName("location")]
    [JsonProperty("location")]
    public string? Location { get; set; }
}
