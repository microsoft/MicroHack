namespace OctoSupply.Api.Models;

public sealed record Delivery(
    int DeliveryId,
    int SupplierId,
    string DeliveryDate,
    string Name,
    string? Description,
    string Status);

public sealed class CreateDeliveryRequest
{
    public int SupplierId { get; set; }
    public string DeliveryDate { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Status { get; set; } = "pending";
}

public sealed class UpdateDeliveryRequest
{
    public int? SupplierId { get; set; }
    public string? DeliveryDate { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string? Status { get; set; }
}
