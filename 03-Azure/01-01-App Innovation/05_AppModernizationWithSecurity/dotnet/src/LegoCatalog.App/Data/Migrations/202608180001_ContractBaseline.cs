using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LegoCatalog.App.Data.Migrations
{
    /// <inheritdoc />
    public partial class ContractBaseline : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Categories",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Slug = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Categories", x => x.Id);
                    table.UniqueConstraint("UQ_Categories_Name", x => x.Name);
                    table.UniqueConstraint("UQ_Categories_Slug", x => x.Slug);
                });

            migrationBuilder.CreateTable(
                name: "Figures",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    CategoryId = table.Column<int>(type: "int", nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1200)", maxLength: 1200, nullable: false),
                    ImageFile = table.Column<string>(type: "varchar(40)", unicode: false, maxLength: 40, nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastUpdatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Figures", x => x.Id);
                    table.CheckConstraint("CK_Figures_ImageFile", "[ImageFile] = LOWER(CONVERT(varchar(36), [Id])) + '.png'");
                    table.ForeignKey(
                        name: "FK_Figures_Categories",
                        column: x => x.CategoryId,
                        principalTable: "Categories",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Figures_CategoryId",
                table: "Figures",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_Figures_Name",
                table: "Figures",
                column: "Name");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Figures");

            migrationBuilder.DropTable(
                name: "Categories");
        }
    }
}
