namespace OctoSupply.Api.Models;

public sealed record Order(
    int OrderId,
    int BranchId,
    string OrderDate,
    string Name,
    string? Description,
    string Status);

public sealed class CreateOrderRequest
{
    public int BranchId { get; set; }
    public string OrderDate { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Status { get; set; } = "pending";
}

public sealed class UpdateOrderRequest
{
    public int? BranchId { get; set; }
    public string? OrderDate { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string? Status { get; set; }
}
