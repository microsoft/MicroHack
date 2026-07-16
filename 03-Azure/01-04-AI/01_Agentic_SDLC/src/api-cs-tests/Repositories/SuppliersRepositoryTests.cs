using Microsoft.Extensions.Logging.Abstractions;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;
using Xunit;

namespace OctoSupply.Api.Tests.Repositories;

public sealed class SuppliersRepositoryTests
{
    [Fact]
    public async Task CreateAndFindById_PersistsSupplier()
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"octosupply-tests-{Guid.NewGuid():N}.db");
        Environment.SetEnvironmentVariable("DB_FILE", dbPath);

        try
        {
            var factory = new SqliteConnectionFactory(new NullLogger<SqliteConnectionFactory>());
            await EnsureSchemaAsync(factory);
            var repository = new SuppliersRepository(factory);

            var created = await repository.CreateAsync(new CreateSupplierRequest
            {
                Name = "Test Supplier",
                Description = "desc",
                ContactPerson = "Alice",
                Email = "alice@example.com",
                Phone = "555-0100",
                Active = true,
                Verified = false
            });

            var fetched = await repository.FindByIdAsync(created.SupplierId);

            Assert.NotNull(fetched);
            Assert.Equal("Test Supplier", fetched!.Name);
            Assert.True(fetched.Active);
            Assert.False(fetched.Verified);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DB_FILE", null);
            if (File.Exists(dbPath))
            {
                File.Delete(dbPath);
            }
        }
    }

    [Fact]
    public async Task Update_WithNoFields_ThrowsValidationException()
    {
        var dbPath = Path.Combine(Path.GetTempPath(), $"octosupply-tests-{Guid.NewGuid():N}.db");
        Environment.SetEnvironmentVariable("DB_FILE", dbPath);

        try
        {
            var factory = new SqliteConnectionFactory(new NullLogger<SqliteConnectionFactory>());
            await EnsureSchemaAsync(factory);
            var repository = new SuppliersRepository(factory);
            var created = await repository.CreateAsync(new CreateSupplierRequest { Name = "Test Supplier" });

            var ex = await Assert.ThrowsAsync<ValidationException>(() => repository.UpdateAsync(created.SupplierId, new UpdateSupplierRequest()));
            Assert.Contains("No fields provided for update", ex.Message, StringComparison.Ordinal);
        }
        finally
        {
            Environment.SetEnvironmentVariable("DB_FILE", null);
            if (File.Exists(dbPath))
            {
                File.Delete(dbPath);
            }
        }
    }

    private static async Task EnsureSchemaAsync(SqliteConnectionFactory connectionFactory)
    {
        await using var connection = await connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = """
            CREATE TABLE suppliers (
                supplier_id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                contact_person TEXT,
                email TEXT,
                phone TEXT,
                active INTEGER NOT NULL DEFAULT 1,
                verified INTEGER NOT NULL DEFAULT 0
            );
            """;
        await cmd.ExecuteNonQueryAsync();
    }
}
