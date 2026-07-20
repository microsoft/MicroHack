using Microsoft.Data.Sqlite;

namespace OctoSupply.Api.Data;

public sealed class SqliteConnectionFactory(ILogger<SqliteConnectionFactory> logger)
{
    private readonly ILogger<SqliteConnectionFactory> _logger = logger;

    public async Task<SqliteConnection> OpenConnectionAsync()
    {
        var dbFile = Environment.GetEnvironmentVariable("DB_FILE") ?? "./data/app.db";
        if (!string.Equals(dbFile, ":memory:", StringComparison.Ordinal))
        {
            var fullPath = Path.GetFullPath(dbFile);
            var directory = Path.GetDirectoryName(fullPath);
            if (!string.IsNullOrWhiteSpace(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
            dbFile = fullPath;
        }

        var connectionString = $"Data Source={dbFile}";
        var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        await using var pragma = connection.CreateCommand();
        pragma.CommandText = """
            PRAGMA foreign_keys = ON;
            PRAGMA journal_mode = WAL;
            PRAGMA busy_timeout = 30000;
            """;
        await pragma.ExecuteNonQueryAsync();

        _logger.LogDebug("Opened SQLite connection to {DbFile}", dbFile);
        return connection;
    }
}
