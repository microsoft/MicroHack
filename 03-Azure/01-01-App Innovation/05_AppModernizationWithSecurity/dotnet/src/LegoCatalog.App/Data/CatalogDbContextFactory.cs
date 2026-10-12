using LegoCatalog.App.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace LegoCatalog.App.Data;

/// <summary>
/// Creates the contract-configured context for EF migration commands.
/// </summary>
public sealed class CatalogDbContextFactory
    : IDesignTimeDbContextFactory<CatalogDbContext>
{
    public CatalogDbContext CreateDbContext(string[] args)
    {
        var workingDirectory = Directory.GetCurrentDirectory();
        var configuration = new ConfigurationBuilder()
            .SetBasePath(workingDirectory)
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables()
            .AddInMemoryCollection(
                new Dictionary<string, string?>
                {
                    ["PERFTEST_API_KEY"] = "design-time-only",
                })
            .Build();
        var runtime = CatalogRuntimeOptions.Load(
            configuration,
            workingDirectory);
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            .UseSqlServer(runtime.SqlConnectionString)
            .Options;
        return new CatalogDbContext(options);
    }
}
