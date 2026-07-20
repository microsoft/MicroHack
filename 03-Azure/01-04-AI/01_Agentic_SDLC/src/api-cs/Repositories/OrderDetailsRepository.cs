using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class OrderDetailsRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<OrderDetail>> FindAllAsync()
    {
        const string sql = "SELECT * FROM order_details ORDER BY order_detail_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<OrderDetail>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<OrderDetail?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM order_details WHERE order_detail_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<OrderDetail> CreateAsync(CreateOrderDetailRequest request)
    {
        const string sql = """
            INSERT INTO order_details (order_id, product_id, quantity, unit_price, notes)
            VALUES ($orderId, $productId, $quantity, $unitPrice, $notes);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$orderId", request.OrderId);
        cmd.Parameters.AddWithValue("$productId", request.ProductId);
        cmd.Parameters.AddWithValue("$quantity", request.Quantity);
        cmd.Parameters.AddWithValue("$unitPrice", request.UnitPrice);
        cmd.Parameters.AddWithValue("$notes", (object?)request.Notes ?? DBNull.Value);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created OrderDetail");
    }

    public async Task<OrderDetail> UpdateAsync(int id, UpdateOrderDetailRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.OrderId.HasValue) { updates.Add("order_id = $orderId"); parameters.Add(new SqliteParameter("$orderId", request.OrderId.Value)); }
        if (request.ProductId.HasValue) { updates.Add("product_id = $productId"); parameters.Add(new SqliteParameter("$productId", request.ProductId.Value)); }
        if (request.Quantity.HasValue) { updates.Add("quantity = $quantity"); parameters.Add(new SqliteParameter("$quantity", request.Quantity.Value)); }
        if (request.UnitPrice.HasValue) { updates.Add("unit_price = $unitPrice"); parameters.Add(new SqliteParameter("$unitPrice", request.UnitPrice.Value)); }
        if (request.Notes is not null) { updates.Add("notes = $notes"); parameters.Add(new SqliteParameter("$notes", request.Notes)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE order_details SET {string.Join(", ", updates)} WHERE order_detail_id = $id;";
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
            throw new NotFoundException("OrderDetail", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated OrderDetail");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM order_details WHERE order_detail_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("OrderDetail", id);
        }
    }

    private static OrderDetail Map(SqliteDataReader reader) =>
        new(
            OrderDetailId: reader.GetInt32(reader.GetOrdinal("order_detail_id")),
            OrderId: reader.GetInt32(reader.GetOrdinal("order_id")),
            ProductId: reader.GetInt32(reader.GetOrdinal("product_id")),
            Quantity: reader.GetInt32(reader.GetOrdinal("quantity")),
            UnitPrice: reader.GetDouble(reader.GetOrdinal("unit_price")),
            Notes: reader["notes"] as string
        );
}
