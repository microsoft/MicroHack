using Microsoft.Data.Sqlite;

namespace OctoSupply.Api.Data;

public sealed class DatabaseMigrator(
    SqliteConnectionFactory connectionFactory,
    ILogger<DatabaseMigrator> logger)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;
    private readonly ILogger<DatabaseMigrator> _logger = logger;

    public async Task InitializeAsync(bool seedOnStartup)
    {
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await EnsureMigrationsTableAsync(connection);
        await ApplyMigrationsAsync(connection);
        if (seedOnStartup)
        {
            await SeedIfNeededAsync(connection);
        }
    }

    private static async Task EnsureMigrationsTableAsync(SqliteConnection connection)
    {
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = """
            CREATE TABLE IF NOT EXISTS migrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version INTEGER NOT NULL,
                filename TEXT NOT NULL UNIQUE,
                applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """;
        await cmd.ExecuteNonQueryAsync();
    }

    private async Task ApplyMigrationsAsync(SqliteConnection connection)
    {
        var migrationsDir = ResolvePath("../database/migrations");
        if (!Directory.Exists(migrationsDir))
        {
            throw new InvalidOperationException($"Migrations directory not found: {migrationsDir}");
        }

        var migrationFiles = Directory
            .GetFiles(migrationsDir, "*.sql")
            .OrderBy(Path.GetFileName)
            .ToList();

        foreach (var file in migrationFiles)
        {
            var filename = Path.GetFileName(file);
            if (await IsMigrationAppliedAsync(connection, filename))
            {
                continue;
            }

            _logger.LogInformation("Applying migration: {Filename}", filename);
            var sql = await File.ReadAllTextAsync(file);
            await ExecuteSqlStatementsAsync(connection, sql);

            var version = ParseMigrationVersion(filename);
            await using var insert = connection.CreateCommand();
            insert.CommandText = "INSERT INTO migrations (version, filename) VALUES ($version, $filename);";
            insert.Parameters.AddWithValue("$version", version);
            insert.Parameters.AddWithValue("$filename", filename);
            await insert.ExecuteNonQueryAsync();
        }
    }

    private async Task SeedIfNeededAsync(SqliteConnection connection)
    {
        var shouldSeed = true;
        try
        {
            await using var countCmd = connection.CreateCommand();
            countCmd.CommandText = "SELECT COUNT(*) FROM suppliers;";
            var count = Convert.ToInt32(await countCmd.ExecuteScalarAsync());
            shouldSeed = count == 0;
        }
        catch (SqliteException)
        {
            shouldSeed = true;
        }
        catch (InvalidOperationException)
        {
            shouldSeed = true;
        }

        if (!shouldSeed)
        {
            _logger.LogInformation("Database already seeded; skipping seed files.");
            return;
        }

        var seedDir = ResolvePath("../database/seed");
        if (!Directory.Exists(seedDir))
        {
            _logger.LogInformation("Seed directory not found: {SeedDir}. Skipping seeding.", seedDir);
            return;
        }

        var seedFiles = Directory
            .GetFiles(seedDir, "*.sql")
            .OrderBy(Path.GetFileName)
            .ToList();

        foreach (var file in seedFiles)
        {
            _logger.LogInformation("Applying seed file: {Filename}", Path.GetFileName(file));
            var sql = await File.ReadAllTextAsync(file);
            await ExecuteSqlStatementsAsync(connection, sql);
        }
    }

    private static async Task<bool> IsMigrationAppliedAsync(SqliteConnection connection, string filename)
    {
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM migrations WHERE filename = $filename;";
        cmd.Parameters.AddWithValue("$filename", filename);
        var count = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return count > 0;
    }

    private static async Task ExecuteSqlStatementsAsync(SqliteConnection connection, string sqlScript)
    {
        var statements = sqlScript
            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(statement => !string.IsNullOrWhiteSpace(statement))
            .ToList();

        await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync();
        foreach (var statement in statements)
        {
            await using var cmd = connection.CreateCommand();
            cmd.Transaction = transaction;
            cmd.CommandText = statement;
            await cmd.ExecuteNonQueryAsync();
        }
        await transaction.CommitAsync();
    }

    private static int ParseMigrationVersion(string filename)
    {
        var prefix = filename.Split('_')[0];
        return int.TryParse(prefix, out var version) ? version : 0;
    }

    private static string ResolvePath(string relativePath)
    {
        var configured = Environment.GetEnvironmentVariable("DB_MIGRATIONS_DIR");
        if (!string.IsNullOrWhiteSpace(configured) && relativePath.Contains("migrations", StringComparison.OrdinalIgnoreCase))
        {
            return Path.GetFullPath(configured);
        }

        return Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), relativePath));
    }
}
