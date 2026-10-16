using System.Collections.Generic;
using Newtonsoft.Json;

namespace FactoryWorkflow.RepairPlanner.Models;

/// <summary>
/// Represents a part inventory item stored in Cosmos DB (container: PartsInventory).
/// </summary>
public sealed class Part
{
    /// <summary>
    /// Cosmos document id (e.g., "part-curing-bladder").
    /// </summary>
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    [JsonProperty("partNumber")]
    public string PartNumber { get; set; } = string.Empty;

    [JsonProperty("name")]
    public string Name { get; set; } = string.Empty;

    [JsonProperty("category")]
    public string? Category { get; set; }

    [JsonProperty("compatibleMachines")]
    public List<string> CompatibleMachines { get; set; } = new();

    [JsonProperty("manufacturer")]
    public string? Manufacturer { get; set; }

    [JsonProperty("quantityInStock")]
    public int QuantityInStock { get; set; }

    [JsonProperty("unit")]
    public string? Unit { get; set; }

    [JsonProperty("reorderLevel")]
    public int? ReorderLevel { get; set; }

    [JsonProperty("unitCost")]
    public decimal? UnitCost { get; set; }

    [JsonProperty("leadTimeDays")]
    public int? LeadTimeDays { get; set; }

    [JsonProperty("location")]
    public string? Location { get; set; }
}
