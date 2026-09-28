using System.Data.Common;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using LegoCatalog.App.Configuration;
using LegoCatalog.App.Services;

namespace LegoCatalog.App.Endpoints;

/// <summary>
/// Maps the path-neutral HTTP behavior frozen by the shared contract.
/// </summary>
public static class CatalogEndpoints
{
    public static IEndpointRouteBuilder MapCatalogEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/healthz",
            () => Results.Json(new { status = "healthy" }));

        endpoints.MapGet(
            "/readyz",
            ReadinessAsync);

        endpoints.MapGet(
            "/images/{fileName}",
            (string fileName, IImageStore imageStore) =>
                imageStore.TryResolvePath(fileName, out var path)
                    ? Results.File(path, "image/png")
                    : Results.NotFound());

        endpoints.MapGet(
            "/figure/{id}",
            async (
                string id,
                FigureCatalogService catalog,
                CancellationToken cancellationToken) =>
            {
                var figure = await catalog.GetAsync(id, cancellationToken);
                return figure is null
                    ? Results.NotFound()
                    : Results.Content(
                        CatalogHtml.RenderDetail(figure),
                        "text/html",
                        Encoding.UTF8);
            });

        endpoints.MapPost(
            "/import",
            ImportAsync);

        endpoints.MapGet(
            "/perftest/catalog",
            PerformanceAsync);

        return endpoints;
    }

    private static async Task<IResult> ReadinessAsync(
        ICatalogDatabaseHealth database,
        StartupState startup,
        CatalogTelemetry telemetry,
        ILoggerFactory loggerFactory,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        var databaseReady = false;
        var logger = loggerFactory.CreateLogger("Catalog.Database");
        try
        {
            databaseReady = await database.CanConnectAsync(cancellationToken);
            stopwatch.Stop();
            telemetry.RecordDatabase(stopwatch.Elapsed.TotalSeconds, "connect");
            if (!databaseReady)
            {
                CatalogTelemetry.LogDatabaseFailure(logger, "connect");
            }
        }
        catch (DbException exception)
        {
            stopwatch.Stop();
            telemetry.RecordDatabase(stopwatch.Elapsed.TotalSeconds, "connect");
            CatalogTelemetry.LogDatabaseFailure(logger, "connect", exception);
            CatalogTelemetry.LogException(logger, exception);
        }

        var import = startup.Status switch
        {
            StartupStatus.Ready => "ready",
            StartupStatus.Failed => "failed",
            _ => "not_ready",
        };
        var checks = new
        {
            database = databaseReady ? "ready" : "not_ready",
            import,
        };
        return databaseReady && startup.Status == StartupStatus.Ready
            ? Results.Json(new { status = "ready", checks })
            : Results.Json(
                new { status = "not_ready", checks },
                statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private static async Task<IResult> ImportAsync(
        HttpRequest request,
        ImportService importer,
        CancellationToken cancellationToken)
    {
        if (!request.HasFormContentType)
        {
            return InvalidImport("multipart/form-data is required.");
        }

        try
        {
            var form = await request.ReadFormAsync(cancellationToken);
            var file = form.Files.GetFile("catalogFile");
            if (file is null || file.Length == 0)
            {
                return InvalidImport("catalogFile is required.");
            }

            await using var stream = file.OpenReadStream();
            var result = await importer.ImportAsync(stream, cancellationToken);
            return Results.Json(result);
        }
        catch (CatalogImportValidationException exception)
        {
            return InvalidImport(exception.Message);
        }
        catch (InvalidDataException exception)
        {
            return InvalidImport(exception.Message);
        }
    }

    private static async Task<IResult> PerformanceAsync(
        HttpRequest request,
        CatalogRuntimeOptions options,
        IPerformanceCatalogService performance,
        CancellationToken cancellationToken)
    {
        var provided = request.Headers["x-api-key"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(provided)
            || !KeysEqual(provided.Trim(), options.PerformanceApiKey))
        {
            return Results.Json(
                new { status = "unauthorized", error = "invalid_api_key" },
                statusCode: StatusCodes.Status401Unauthorized);
        }

        try
        {
            return Results.Json(
                await performance.ExecuteAsync(cancellationToken));
        }
        catch (CatalogQueryTimeoutException)
        {
            return Results.Json(
                new
                {
                    status = "unavailable",
                    error = "catalog_query_timeout",
                },
                statusCode: StatusCodes.Status504GatewayTimeout);
        }
        catch (CatalogDependencyUnavailableException)
        {
            return Results.Json(
                new
                {
                    status = "unavailable",
                    error = "catalog_dependency_unavailable",
                },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }
    }

    private static IResult InvalidImport(string message) =>
        Results.Json(
            new
            {
                status = "invalid",
                error = "invalid_catalog",
                message,
            },
            statusCode: StatusCodes.Status400BadRequest);

    private static bool KeysEqual(string provided, string expected)
    {
        var providedHash = SHA256.HashData(Encoding.UTF8.GetBytes(provided));
        var expectedHash = SHA256.HashData(Encoding.UTF8.GetBytes(expected));
        return CryptographicOperations.FixedTimeEquals(providedHash, expectedHash);
    }
}
