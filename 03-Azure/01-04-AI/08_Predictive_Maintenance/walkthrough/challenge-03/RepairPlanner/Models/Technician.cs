using System.Collections.Generic;
using System.Text.Json.Serialization;
using Newtonsoft.Json;

namespace RepairPlanner.Models;

/// <summary>
/// Represents a maintenance technician record stored in Cosmos DB.
/// </summary>
public sealed class Technician
{
    [JsonPropertyName("id")]
    [JsonProperty("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("employeeId")]
    [JsonProperty("employeeId")]
    public string EmployeeId { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    [JsonProperty("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("role")]
    [JsonProperty("role")]
    public string? Role { get; set; }

    /// <summary>
    /// Cosmos partition key in sample dataset.
    /// </summary>
    [JsonPropertyName("department")]
    [JsonProperty("department")]
    public string Department { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    [JsonProperty("email")]
    public string? Email { get; set; }

    [JsonPropertyName("phone")]
    [JsonProperty("phone")]
    public string? Phone { get; set; }

    [JsonPropertyName("skills")]
    [JsonProperty("skills")]
    public List<string> Skills { get; set; } = new();

    [JsonPropertyName("certifications")]
    [JsonProperty("certifications")]
    public List<string> Certifications { get; set; } = new();

    [JsonPropertyName("available")]
    [JsonProperty("available")]
    public bool Available { get; set; }

    [JsonPropertyName("currentAssignments")]
    [JsonProperty("currentAssignments")]
    public List<string> CurrentAssignments { get; set; } = new();

    [JsonPropertyName("shiftSchedule")]
    [JsonProperty("shiftSchedule")]
    public string? ShiftSchedule { get; set; }
}
