using LegoCatalog.App.Data;

namespace LegoCatalog.App.Services;

public interface ICatalogDatabaseHealth
{
    Task<bool> CanConnectAsync(CancellationToken cancellationToken);
}

/// <summary>
/// Performs a bounded SQL Server connectivity check for readiness.
/// </summary>
public sealed class CatalogDatabaseHealth : ICatalogDatabaseHealth
{
    private readonly CatalogDbContext _database;

    public CatalogDatabaseHealth(CatalogDbContext database) => _database = database;

    public Task<bool> CanConnectAsync(CancellationToken cancellationToken) =>
        _database.Database.CanConnectAsync(cancellationToken);
}
