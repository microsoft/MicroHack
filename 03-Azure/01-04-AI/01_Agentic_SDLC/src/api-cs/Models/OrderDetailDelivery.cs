namespace OctoSupply.Api.Models;

public sealed record OrderDetailDelivery(
    int OrderDetailDeliveryId,
    int OrderDetailId,
    int DeliveryId,
    int Quantity,
    string? Notes);

public sealed class CreateOrderDetailDeliveryRequest
{
    public int OrderDetailId { get; set; }
    public int DeliveryId { get; set; }
    public int Quantity { get; set; }
    public string? Notes { get; set; }
}

public sealed class UpdateOrderDetailDeliveryRequest
{
    public int? OrderDetailId { get; set; }
    public int? DeliveryId { get; set; }
    public int? Quantity { get; set; }
    public string? Notes { get; set; }
}
