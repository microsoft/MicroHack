using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using Newtonsoft.Json;

namespace RepairPlanner.Models;

/// <summary>
/// Represents the diagnosed fault produced by the Fault Diagnosis Agent.
/// </summary>
public sealed class DiagnosedFault
{
    [JsonPropertyName("machineId")]
    [JsonProperty("machineId")]
    public string MachineId { get; set; } = string.Empty;

    /// <summary>
    /// Fault key/type in snake_case (e.g., "curing_temperature_excessive").
    /// </summary>
    [JsonPropertyName("faultType")]
    [JsonProperty("faultType")]
    public string FaultType { get; set; } = string.Empty;

    [JsonPropertyName("rootCause")]
    [JsonProperty("rootCause")]
    public string? RootCause { get; set; }

    [JsonPropertyName("severity")]
    [JsonProperty("severity")]
    public string? Severity { get; set; }

    [JsonPropertyName("detectedAt")]
    [JsonProperty("detectedAt")]
    public DateTimeOffset DetectedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("metadata")]
    [JsonProperty("metadata")]
    public Dictionary<string, object?> Metadata { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
