using LegoCatalog.App.Models;
using Microsoft.EntityFrameworkCore;

namespace LegoCatalog.App.Data;

/// <summary>
/// EF Core DbContext for the catalog.
/// </summary>
public class CatalogDbContext : DbContext
{
    public CatalogDbContext(DbContextOptions<CatalogDbContext> options) : base(options) {}

    public DbSet<Category> Categories => Set<Category>();
    public DbSet<LegoFigure> Figures => Set<LegoFigure>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Category>(e =>
        {
            e.ToTable("Categories");
            e.HasKey(c => c.Id).HasName("PK_Categories");
            e.HasAlternateKey(c => c.Name).HasName("UQ_Categories_Name");
            e.HasAlternateKey(c => c.Slug).HasName("UQ_Categories_Slug");
            e.Property(c => c.Name).HasMaxLength(64).IsRequired();
            e.Property(c => c.Slug).HasMaxLength(64).IsUnicode(false).IsRequired();
        });

        modelBuilder.Entity<LegoFigure>(e =>
        {
            e.ToTable(
                "Figures",
                table => table.HasCheckConstraint(
                    "CK_Figures_ImageFile",
                    "[ImageFile] = LOWER(CONVERT(varchar(36), [Id])) + '.png'"));
            e.HasKey(f => f.Id).HasName("PK_Figures");
            e.Property(f => f.Name).HasMaxLength(80).IsRequired();
            e.Property(f => f.Description).HasMaxLength(1200).IsRequired();
            e.Property(f => f.ImageFile).HasMaxLength(40).IsUnicode(false).IsRequired();
            e.Property(f => f.CreatedUtc).HasColumnType("datetime2").IsRequired();
            e.Property(f => f.LastUpdatedUtc).HasColumnType("datetime2").IsRequired();
            e.HasIndex(f => f.Name).HasDatabaseName("IX_Figures_Name");
            e.HasIndex(f => f.CategoryId).HasDatabaseName("IX_Figures_CategoryId");
            e.HasOne(f => f.Category)
                .WithMany(c => c.Figures)
                .HasForeignKey(f => f.CategoryId)
                .HasConstraintName("FK_Figures_Categories")
                .OnDelete(DeleteBehavior.NoAction);
        });
    }
}
