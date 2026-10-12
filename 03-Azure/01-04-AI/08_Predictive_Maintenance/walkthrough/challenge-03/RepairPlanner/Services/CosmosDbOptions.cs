namespace RepairPlanner.Services;

/// <summary>
/// Configuration for Cosmos DB access.
/// </summary>
public sealed class CosmosDbOptions
{
    public required string Endpoint { get; set; }
    public required string Key { get; set; }
    public required string DatabaseName { get; set; }

    public string TechniciansContainerName { get; set; } = "Technicians";
    public string PartsInventoryContainerName { get; set; } = "PartsInventory";
    public string WorkOrdersContainerName { get; set; } = "WorkOrders";
}
