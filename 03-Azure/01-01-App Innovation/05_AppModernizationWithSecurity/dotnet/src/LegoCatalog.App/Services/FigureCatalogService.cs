using System.Diagnostics;
using LegoCatalog.App.Models;

namespace LegoCatalog.App.Services;

/// <summary>
/// Provides measured catalog queries and stable external DTOs.
/// </summary>
public sealed class FigureCatalogService
{
    private readonly IFigureRepository _figures;
    private readonly ICategoryRepository _categories;
    private readonly CatalogTelemetry _telemetry;
    private readonly ILogger<FigureCatalogService> _logger;

    public FigureCatalogService(
        IFigureRepository figures,
        ICategoryRepository categories,
        CatalogTelemetry telemetry,
        ILogger<FigureCatalogService> logger)
    {
        _figures = figures;
        _categories = categories;
        _telemetry = telemetry;
        _logger = logger;
    }

    public async Task<IReadOnlyList<LegoFigure>> ListAsync(
        string? category,
        string? search,
        CancellationToken cancellationToken)
    {
        var filter = BuildFilter(category, search);
        var stopwatch = Stopwatch.StartNew();
        using var activity = _telemetry.StartActivity("catalog.query");
        activity?.SetTag("catalog.query.filter", filter);
        try
        {
            var figures = await _figures.ListAsync(
                category,
                search,
                cancellationToken);
            stopwatch.Stop();
            _telemetry.RecordDatabase(stopwatch.Elapsed.TotalSeconds, "select");
            activity?.SetTag("catalog.query.result_count", figures.Count);
            _telemetry.RecordQuery(stopwatch.Elapsed.TotalSeconds, filter);
            return figures;
        }
        catch (Exception exception)
        {
            activity?.SetStatus(ActivityStatusCode.Error, exception.Message);
            CatalogTelemetry.RecordException(activity, exception);
            if (exception is System.Data.Common.DbException)
            {
                CatalogTelemetry.LogDatabaseFailure(_logger, "select", exception);
            }
            CatalogTelemetry.LogException(_logger, exception);
            using (_logger.BeginScope(
                new Dictionary<string, object>
                {
                    ["catalog.query.filter"] = filter,
                    ["exception.type"] =
                        exception.GetType().FullName ?? exception.GetType().Name,
                }))
            {
                _logger.LogError(
                    exception,
                    "catalog.query.failed filter={Filter}",
                    filter);
            }

            throw;
        }
    }

    public async Task<LegoFigure?> GetAsync(
        string id,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParseExact(id, "D", out var parsed)
            || !string.Equals(id, parsed.ToString("D"), StringComparison.Ordinal))
        {
            return null;
        }

        return await _figures.GetAsync(parsed, cancellationToken);
    }

    public Task<IReadOnlyList<Category>> CategoriesAsync(
        CancellationToken cancellationToken) =>
        _categories.ListAsync(cancellationToken);

    public static CatalogFigureDto ToDto(LegoFigure figure) =>
        new(
            figure.Id,
            figure.Name,
            figure.Description,
            figure.Category!.Name,
            figure.Category.Slug,
            figure.ImageFile);

    private static string BuildFilter(string? category, string? search)
    {
        if (!string.IsNullOrWhiteSpace(category)
            && !string.IsNullOrWhiteSpace(search))
        {
            return "category+search";
        }

        if (!string.IsNullOrWhiteSpace(category))
        {
            return "category";
        }

        return string.IsNullOrWhiteSpace(search) ? "all" : "search";
    }
}

public sealed record CatalogFigureDto(
    Guid ProductId,
    string Name,
    string Description,
    string Category,
    string CategorySlug,
    string Filename);
