using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class SuppliersRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<Supplier>> FindAllAsync()
    {
        const string sql = "SELECT * FROM suppliers ORDER BY supplier_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<Supplier>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<Supplier?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM suppliers WHERE supplier_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Supplier> CreateAsync(CreateSupplierRequest request)
    {
        const string sql = """
            INSERT INTO suppliers (name, description, contact_person, email, phone, active, verified)
            VALUES ($name, $description, $contactPerson, $email, $phone, $active, $verified);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$name", request.Name);
        cmd.Parameters.AddWithValue("$description", (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$contactPerson", (object?)request.ContactPerson ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$email", (object?)request.Email ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$phone", (object?)request.Phone ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$active", request.Active ? 1 : 0);
        cmd.Parameters.AddWithValue("$verified", request.Verified ? 1 : 0);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created Supplier");
    }

    public async Task<Supplier> UpdateAsync(int id, UpdateSupplierRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.Name is not null) { updates.Add("name = $name"); parameters.Add(new SqliteParameter("$name", request.Name)); }
        if (request.Description is not null) { updates.Add("description = $description"); parameters.Add(new SqliteParameter("$description", request.Description)); }
        if (request.ContactPerson is not null) { updates.Add("contact_person = $contactPerson"); parameters.Add(new SqliteParameter("$contactPerson", request.ContactPerson)); }
        if (request.Email is not null) { updates.Add("email = $email"); parameters.Add(new SqliteParameter("$email", request.Email)); }
        if (request.Phone is not null) { updates.Add("phone = $phone"); parameters.Add(new SqliteParameter("$phone", request.Phone)); }
        if (request.Active.HasValue) { updates.Add("active = $active"); parameters.Add(new SqliteParameter("$active", request.Active.Value ? 1 : 0)); }
        if (request.Verified.HasValue) { updates.Add("verified = $verified"); parameters.Add(new SqliteParameter("$verified", request.Verified.Value ? 1 : 0)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE suppliers SET {string.Join(", ", updates)} WHERE supplier_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        foreach (var parameter in parameters)
        {
            cmd.Parameters.Add(parameter);
        }
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Supplier", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated Supplier");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM suppliers WHERE supplier_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Supplier", id);
        }
    }

    private static Supplier Map(SqliteDataReader reader) =>
        new(
            SupplierId: reader.GetInt32(reader.GetOrdinal("supplier_id")),
            Name: reader.GetString(reader.GetOrdinal("name")),
            Description: reader["description"] as string,
            ContactPerson: reader["contact_person"] as string,
            Email: reader["email"] as string,
            Phone: reader["phone"] as string,
            Active: Convert.ToInt32(reader["active"]) == 1,
            Verified: Convert.ToInt32(reader["verified"]) == 1
        );
}
