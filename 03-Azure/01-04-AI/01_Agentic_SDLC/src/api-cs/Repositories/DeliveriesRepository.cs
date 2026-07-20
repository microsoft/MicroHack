using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class DeliveriesRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<Delivery>> FindAllAsync()
    {
        const string sql = "SELECT * FROM deliveries ORDER BY delivery_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<Delivery>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<Delivery?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM deliveries WHERE delivery_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Delivery> CreateAsync(CreateDeliveryRequest request)
    {
        const string sql = """
            INSERT INTO deliveries (supplier_id, delivery_date, name, description, status)
            VALUES ($supplierId, $deliveryDate, $name, $description, $status);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$supplierId", request.SupplierId);
        cmd.Parameters.AddWithValue("$deliveryDate", request.DeliveryDate);
        cmd.Parameters.AddWithValue("$name", request.Name);
        cmd.Parameters.AddWithValue("$description", (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$status", request.Status);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created Delivery");
    }

    public async Task<Delivery> UpdateAsync(int id, UpdateDeliveryRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.SupplierId.HasValue) { updates.Add("supplier_id = $supplierId"); parameters.Add(new SqliteParameter("$supplierId", request.SupplierId.Value)); }
        if (request.DeliveryDate is not null) { updates.Add("delivery_date = $deliveryDate"); parameters.Add(new SqliteParameter("$deliveryDate", request.DeliveryDate)); }
        if (request.Name is not null) { updates.Add("name = $name"); parameters.Add(new SqliteParameter("$name", request.Name)); }
        if (request.Description is not null) { updates.Add("description = $description"); parameters.Add(new SqliteParameter("$description", request.Description)); }
        if (request.Status is not null) { updates.Add("status = $status"); parameters.Add(new SqliteParameter("$status", request.Status)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE deliveries SET {string.Join(", ", updates)} WHERE delivery_id = $id;";
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
            throw new NotFoundException("Delivery", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated Delivery");
    }

    public async Task<Delivery> UpdateStatusAsync(int id, string status)
    {
        const string sql = "UPDATE deliveries SET status = $status WHERE delivery_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        cmd.Parameters.AddWithValue("$status", status);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Delivery", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated Delivery");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM deliveries WHERE delivery_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Delivery", id);
        }
    }

    private static Delivery Map(SqliteDataReader reader) =>
        new(
            DeliveryId: reader.GetInt32(reader.GetOrdinal("delivery_id")),
            SupplierId: reader.GetInt32(reader.GetOrdinal("supplier_id")),
            DeliveryDate: reader.GetString(reader.GetOrdinal("delivery_date")),
            Name: reader.GetString(reader.GetOrdinal("name")),
            Description: reader["description"] as string,
            Status: reader.GetString(reader.GetOrdinal("status"))
        );
}
