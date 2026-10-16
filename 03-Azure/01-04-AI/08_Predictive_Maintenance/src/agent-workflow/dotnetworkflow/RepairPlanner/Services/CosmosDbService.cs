using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using FactoryWorkflow.RepairPlanner.Models;

namespace FactoryWorkflow.RepairPlanner.Services;

/// <summary>
/// Cosmos DB data access for the Repair Planner Agent.
/// </summary>
public sealed class CosmosDbService : IDisposable
{
    private readonly CosmosClient _client;
    private readonly bool _ownsClient;
    private readonly ILogger<CosmosDbService> _logger;

    private readonly Container _techniciansContainer;
    private readonly Container _partsContainer;
    private readonly Container _workOrdersContainer;

    /// <summary>
    /// Creates a CosmosDbService using an endpoint/key pair.
    /// </summary>
    public CosmosDbService(
        string endpoint,
        string key,
        string databaseName,
        ILogger<CosmosDbService>? logger = null,
        string techniciansContainerName = "Technicians",
        string partsContainerName = "PartsInventory",
        string workOrdersContainerName = "WorkOrders")
    {
        _client = new CosmosClient(endpoint, key, new CosmosClientOptions
        {
            ApplicationName = "RepairPlannerAgent",
        });
        _ownsClient = true;

        _logger = logger ?? NullLogger<CosmosDbService>.Instance;

        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new ArgumentException("Database name is required.", nameof(databaseName));
        }

