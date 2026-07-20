namespace OctoSupply.Api.Models;

public sealed record Branch(
    int BranchId,
    int HeadquartersId,
    string Name,
    string? Description,
    string? Address,
    string? ContactPerson,
    string? Email,
    string? Phone);

public sealed class CreateBranchRequest
{
    public int HeadquartersId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Address { get; set; }
    public string? ContactPerson { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
}

public sealed class UpdateBranchRequest
{
    public int? HeadquartersId { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string? Address { get; set; }
    public string? ContactPerson { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
}
