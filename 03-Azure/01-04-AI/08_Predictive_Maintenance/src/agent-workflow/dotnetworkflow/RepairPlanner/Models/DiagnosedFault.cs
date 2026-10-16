using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace FactoryWorkflow.RepairPlanner.Models;

/// <summary>
/// Represents the diagnosed fault produced by the Fault Diagnosis Agent (Challenge 1).
/// This is the primary input to the Repair Planner Agent.
/// </summary>
public sealed class DiagnosedFault
{
    /// <summary>
    /// The machine identifier (e.g., "machine-001").
    /// </summary>
    [JsonProperty("machineId")]
    public string MachineId { get; set; } = string.Empty;

    /// <summary>
    /// The fault key/type (snake_case in the sample dataset, e.g., "curing_temperature_excessive").
    /// </summary>
    [JsonProperty("faultType")]
    public string FaultType { get; set; } = string.Empty;

    /// <summary>
    /// Human-readable root cause hypothesis.
    /// </summary>
    [JsonProperty("rootCause")]
    public string? RootCause { get; set; }

    /// <summary>
    /// Severity label (e.g., "critical", "high", "medium", "low").
    /// </summary>
    [JsonProperty("severity")]
    public string? Severity { get; set; }

    /// <summary>
    /// When the fault was detected.
    /// </summary>
    [JsonProperty("detectedAt")]
    public DateTimeOffset DetectedAt { get; set; }

    /// <summary>
    /// Additional context from upstream agents/sensors.
    /// Values typically deserialize as <see cref="System.Text.Json.JsonElement"/>.
    /// </summary>
    [JsonProperty("metadata")]
    public Dictionary<string, object?> Metadata { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