        var database = _client.GetDatabase(databaseName);
        _techniciansContainer = database.GetContainer(techniciansContainerName);
        _partsContainer = database.GetContainer(partsContainerName);
        _workOrdersContainer = database.GetContainer(workOrdersContainerName);
    }

    /// <summary>
    /// Creates a CosmosDbService using an existing CosmosClient (recommended for DI).
    /// </summary>
    public CosmosDbService(
        CosmosClient cosmosClient,
        string databaseName,
        ILogger<CosmosDbService>? logger = null,
        string techniciansContainerName = "Technicians",
        string partsContainerName = "PartsInventory",
        string workOrdersContainerName = "WorkOrders")
    {
        _client = cosmosClient ?? throw new ArgumentNullException(nameof(cosmosClient));
        _ownsClient = false;

        _logger = logger ?? NullLogger<CosmosDbService>.Instance;

        if (string.IsNullOrWhiteSpace(databaseName))
        {
            throw new ArgumentException("Database name is required.", nameof(databaseName));
        }

        var database = _client.GetDatabase(databaseName);
        _techniciansContainer = database.GetContainer(techniciansContainerName);
        _partsContainer = database.GetContainer(partsContainerName);
        _workOrdersContainer = database.GetContainer(workOrdersContainerName);
    }

    public void Dispose()
    {
        if (_ownsClient)
        {
            _client.Dispose();
        }
    }

    /// <summary>
    /// Queries technicians who are available and match the given required skills.
    /// </summary>
    public async Task<IReadOnlyList<Technician>> GetAvailableTechniciansWithSkillsAsync(
        IReadOnlyList<string> requiredSkills,
        string? department = null,
        bool requireAllSkills = true,
        CancellationToken cancellationToken = default)
    {
        requiredSkills ??= Array.Empty<string>();

        var normalizedSkills = requiredSkills
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var queryText = "SELECT * FROM c WHERE c.available = true";
        var parameters = new List<(string Name, object Value)>();

        if (!string.IsNullOrWhiteSpace(department))
        {
            queryText += " AND c.department = @department";
            parameters.Add(("@department", department));
        }

        if (normalizedSkills.Length > 0)
        {
            var clauses = new List<string>(capacity: normalizedSkills.Length);
            for (var i = 0; i < normalizedSkills.Length; i++)
            {
                var paramName = $"@skill{i}";
                clauses.Add($"ARRAY_CONTAINS(c.skills, {paramName})");
                parameters.Add((paramName, normalizedSkills[i]));
            }

            var joiner = requireAllSkills ? " AND " : " OR ";
            queryText += $" AND ({string.Join(joiner, clauses)})";
        }

        var queryDefinition = new QueryDefinition(queryText);
        foreach (var (name, value) in parameters)
        {
            queryDefinition = queryDefinition.WithParameter(name, value);
        }

        var results = new List<Technician>();

        try
        {
            var requestOptions = new QueryRequestOptions
            {
                PartitionKey = string.IsNullOrWhiteSpace(department) ? null : new PartitionKey(department),
            };

            using var iterator = _techniciansContainer.GetItemQueryIterator<Technician>(
                queryDefinition,
                requestOptions: requestOptions);

            while (iterator.HasMoreResults)
            {
                var response = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(response);
            }

            return results;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogWarning(ex, "Technicians container or database not found.");
            return Array.Empty<Technician>();
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos query failed in {Method}.", nameof(GetAvailableTechniciansWithSkillsAsync));
            throw;
        }
    }

    /// <summary>
    /// Fetches parts inventory items by part numbers.
    /// </summary>
    public async Task<IReadOnlyList<Part>> GetPartsByPartNumbersAsync(
        IReadOnlyList<string> partNumbers,
        string? category = null,
        CancellationToken cancellationToken = default)
    {
        partNumbers ??= Array.Empty<string>();

        var normalizedPartNumbers = partNumbers
            .Where(p => !string.IsNullOrWhiteSpace(p))
            .Select(p => p.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (normalizedPartNumbers.Length == 0)
        {
            return Array.Empty<Part>();
        }

        var queryDefinition = new QueryDefinition(
                "SELECT * FROM c WHERE ARRAY_CONTAINS(@partNumbers, c.partNumber)")
            .WithParameter("@partNumbers", normalizedPartNumbers);

        if (!string.IsNullOrWhiteSpace(category))
        {
            queryDefinition = new QueryDefinition(
                    "SELECT * FROM c WHERE c.category = @category AND ARRAY_CONTAINS(@partNumbers, c.partNumber)")
                .WithParameter("@category", category)
                .WithParameter("@partNumbers", normalizedPartNumbers);
        }

        var results = new List<Part>();

        try
        {
            var requestOptions = new QueryRequestOptions
            {
                PartitionKey = string.IsNullOrWhiteSpace(category) ? null : new PartitionKey(category),
            };

            using var iterator = _partsContainer.GetItemQueryIterator<Part>(
                queryDefinition,
                requestOptions: requestOptions);

            while (iterator.HasMoreResults)
            {
                var response = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(response);
            }

            return results;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogWarning(ex, "Parts container or database not found.");
            return Array.Empty<Part>();
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos query failed in {Method}.", nameof(GetPartsByPartNumbersAsync));
            throw;
        }
    }

    /// <summary>
    /// Creates a new work order document in Cosmos DB.
    /// </summary>
    public async Task<string> CreateWorkOrderAsync(WorkOrder workOrder, CancellationToken cancellationToken = default)
    {
        if (workOrder is null)
        {
            throw new ArgumentNullException(nameof(workOrder));
        }

        if (string.IsNullOrWhiteSpace(workOrder.Id))
        {
            workOrder.Id = $"wo-{Guid.NewGuid():N}";
        }

        workOrder.CreatedDate ??= DateTimeOffset.UtcNow;
        workOrder.Status = string.IsNullOrWhiteSpace(workOrder.Status) ? "new" : workOrder.Status;

        if (string.IsNullOrWhiteSpace(workOrder.WorkOrderNumber))
        {
            workOrder.WorkOrderNumber = $"WO-{DateTimeOffset.UtcNow:yyyyMMdd-HHmmss}";
        }

        try
        {
            var response = await _workOrdersContainer.CreateItemAsync(
                workOrder,
                new PartitionKey(workOrder.Status),
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "Created work order {WorkOrderNumber} (id={Id}, status={Status}).",
                workOrder.WorkOrderNumber,
                response.Resource.Id,
                response.Resource.Status);

            return response.Resource.Id;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            _logger.LogWarning(ex, "Work order id conflict for id={Id}.", workOrder.Id);
            throw;
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos create failed in {Method}.", nameof(CreateWorkOrderAsync));
            throw;
        }
    }
}
