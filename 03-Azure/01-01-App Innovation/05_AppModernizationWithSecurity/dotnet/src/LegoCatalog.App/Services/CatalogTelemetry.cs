using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace LegoCatalog.App.Services;

/// <summary>
/// Owns the catalog's custom OpenTelemetry activities and instruments.
/// </summary>
public sealed class CatalogTelemetry : IDisposable
{
    public const string InstrumentationName = "LegoCatalog.App";
    public const string ServiceName = "mh-catalog-dotnet";
    public const string ServiceNamespace = "app-innovation";
    public const string DeploymentEnvironmentAttribute = "deployment.environment";
    public const string RevisionAttribute = "azure.containerapps.revision.name";

    private readonly ActivitySource _activities = new(InstrumentationName);
    private readonly Meter _meter = new(InstrumentationName);
    private readonly Counter<long> _importRecords;
    private readonly Histogram<double> _databaseDuration;
    private readonly Histogram<double> _queryDuration;
    private readonly Histogram<double> _performanceDuration;

    public CatalogTelemetry()
    {
        _importRecords = _meter.CreateCounter<long>(
            "catalog.import.records",
            unit: "{record}");
        _databaseDuration = _meter.CreateHistogram<double>(
            "db.client.operation.duration",
            unit: "s");
        _queryDuration = _meter.CreateHistogram<double>(
            "catalog.query.duration",
            unit: "s");
        _performanceDuration = _meter.CreateHistogram<double>(
            "catalog.performance.duration",
            unit: "s");
    }

    public Activity? StartActivity(string name) =>
        _activities.StartActivity(name, ActivityKind.Internal);

    public void RecordImport(int inserted, int skipped)
    {
        _importRecords.Add(
            inserted,
            new KeyValuePair<string, object?>("catalog.import.outcome", "inserted"));
        _importRecords.Add(
            skipped,
            new KeyValuePair<string, object?>("catalog.import.outcome", "skipped"));
    }

    public void RecordRejectedImport() =>
        _importRecords.Add(
            1,
            new KeyValuePair<string, object?>("catalog.import.outcome", "rejected"));

    public void RecordQuery(double elapsedSeconds, string filter) =>
        _queryDuration.Record(
            elapsedSeconds,
            new KeyValuePair<string, object?>("catalog.query.filter", filter));

    public void RecordDatabase(double elapsedSeconds, string operation) =>
        _databaseDuration.Record(
            elapsedSeconds,
            new KeyValuePair<string, object?>(
                "db.system.name",
                "microsoft.sql_server"),
            new KeyValuePair<string, object?>("db.operation.name", operation));

    public void RecordPerformance(double elapsedSeconds, int workFactor) =>
        _performanceDuration.Record(
            elapsedSeconds,
            new KeyValuePair<string, object?>(
                "catalog.performance.work_factor",
                workFactor));

    public static void RecordException(Activity? activity, Exception exception)
    {
        activity?.AddEvent(
            new ActivityEvent(
                "exception",
                tags: new ActivityTagsCollection
                {
                    ["exception.type"] =
                        exception.GetType().FullName ?? exception.GetType().Name,
                    ["exception.message"] = exception.Message,
                }));
    }

    public static void LogException(ILogger logger, Exception exception)
    {
        using (logger.BeginScope(
            new Dictionary<string, object>
            {
                ["exception.type"] =
                    exception.GetType().FullName ?? exception.GetType().Name,
                ["exception.message"] = exception.Message,
            }))
        {
            logger.LogError(exception, "exception");
        }
    }

    public static void LogDatabaseFailure(
        ILogger logger,
        string operation,
        Exception? exception = null)
    {
        using (logger.BeginScope(
            new Dictionary<string, object>
            {
                ["db.system.name"] = "microsoft.sql_server",
                ["db.operation.name"] = operation,
                ["exception.type"] = exception?.GetType().FullName
                    ?? typeof(CatalogDependencyUnavailableException).FullName!,
            }))
        {
            if (exception is null)
            {
                logger.LogError("catalog.database.failed");
            }
            else
            {
                logger.LogError(exception, "catalog.database.failed");
            }
        }
    }

    public void Dispose()
    {
        _activities.Dispose();
        _meter.Dispose();
    }
}
