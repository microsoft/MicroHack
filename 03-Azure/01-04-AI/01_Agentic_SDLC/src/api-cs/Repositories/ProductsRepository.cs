using Microsoft.Data.Sqlite;
using OctoSupply.Api.Data;
using OctoSupply.Api.Models;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Repositories;

public sealed class ProductsRepository(SqliteConnectionFactory connectionFactory)
{
    private readonly SqliteConnectionFactory _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<Product>> FindAllAsync()
    {
        const string sql = "SELECT * FROM products ORDER BY product_id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        await using var reader = await cmd.ExecuteReaderAsync();
        var items = new List<Product>();
        while (await reader.ReadAsync())
        {
            items.Add(Map(reader));
        }
        return items;
    }

    public async Task<Product?> FindByIdAsync(int id)
    {
        const string sql = "SELECT * FROM products WHERE product_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Product> CreateAsync(CreateProductRequest request)
    {
        const string sql = """
            INSERT INTO products (supplier_id, name, description, price, sku, unit, img_name, discount)
            VALUES ($supplierId, $name, $description, $price, $sku, $unit, $imgName, $discount);
            SELECT last_insert_rowid();
            """;

        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$supplierId", request.SupplierId);
        cmd.Parameters.AddWithValue("$name", request.Name);
        cmd.Parameters.AddWithValue("$description", (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$price", request.Price);
        cmd.Parameters.AddWithValue("$sku", request.Sku);
        cmd.Parameters.AddWithValue("$unit", request.Unit);
        cmd.Parameters.AddWithValue("$imgName", (object?)request.ImgName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$discount", request.Discount);

        var id = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve created Product");
    }

    public async Task<Product> UpdateAsync(int id, UpdateProductRequest request)
    {
        var updates = new List<string>();
        var parameters = new List<SqliteParameter>();
        if (request.SupplierId.HasValue) { updates.Add("supplier_id = $supplierId"); parameters.Add(new SqliteParameter("$supplierId", request.SupplierId.Value)); }
        if (request.Name is not null) { updates.Add("name = $name"); parameters.Add(new SqliteParameter("$name", request.Name)); }
        if (request.Description is not null) { updates.Add("description = $description"); parameters.Add(new SqliteParameter("$description", request.Description)); }
        if (request.Price.HasValue) { updates.Add("price = $price"); parameters.Add(new SqliteParameter("$price", request.Price.Value)); }
        if (request.Sku is not null) { updates.Add("sku = $sku"); parameters.Add(new SqliteParameter("$sku", request.Sku)); }
        if (request.Unit is not null) { updates.Add("unit = $unit"); parameters.Add(new SqliteParameter("$unit", request.Unit)); }
        if (request.ImgName is not null) { updates.Add("img_name = $imgName"); parameters.Add(new SqliteParameter("$imgName", request.ImgName)); }
        if (request.Discount.HasValue) { updates.Add("discount = $discount"); parameters.Add(new SqliteParameter("$discount", request.Discount.Value)); }

        if (updates.Count == 0)
        {
            throw new ValidationException("No fields provided for update");
        }

        var sql = $"UPDATE products SET {string.Join(", ", updates)} WHERE product_id = $id;";
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
            throw new NotFoundException("Product", id);
        }

        return await FindByIdAsync(id) ?? throw new DatabaseException("Failed to retrieve updated Product");
    }

    public async Task DeleteAsync(int id)
    {
        const string sql = "DELETE FROM products WHERE product_id = $id;";
        await using var connection = await _connectionFactory.OpenConnectionAsync();
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.Parameters.AddWithValue("$id", id);
        var changes = await cmd.ExecuteNonQueryAsync();
        if (changes == 0)
        {
            throw new NotFoundException("Product", id);
        }
    }

    private static Product Map(SqliteDataReader reader) =>
        new(
            ProductId: reader.GetInt32(reader.GetOrdinal("product_id")),
            SupplierId: reader.GetInt32(reader.GetOrdinal("supplier_id")),
            Name: reader.GetString(reader.GetOrdinal("name")),
            Description: reader["description"] as string,
            Price: reader.GetDouble(reader.GetOrdinal("price")),
            Sku: reader.GetString(reader.GetOrdinal("sku")),
            Unit: reader.GetString(reader.GetOrdinal("unit")),
            ImgName: reader["img_name"] as string,
            Discount: reader.GetDouble(reader.GetOrdinal("discount"))
        );
}
