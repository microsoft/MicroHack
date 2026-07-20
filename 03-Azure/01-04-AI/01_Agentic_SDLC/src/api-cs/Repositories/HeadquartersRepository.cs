using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class HeadquartersRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<Headquarters>> FindAllAsync()
    {
        const string sql = "SELECT * FROM headquarters ORDER BY headquarters_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<Headquarters>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<Headquarters?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM headquarters WHERE headquarters_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<object> GetMetricsAsync(int id)
    {
        var headquarters = await FindByIdAsync(id);
        if (headquarters is null)
        {
            throw new NotFoundException("Headquarters", id);
        }

        // Mirrors the TypeScript route behavior where missing floor/capacity resolve to 0.
        var score = headquarters.HeadquartersId;
        var average = headquarters.HeadquartersId / 2.0;
        var display = $"HQ-{headquarters.HeadquartersId}0";

        return new
        {
            score,
            average,
            display
        };
    }

    public async Task<Headquarters> CreateAsync(CreateHeadquartersRequest request)
    {
        const string sql = """
            INSERT INTO headquarters (name, description, address, contact_person, email, phone)
            VALUES ($name, $description, $address, $contactPerson, $email, $phone);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$name", request.Name);
        cmd.Parameters.AddWithValue("$description", (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$address", (object?)request.Address ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$contactPerson", (object?)request.ContactPerson ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$email", (object?)request.Email ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$phone", (object?)request.Phone ?? DBNull.Value);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created Headquarters");
    }

    public async Task<Headquarters> UpdateAsync(int id, UpdateHeadquartersRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.Name is not null) { updates.Add("name = $name"); parameters.Add(new SqliteParameter("$name", request.Name)); }
        if (request.Description is not null) { updates.Add("description = $description"); parameters.Add(new SqliteParameter("$description", request.Description)); }
        if (request.Address is not null) { updates.Add("address = $address"); parameters.Add(new SqliteParameter("$address", request.Address)); }
        if (request.ContactPerson is not null) { updates.Add("contact_person = $contactPerson"); parameters.Add(new SqliteParameter("$contactPerson", request.ContactPerson)); }
        if (request.Email is not null) { updates.Add("email = $email"); parameters.Add(new SqliteParameter("$email", request.Email)); }
        if (request.Phone is not null) { updates.Add("phone = $phone"); parameters.Add(new SqliteParameter("$phone", request.Phone)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE headquarters SET {string.Join(", ", updates)} WHERE headquarters_id = $id;";
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
            throw new NotFoundException("Headquarters", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated Headquarters");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM headquarters WHERE headquarters_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Headquarters", id);
        }
    }

    private static Headquarters Map(SqliteDataReader reader) =>
        new(
            HeadquartersId: reader.GetInt32(reader.GetOrdinal("headquarters_id")),
            Name: reader.GetString(reader.GetOrdinal("name")),
            Description: reader["description"] as string,
            Address: reader["address"] as string,
            ContactPerson: reader["contact_person"] as string,
            Email: reader["email"] as string,
            Phone: reader["phone"] as string
        );
}
