using LegoCatalog.App.Data;
using LegoCatalog.App.Models;
using Microsoft.EntityFrameworkCore;

namespace LegoCatalog.App.Services;

public interface IFigureRepository
{
    Task<IReadOnlyList<LegoFigure>> ListAsync(
        string? category,
        string? search,
        CancellationToken cancellationToken);

    Task<LegoFigure?> GetAsync(Guid id, CancellationToken cancellationToken);
}

public interface ICategoryRepository
{
    Task<IReadOnlyList<Category>> ListAsync(CancellationToken cancellationToken);
}

/// <summary>
/// Executes deterministic SQL Server catalog queries.
/// </summary>
public sealed class FigureRepository : IFigureRepository
{
    private const string CaseInsensitiveCollation = "Latin1_General_100_CI_AS";
    private readonly CatalogDbContext _database;

    public FigureRepository(CatalogDbContext database) => _database = database;

    public async Task<IReadOnlyList<LegoFigure>> ListAsync(
        string? category,
        string? search,
        CancellationToken cancellationToken)
    {
        var query = _database.Figures
            .AsNoTracking()
            .Include(figure => figure.Category)
            .AsQueryable();
        if (!string.IsNullOrWhiteSpace(category))
        {
            var categoryFilter = category.Trim();
            query = query.Where(figure =>
                figure.Category!.Slug == categoryFilter
                || EF.Functions.Collate(
                    figure.Category.Name,
                    CaseInsensitiveCollation) == categoryFilter);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var searchFilter = EscapeLikePattern(search.Trim());
            query = query.Where(figure =>
                EF.Functions.Like(
                    EF.Functions.Collate(
                        figure.Name,
                        CaseInsensitiveCollation),
                    $"%{searchFilter}%",
                    "\\"));
        }

        var figures = await query.ToListAsync(cancellationToken);
        return figures
            .OrderBy(figure => figure.Id.ToString("D"), StringComparer.Ordinal)
            .ToList();
    }

    private static string EscapeLikePattern(string value) =>
        value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal)
            .Replace("[", "\\[", StringComparison.Ordinal);

    public Task<LegoFigure?> GetAsync(
        Guid id,
        CancellationToken cancellationToken) =>
        _database.Figures
            .AsNoTracking()
            .Include(figure => figure.Category)
            .FirstOrDefaultAsync(figure => figure.Id == id, cancellationToken);
}

/// <summary>
/// Reads category filter options in stable display order.
/// </summary>
public sealed class CategoryRepository : ICategoryRepository
{
    private readonly CatalogDbContext _database;

    public CategoryRepository(CatalogDbContext database) => _database = database;

    public async Task<IReadOnlyList<Category>> ListAsync(
        CancellationToken cancellationToken) =>
        await _database.Categories
            .AsNoTracking()
            .OrderBy(category => category.Name)
            .ToListAsync(cancellationToken);
}
