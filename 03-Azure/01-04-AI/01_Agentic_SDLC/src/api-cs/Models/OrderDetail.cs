namespace OctoSupply.Api.Models;

public sealed record OrderDetail(
    int OrderDetailId,
    int OrderId,
    int ProductId,
    int Quantity,
    double UnitPrice,
    string? Notes);

public sealed class CreateOrderDetailRequest
{
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }
    public double UnitPrice { get; set; }
    public string? Notes { get; set; }
}

public sealed class UpdateOrderDetailRequest
{
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
    public int? Quantity { get; set; }
    public double? UnitPrice { get; set; }
    public string? Notes { get; set; }
}
