namespace OctoSupply.Api.Models;

public sealed record Supplier(
    int SupplierId,
    string Name,
    string? Description,
    string? ContactPerson,
    string? Email,
    string? Phone,
    bool Active,
    bool Verified);

public sealed class CreateSupplierRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? ContactPerson { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public bool Active { get; set; } = true;
    public bool Verified { get; set; } = false;
}

public sealed class UpdateSupplierRequest
{
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string? ContactPerson { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public bool? Active { get; set; }
    public bool? Verified { get; set; }
}
