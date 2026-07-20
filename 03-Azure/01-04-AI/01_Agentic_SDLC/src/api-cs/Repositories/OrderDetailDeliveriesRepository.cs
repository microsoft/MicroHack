using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class OrderDetailDeliveriesRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<OrderDetailDelivery>> FindAllAsync()
    {
        const string sql = "SELECT * FROM order_detail_deliveries ORDER BY order_detail_delivery_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<OrderDetailDelivery>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<OrderDetailDelivery?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM order_detail_deliveries WHERE order_detail_delivery_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<OrderDetailDelivery> CreateAsync(CreateOrderDetailDeliveryRequest request)
    {
        const string sql = """
            INSERT INTO order_detail_deliveries (order_detail_id, delivery_id, quantity, notes)
            VALUES ($orderDetailId, $deliveryId, $quantity, $notes);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$orderDetailId", request.OrderDetailId);
        cmd.Parameters.AddWithValue("$deliveryId", request.DeliveryId);
        cmd.Parameters.AddWithValue("$quantity", request.Quantity);
        cmd.Parameters.AddWithValue("$notes", (object?)request.Notes ?? DBNull.Value);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created OrderDetailDelivery");
    }

    public async Task<OrderDetailDelivery> UpdateAsync(int id, UpdateOrderDetailDeliveryRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.OrderDetailId.HasValue) { updates.Add("order_detail_id = $orderDetailId"); parameters.Add(new SqliteParameter("$orderDetailId", request.OrderDetailId.Value)); }
        if (request.DeliveryId.HasValue) { updates.Add("delivery_id = $deliveryId"); parameters.Add(new SqliteParameter("$deliveryId", request.DeliveryId.Value)); }
        if (request.Quantity.HasValue) { updates.Add("quantity = $quantity"); parameters.Add(new SqliteParameter("$quantity", request.Quantity.Value)); }
        if (request.Notes is not null) { updates.Add("notes = $notes"); parameters.Add(new SqliteParameter("$notes", request.Notes)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE order_detail_deliveries SET {string.Join(", ", updates)} WHERE order_detail_delivery_id = $id;";
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
            throw new NotFoundException("OrderDetailDelivery", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated OrderDetailDelivery");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM order_detail_deliveries WHERE order_detail_delivery_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("OrderDetailDelivery", id);
        }
    }

    private static OrderDetailDelivery Map(SqliteDataReader reader) =>
        new(
            OrderDetailDeliveryId: reader.GetInt32(reader.GetOrdinal("order_detail_delivery_id")),
            OrderDetailId: reader.GetInt32(reader.GetOrdinal("order_detail_id")),
            DeliveryId: reader.GetInt32(reader.GetOrdinal("delivery_id")),
            Quantity: reader.GetInt32(reader.GetOrdinal("quantity")),
            Notes: reader["notes"] as string
        );
}
