namespace LegoCatalog.App.Models;

/// <summary>
/// Product category (e.g., Space Exploration, Medieval, etc.).
/// </summary>
public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public ICollection<LegoFigure> Figures { get; set; } = new List<LegoFigure>();
}
