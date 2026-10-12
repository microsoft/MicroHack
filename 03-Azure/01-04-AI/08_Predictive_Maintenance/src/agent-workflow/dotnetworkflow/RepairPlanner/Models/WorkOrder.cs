using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace FactoryWorkflow.RepairPlanner.Models;

/// <summary>
/// A work order produced by the Repair Planner Agent and stored in Cosmos DB (container: WorkOrders).
/// </summary>
public sealed class WorkOrder
{
    /// <summary>
    /// Cosmos document id (e.g., "wo-2024-445").
    /// </summary>
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Human-friendly work order number (e.g., "WO-2026-001").
    /// </summary>
    [JsonProperty("workOrderNumber")]
    public string? WorkOrderNumber { get; set; }

    [JsonProperty("machineId")]
    public string MachineId { get; set; } = string.Empty;

    [JsonProperty("faultType")]
    public string? FaultType { get; set; }

    [JsonProperty("title")]
    public string? Title { get; set; }

    [JsonProperty("description")]
    public string? Description { get; set; }

    /// <summary>
    /// Work order type (e.g., "preventive", "corrective", "emergency").
    /// </summary>
    [JsonProperty("type")]
    public string? Type { get; set; }

    /// <summary>
    /// Priority label (e.g., "critical", "high", "medium", "low").
    /// </summary>
    [JsonProperty("priority")]
    public string? Priority { get; set; }

    /// <summary>
    /// Status label (e.g., "scheduled", "in_progress", "completed").
    /// </summary>
    [JsonProperty("status")]
    public string? Status { get; set; }

    /// <summary>
    /// Technician id assigned to the work order (e.g., "tech-001").
    /// </summary>
    [JsonProperty("assignedTo")]
    public string? AssignedTo { get; set; }

    /// <summary>
    /// Optional: embed the selected technician details.
    /// </summary>
    [JsonProperty("assignedTechnician")]
    public Technician? AssignedTechnician { get; set; }

    [JsonProperty("createdDate")]
    public DateTimeOffset? CreatedDate { get; set; }

    [JsonProperty("scheduledDate")]
    public DateTimeOffset? ScheduledDate { get; set; }

    [JsonProperty("completedDate")]
    public DateTimeOffset? CompletedDate { get; set; }

    /// <summary>
    /// Estimated total duration in minutes.
    /// </summary>
    [JsonProperty("estimatedDuration")]
    public int? EstimatedDurationMinutes { get; set; }

    /// <summary>
    /// Actual duration in minutes (when completed).
    /// </summary>
    [JsonProperty("actualDuration")]
    public int? ActualDurationMinutes { get; set; }

    /// <summary>
    /// Optional: an AI-generated breakdown of tasks.
    /// </summary>
    [JsonProperty("tasks")]
    public List<RepairTask> Tasks { get; set; } = new();

    /// <summary>
    /// Optional: the parts required to execute the plan (by part number).
    /// </summary>
    [JsonProperty("requiredParts")]
    public List<PartRequirement> RequiredParts { get; set; } = new();

    /// <summary>
    /// Parts actually consumed by the work order.
    /// </summary>
    [JsonProperty("partsUsed")]
    public List<WorkOrderPartUsage> PartsUsed { get; set; } = new();

    [JsonProperty("notes")]
    public string? Notes { get; set; }

    [JsonProperty("cost")]
    public decimal? Cost { get; set; }

    /// <summary>
    /// Downtime impact in minutes.
    /// </summary>
    [JsonProperty("downtime")]
    public int? DowntimeMinutes { get; set; }
}

/// <summary>
/// A part requirement expressed as a part number and quantity.
/// </summary>
public sealed class PartRequirement
{
    [JsonProperty("partNumber")]
    public string PartNumber { get; set; } = string.Empty;

    [JsonProperty("quantity")]
    public int Quantity { get; set; }
}

/// <summary>
/// Represents a part usage entry in an existing work order.
/// </summary>
public sealed class WorkOrderPartUsage
{
    [JsonProperty("partId")]
    public string PartId { get; set; } = string.Empty;

    [JsonProperty("quantity")]
    public int Quantity { get; set; }
}
