using LegoCatalog.App.Configuration;
using LegoCatalog.App.Data;
using LegoCatalog.App.Endpoints;
using LegoCatalog.App.Middleware;
using LegoCatalog.App.Services;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
var runtime = CatalogRuntimeOptions.Load(
    builder.Configuration,
    builder.Environment.ContentRootPath);
builder.Services.AddSingleton(runtime);

builder.Services.AddDbContext<CatalogDbContext>(
    options => options.UseSqlServer(
        runtime.SqlConnectionString,
        sqlServer => sqlServer
            .CommandTimeout(15)
            .EnableRetryOnFailure()));
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.Configure<FormOptions>(
    options => options.MultipartBodyLengthLimit = 4 * 1024 * 1024);

builder.Services.AddSingleton<CatalogTelemetry>();
builder.Services.AddSingleton<StartupState>();
builder.Services.AddSingleton<CatalogDocumentParser>();
builder.Services.AddScoped<IFigureRepository, FigureRepository>();
builder.Services.AddScoped<ICategoryRepository, CategoryRepository>();
builder.Services.AddScoped<IImageStore, LocalImageStore>();
builder.Services.AddScoped<ICatalogDatabaseHealth, CatalogDatabaseHealth>();
builder.Services.AddScoped<FigureCatalogService>();
builder.Services.AddScoped<ImportService>();
builder.Services.AddScoped<IPerformanceCatalogService, PerformanceCatalogService>();
builder.Services.AddHostedService<StartupImportHostedService>();

var hasOtlpExporter = new[]
{
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
    "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
    "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT",
}.Any(key => !string.IsNullOrWhiteSpace(builder.Configuration[key]));

builder.Services
    .AddOpenTelemetry()
    .ConfigureResource(
        resource => resource
            .AddService(
                serviceName: CatalogTelemetry.ServiceName,
                serviceNamespace: CatalogTelemetry.ServiceNamespace,
                serviceVersion: runtime.ServiceVersion,
                serviceInstanceId: Environment.MachineName)
            .AddAttributes(
                new Dictionary<string, object>
                {
                    [CatalogTelemetry.DeploymentEnvironmentAttribute] =
                        runtime.DeploymentEnvironment,
                    [CatalogTelemetry.RevisionAttribute] = runtime.RevisionName,
                }))
    .WithMetrics(
        metrics =>
        {
            metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddMeter(CatalogTelemetry.InstrumentationName);
            if (hasOtlpExporter)
            {
                metrics.AddOtlpExporter();
            }
        })
    .WithTracing(
        tracing =>
        {
            tracing
                .AddAspNetCoreInstrumentation(
                    options => options.RecordException = true)
                .AddHttpClientInstrumentation()
                .AddSqlClientInstrumentation()
                .AddSource(CatalogTelemetry.InstrumentationName);
            if (hasOtlpExporter)
            {
                tracing.AddOtlpExporter();
            }
        });

builder.Logging.AddOpenTelemetry(
    logging =>
    {
        logging.IncludeFormattedMessage = true;
        logging.IncludeScopes = true;
        if (hasOtlpExporter)
        {
            logging.AddOtlpExporter();
        }
    });

var app = builder.Build();
app.UseMiddleware<OriginalRequestTargetMiddleware>();
app.UseStaticFiles();
app.UseRouting();
app.UseMiddleware<RequestTelemetryMiddleware>();
app.UseExceptionHandler("/Error");
app.MapCatalogEndpoints();
app.MapRazorPages();
app.MapBlazorHub();
app.MapFallbackToPage("/import", "/_Host");
app.Run();

public partial class Program;
