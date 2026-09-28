using LegoCatalog.App.Data;
using LegoCatalog.App.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace LegoCatalog.App.Tests;

internal sealed class ContractWebApplicationFactory
    : WebApplicationFactory<Program>
{
    private readonly bool _databaseReady;
    private readonly StartupStatus _startupStatus;
    private readonly PerformanceBehavior _performanceBehavior;
    private readonly SqliteConnection? _catalogDatabase;

    public ContractWebApplicationFactory(
        bool databaseReady = true,
        StartupStatus startupStatus = StartupStatus.Ready,
        PerformanceBehavior performanceBehavior = PerformanceBehavior.Success,
        bool inMemoryCatalogDatabase = false)
    {
        Environment.SetEnvironmentVariable("PERFTEST_API_KEY", "test-api-key");
        Environment.SetEnvironmentVariable("DEPLOYMENT_ENVIRONMENT", "lab");
        Environment.SetEnvironmentVariable("OTEL_SERVICE_VERSION", "contract-test");
        Environment.SetEnvironmentVariable("CONTAINER_APP_REVISION", "contract-test");
        Environment.SetEnvironmentVariable(
            "CATALOG_IMAGES_PATH",
            Path.Combine(RepositoryRoot(), "data", "images"));
        Environment.SetEnvironmentVariable(
            "CATALOG_SEED_PATH",
            Path.Combine(RepositoryRoot(), "data", "catalog.json"));
        _databaseReady = databaseReady;
        _startupStatus = startupStatus;
        _performanceBehavior = performanceBehavior;
        _catalogDatabase = inMemoryCatalogDatabase ? OpenCatalogDatabase() : null;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration(
            configuration => configuration.AddInMemoryCollection(
                new Dictionary<string, string?>
                {
                    ["PERFTEST_API_KEY"] = "test-api-key",
                    ["CATALOG_STARTUP_IMPORT_ENABLED"] = "false",
                    ["CATALOG_IMAGES_PATH"] =
                        Path.Combine(RepositoryRoot(), "data", "images"),
                    ["CATALOG_SEED_PATH"] =
                        Path.Combine(RepositoryRoot(), "data", "catalog.json"),
                    ["DEPLOYMENT_ENVIRONMENT"] = "lab",
                    ["OTEL_SERVICE_VERSION"] = "contract-test",
                    ["CONTAINER_APP_REVISION"] = "contract-test",
                }));
        builder.ConfigureServices(
            services =>
            {
                services.RemoveAll<IHostedService>();
                services.RemoveAll<ICatalogDatabaseHealth>();
                services.AddScoped<ICatalogDatabaseHealth>(
                    _ => new FakeDatabaseHealth(_databaseReady));
                services.RemoveAll<IPerformanceCatalogService>();
                services.AddScoped<IPerformanceCatalogService>(
                    _ => new FakePerformanceService(_performanceBehavior));
                services.RemoveAll<StartupState>();
                var startup = new StartupState();
                if (_startupStatus == StartupStatus.Ready)
                {
                    startup.MarkReady();
                }
                else if (_startupStatus == StartupStatus.Failed)
                {
                    startup.MarkFailed();
                }

                services.AddSingleton(startup);

                if (_catalogDatabase is not null)
                {
                    RemoveCatalogDatabase(services);
                    services.AddDbContext<CatalogDbContext>(
                        options => options.UseSqlite(_catalogDatabase));
                }
            });
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);
        if (_catalogDatabase is not null)
        {
            using var scope = host.Services.CreateScope();
            CreateCatalogSchema(
                scope.ServiceProvider.GetRequiredService<CatalogDbContext>());
        }

        return host;
    }

    /// <summary>
    /// Locates the repository root that owns the canonical seed data and contracts.
    /// </summary>
    public static string RepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "workshop", "contracts")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("Repository root was not found.");
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing)
        {
            _catalogDatabase?.Dispose();
        }
    }

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
        _catalogDatabase?.Dispose();
    }

    /// <summary>
    /// Drops the SQL Server context registration, including the EF Core provider
    /// services that refuse to coexist with a second provider.
    /// </summary>
    private static void RemoveCatalogDatabase(IServiceCollection services)
    {
        var registrations = services
            .Where(descriptor =>
                descriptor.ServiceType == typeof(CatalogDbContext)
                || descriptor.ServiceType == typeof(DbContextOptions)
                || descriptor.ServiceType == typeof(DbContextOptions<CatalogDbContext>)
                || (descriptor.ServiceType.Namespace?.StartsWith(
                    "Microsoft.EntityFrameworkCore",
                    StringComparison.Ordinal) ?? false))
            .ToList();
        foreach (var registration in registrations)
        {
            services.Remove(registration);
        }
    }

    private static SqliteConnection OpenCatalogDatabase()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();

        // FigureRepository names the SQL Server case-insensitive collation explicitly;
        // SQLite resolves collations only from the connection that registers them.
        connection.CreateCollation(
            "Latin1_General_100_CI_AS",
            (left, right) =>
                string.Compare(left, right, StringComparison.OrdinalIgnoreCase));
        return connection;
    }

    private static void CreateCatalogSchema(CatalogDbContext database)
    {
        // The frozen EF model is the single source of the test schema. Only
        // CK_Figures_ImageFile is dropped: its expression uses SQL Server CONVERT and
        // '+' concatenation, which SQLite cannot parse.
        var script = string.Join(
            Environment.NewLine,
            database.Database
                .GenerateCreateScript()
                .Split(Environment.NewLine)
                .Where(line => !line.Contains(
                    "CK_Figures_ImageFile",
                    StringComparison.Ordinal)));
        database.Database.ExecuteSqlRaw(script);
    }

    private sealed class FakeDatabaseHealth : ICatalogDatabaseHealth
    {
        private readonly bool _ready;

        public FakeDatabaseHealth(bool ready) => _ready = ready;

        public Task<bool> CanConnectAsync(CancellationToken cancellationToken) =>
            Task.FromResult(_ready);
    }

    private sealed class FakePerformanceService : IPerformanceCatalogService
    {
        private readonly PerformanceBehavior _behavior;

        public FakePerformanceService(PerformanceBehavior behavior) =>
            _behavior = behavior;

        public Task<PerformanceResult> ExecuteAsync(
            CancellationToken cancellationToken) =>
            _behavior switch
            {
                PerformanceBehavior.DependencyUnavailable =>
                    throw new CatalogDependencyUnavailableException(),
                PerformanceBehavior.Timeout =>
                    throw new CatalogQueryTimeoutException(),
                _ => Task.FromResult(
                    new PerformanceResult(
                        10,
                        0,
                        1,
                        Array.Empty<CatalogFigureDto>())),
            };
    }
}

internal enum PerformanceBehavior
{
    Success,
    DependencyUnavailable,
    Timeout,
}
