using System.Data.Common;
using System.Diagnostics;
using LegoCatalog.App.Configuration;
using LegoCatalog.App.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;

namespace LegoCatalog.App.Services;

public interface IPerformanceCatalogService
{
    Task<PerformanceResult> ExecuteAsync(CancellationToken cancellationToken);
}

/// <summary>
/// Executes bounded SQL Server work and returns the stable performance DTO.
/// </summary>
public sealed class PerformanceCatalogService : IPerformanceCatalogService
{
    private const string BoundedWorkSql = """
        DECLARE @work bigint;
        SELECT @work = SUM(ABS(CONVERT(bigint, CHECKSUM(f.[Id], f.[Name], work.[n]))))
        FROM [dbo].[Figures] AS f
        CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7), (8),
                           (9), (10), (11), (12), (13), (14), (15), (16)) AS work([n]);
        """;

    private readonly CatalogDbContext _database;
    private readonly FigureCatalogService _catalog;
    private readonly CatalogRuntimeOptions _options;
    private readonly CatalogTelemetry _telemetry;
    private readonly ILogger<PerformanceCatalogService> _logger;

    public PerformanceCatalogService(
        CatalogDbContext database,
        FigureCatalogService catalog,
        CatalogRuntimeOptions options,
        CatalogTelemetry telemetry,
        ILogger<PerformanceCatalogService> logger)
    {
        _database = database;
        _catalog = catalog;
        _options = options;
        _telemetry = telemetry;
        _logger = logger;
    }

    public async Task<PerformanceResult> ExecuteAsync(
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        using var activity = _telemetry.StartActivity("catalog.performance");
        activity?.SetTag(
            "catalog.performance.work_factor",
            _options.PerformanceWorkFactor);
        try
        {
            for (var iteration = 0;
                 iteration < _options.PerformanceWorkFactor;
                 iteration++)
            {
                await _database.Database.ExecuteSqlRawAsync(
                    BoundedWorkSql,
                    cancellationToken);
            }

            var figures = await _catalog.ListAsync(
                category: null,
                search: null,
                cancellationToken);
            var items = figures.Select(FigureCatalogService.ToDto).ToList();
            stopwatch.Stop();
            _telemetry.RecordDatabase(
                stopwatch.Elapsed.TotalSeconds,
                "execute");
            activity?.SetTag("catalog.performance.item_count", items.Count);
            _telemetry.RecordPerformance(
                stopwatch.Elapsed.TotalSeconds,
                _options.PerformanceWorkFactor);
            using (_logger.BeginScope(
                new Dictionary<string, object>
                {
                    ["catalog.performance.work_factor"] =
                        _options.PerformanceWorkFactor,
                    ["catalog.performance.item_count"] = items.Count,
                }))
            {
                _logger.LogInformation(
                    "catalog.performance.completed workFactor={WorkFactor} itemCount={ItemCount}",
                    _options.PerformanceWorkFactor,
                    items.Count);
            }

            return new PerformanceResult(
                _options.PerformanceWorkFactor,
                items.Count,
                stopwatch.Elapsed.TotalMilliseconds,
                items);
        }
        catch (SqlException exception) when (exception.Number == -2)
        {
            CatalogTelemetry.RecordException(activity, exception);
            throw LogAndWrapTimeout(exception);
        }
        catch (OperationCanceledException exception)
        {
            CatalogTelemetry.RecordException(activity, exception);
            throw LogAndWrapTimeout(exception);
        }
        catch (DbException exception)
        {
            activity?.SetStatus(ActivityStatusCode.Error, exception.Message);
            CatalogTelemetry.RecordException(activity, exception);
            LogFailure(exception);
            throw new CatalogDependencyUnavailableException(exception);
        }
    }

    private CatalogQueryTimeoutException LogAndWrapTimeout(Exception exception)
    {
        LogFailure(exception);
        return new CatalogQueryTimeoutException(exception);
    }

    private void LogFailure(Exception exception)
    {
        CatalogTelemetry.LogException(_logger, exception);
        CatalogTelemetry.LogDatabaseFailure(_logger, "execute", exception);
        using (_logger.BeginScope(
            new Dictionary<string, object>
            {
                ["catalog.performance.work_factor"] =
                    _options.PerformanceWorkFactor,
                ["exception.type"] =
                    exception.GetType().FullName ?? exception.GetType().Name,
            }))
        {
            _logger.LogError(
                exception,
                "catalog.performance.failed workFactor={WorkFactor}",
                _options.PerformanceWorkFactor);
        }
    }
}

public sealed record PerformanceResult(
    int Iterations,
    int ItemCount,
    double ElapsedMilliseconds,
    IReadOnlyList<CatalogFigureDto> Items);

public sealed class CatalogDependencyUnavailableException : Exception
{
    public CatalogDependencyUnavailableException(Exception? innerException = null)
        : base("The catalog dependency is unavailable.", innerException)
    {
    }
}

public sealed class CatalogQueryTimeoutException : Exception
{
    public CatalogQueryTimeoutException(Exception? innerException = null)
        : base("The catalog query timed out.", innerException)
    {
    }
}
