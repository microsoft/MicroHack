using System.Collections.Generic;
using Newtonsoft.Json;

namespace FactoryWorkflow.RepairPlanner.Models;

/// <summary>
/// Represents a maintenance technician stored in Cosmos DB (container: Technicians).
/// </summary>
public sealed class Technician
{
    /// <summary>
    /// Cosmos document id (e.g., "tech-001").
    /// </summary>
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    [JsonProperty("employeeId")]
    public string? EmployeeId { get; set; }

    [JsonProperty("name")]
    public string Name { get; set; } = string.Empty;

    [JsonProperty("role")]
    public string? Role { get; set; }

    [JsonProperty("department")]
    public string? Department { get; set; }

    [JsonProperty("email")]
    public string? Email { get; set; }

    [JsonProperty("phone")]
    public string? Phone { get; set; }

    /// <summary>
    /// Skill tags (snake_case) used for matching to fault requirements.
    /// </summary>
    [JsonProperty("skills")]
    public List<string> Skills { get; set; } = new();

    [JsonProperty("certifications")]
    public List<string> Certifications { get; set; } = new();

    [JsonProperty("available")]
    public bool Available { get; set; }

    [JsonProperty("shiftSchedule")]
    public string? ShiftSchedule { get; set; }

    /// <summary>
    /// Work order numbers currently assigned (if any).
    /// </summary>
    [JsonProperty("assignedWorkOrders")]
    public List<string> AssignedWorkOrders { get; set; } = new();
}
