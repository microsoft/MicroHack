using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using RepairPlanner.Models;

namespace RepairPlanner.Services;

/// <summary>
/// Encapsulates Cosmos DB queries and writes needed by the Repair Planner Agent.
/// </summary>
public sealed class CosmosDbService
{
    private readonly ILogger<CosmosDbService> _logger;
    private readonly Container _technicians;
    private readonly Container _partsInventory;
    private readonly Container _workOrders;

    public CosmosDbService(
        CosmosClient cosmosClient,
        string databaseName,
        ILogger<CosmosDbService> logger,
        string techniciansContainerName = "Technicians",
        string partsInventoryContainerName = "PartsInventory",
        string workOrdersContainerName = "WorkOrders")
    {
        if (cosmosClient is null) throw new ArgumentNullException(nameof(cosmosClient));
        if (string.IsNullOrWhiteSpace(databaseName)) throw new ArgumentException("Database name is required.", nameof(databaseName));

        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        _technicians = cosmosClient.GetContainer(databaseName, techniciansContainerName);
        _partsInventory = cosmosClient.GetContainer(databaseName, partsInventoryContainerName);
        _workOrders = cosmosClient.GetContainer(databaseName, workOrdersContainerName);
    }

    /// <summary>
    /// Queries available technicians and ranks them by overlap with required skills.
    /// Returns only technicians matching at least one required skill.
    /// </summary>
    public async Task<IReadOnlyList<Technician>> QueryAvailableTechniciansBySkillsAsync(
        IEnumerable<string> requiredSkills,
        string? department = null,
        CancellationToken cancellationToken = default)
    {
        requiredSkills ??= Array.Empty<string>();

        var skills = requiredSkills
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        QueryDefinition query = string.IsNullOrWhiteSpace(department)
            ? new QueryDefinition("SELECT * FROM c WHERE c.available = true")
            : new QueryDefinition("SELECT * FROM c WHERE c.available = true AND c.department = @department")
                .WithParameter("@department", department);

        var results = new List<Technician>();

        try
        {
            QueryRequestOptions? requestOptions = null;
            if (!string.IsNullOrWhiteSpace(department))
            {
                requestOptions = new QueryRequestOptions { PartitionKey = new PartitionKey(department) };
            }

            using FeedIterator<Technician> iterator = _technicians.GetItemQueryIterator<Technician>(
                query,
                requestOptions: requestOptions);

            while (iterator.HasMoreResults)
            {
                FeedResponse<Technician> page = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(page);
            }

            if (skills.Length == 0)
            {
                _logger.LogInformation(
                    "Found {TechnicianCount} available technicians (department={Department})",
                    results.Count,
                    department ?? "<any>");
                return results;
            }

            var ranked = results
                .Select(t => new
                {
                    Technician = t,
                    MatchCount = t.Skills.Count(s => skills.Contains(s, StringComparer.OrdinalIgnoreCase)),
                })
                .Where(x => x.MatchCount > 0)
                .OrderByDescending(x => x.MatchCount)
                .ThenBy(x => x.Technician.Name, StringComparer.OrdinalIgnoreCase)
                .Select(x => x.Technician)
                .ToList();

            _logger.LogInformation(
                "Found {TechnicianCount} available technicians matching at least one required skill [{Skills}] (department={Department})",
                ranked.Count,
                string.Join(", ", skills),
                department ?? "<any>");

            return ranked;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogWarning(ex, "Technicians container not found or database missing.");
            return Array.Empty<Technician>();
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos DB error querying technicians.");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error querying technicians.");
            throw;
        }
    }

    /// <summary>
    /// Fetches parts inventory items by part numbers.
    /// </summary>
    public async Task<IReadOnlyList<Part>> GetPartsByPartNumbersAsync(
        IEnumerable<string> partNumbers,
        string? category = null,
        CancellationToken cancellationToken = default)
    {
        if (partNumbers is null) throw new ArgumentNullException(nameof(partNumbers));

        var numbers = partNumbers
            .Where(pn => !string.IsNullOrWhiteSpace(pn))
            .Select(pn => pn.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (numbers.Length == 0)
        {
            return Array.Empty<Part>();
        }

        var queryText = "SELECT * FROM c WHERE ARRAY_CONTAINS(@partNumbers, c.partNumber)";
        if (!string.IsNullOrWhiteSpace(category))
        {
            queryText += " AND c.category = @category";
        }

        var query = new QueryDefinition(queryText)
            .WithParameter("@partNumbers", numbers);

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.WithParameter("@category", category);
        }

        var results = new List<Part>();

        try
        {
            QueryRequestOptions? requestOptions = null;
            if (!string.IsNullOrWhiteSpace(category))
            {
                requestOptions = new QueryRequestOptions { PartitionKey = new PartitionKey(category) };
            }

            using FeedIterator<Part> iterator = _partsInventory.GetItemQueryIterator<Part>(
                query,
                requestOptions: requestOptions);

            while (iterator.HasMoreResults)
            {
                FeedResponse<Part> page = await iterator.ReadNextAsync(cancellationToken);
                results.AddRange(page);
            }

            _logger.LogInformation(
                "Fetched {PartCount} parts for partNumbers [{PartNumbers}] (category={Category})",
                results.Count,
                string.Join(", ", numbers),
                category ?? "<any>");

            return results;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogWarning(ex, "Parts inventory container not found or database missing.");
            return Array.Empty<Part>();
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos DB error fetching parts inventory.");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error fetching parts inventory.");
            throw;
        }
    }

    /// <summary>
    /// Creates a new work order in Cosmos DB.
    /// </summary>
    public async Task<WorkOrder> CreateWorkOrderAsync(WorkOrder workOrder, CancellationToken cancellationToken = default)
    {
        if (workOrder is null) throw new ArgumentNullException(nameof(workOrder));

        if (string.IsNullOrWhiteSpace(workOrder.Id))
        {
            workOrder.Id = $"wo-{Guid.NewGuid():N}";
        }

        if (string.IsNullOrWhiteSpace(workOrder.WorkOrderNumber))
        {
            workOrder.WorkOrderNumber = $"WO-{DateTimeOffset.UtcNow:yyyyMMdd}-{Random.Shared.Next(1, 999):D3}";
        }

        if (string.IsNullOrWhiteSpace(workOrder.Status))
        {
            workOrder.Status = "new";
        }

        try
        {
            ItemResponse<WorkOrder> response = await _workOrders.CreateItemAsync(
                workOrder,
                partitionKey: new PartitionKey(workOrder.Status),
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "Created work order {WorkOrderNumber} (id={Id}, status={Status}, requestCharge={RequestCharge})",
                response.Resource.WorkOrderNumber,
                response.Resource.Id,
                response.Resource.Status,
                response.RequestCharge);

            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            _logger.LogWarning(ex, "Work order id conflict for id={Id}", workOrder.Id);
            throw;
        }
        catch (CosmosException ex)
        {
            _logger.LogError(ex, "Cosmos DB error creating work order.");
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error creating work order.");
            throw;
        }
    }
}
