using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using LegoCatalog.App.Data;
using LegoCatalog.App.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LegoCatalog.App.Tests;

/// <summary>
/// Mirrors the Java reference behavior suite so both tracks prove the same catalog
/// contract: name-only case-insensitive search, category filtering by slug or name,
/// canonical figure identity, connector-level alias rejection, and idempotent import.
/// </summary>
public sealed partial class CatalogBehaviorTests
{
    private const string PercentFigureId = "3a3a3a3a-3333-4333-8333-333333333331";
    private const string UnderscoreFigureId = "3b3b3b3b-3333-4333-8333-333333333332";
    private const string EscapeFigureId = "3c3c3c3c-3333-4333-8333-333333333333";
    private const string ControlFigureId = "4d4d4d4d-4444-4444-8444-444444444441";
    private const string AbsentFigureId = "5e5e5e5e-5555-4555-8555-555555555555";
    private const string CanonicalImageKey =
        "009f7b99-db28-4fff-bbf4-fd68860b968c.png";

    /// <summary>
    /// Four figures: three whose names carry LIKE metacharacters and one control whose
    /// description – but never its name – repeats a searched name.
    /// </summary>
    private const string LiteralSearchDocument = $$"""
        [
          {
            "productId":"{{PercentFigureId}}",
            "name":"Literal % Figure",
            "description":"A catalog figure whose name contains a literal percent character.",
            "category":"Literal Search",
            "filename":"{{PercentFigureId}}.png",
            "imagePrompt":"Photorealistic construction-toy figure with a literal percent symbol."
          },
          {
            "productId":"{{UnderscoreFigureId}}",
            "name":"Literal _ Figure",
            "description":"A catalog figure whose name contains a literal underscore character.",
            "category":"Literal Search",
            "filename":"{{UnderscoreFigureId}}.png",
            "imagePrompt":"Photorealistic construction-toy figure with a literal underscore symbol."
          },
          {
            "productId":"{{EscapeFigureId}}",
            "name":"Literal ! Figure",
            "description":"A catalog figure whose name contains the configured LIKE escape character.",
            "category":"Literal Search",
            "filename":"{{EscapeFigureId}}.png",
            "imagePrompt":"Photorealistic construction-toy figure with a literal exclamation symbol."
          },
          {
            "productId":"{{ControlFigureId}}",
            "name":"Wildcard Free Control",
            "description":"A control figure whose description names Literal % Figure although its own name does not.",
            "category":"Contract Controls",
            "filename":"{{ControlFigureId}}.png",
            "imagePrompt":"Photorealistic construction-toy figure used as a catalog search control subject."
          }
        ]
        """;

    /// <summary>
    /// Search matches the name only, ignores case, and treats LIKE wildcards and the
    /// escape character as literal text.
    /// </summary>
    [Fact(DisplayName = "Contract.Catalog.SearchMatchesNameOnly")]
    public async Task SearchMatchesNameCaseInsensitivelyAndIgnoresDescription()
    {
        await using var factory = new ContractWebApplicationFactory(
            inMemoryCatalogDatabase: true);
        await ImportAsync(factory, LiteralSearchDocument);
        using var client = factory.CreateClient();

        Assert.Equal(
            new[] { PercentFigureId },
            await FigureIdsAsync(client, search: "%"));
        Assert.Equal(
            new[] { UnderscoreFigureId },
            await FigureIdsAsync(client, search: "_"));
        Assert.Equal(
            new[] { EscapeFigureId },
            await FigureIdsAsync(client, search: "!"));

        // The control figure repeats this exact phrase in its description only.
        Assert.Equal(
            new[] { PercentFigureId },
            await FigureIdsAsync(client, search: "Literal % Figure"));
        Assert.Equal(
            new[] { PercentFigureId },
            await FigureIdsAsync(client, search: "literal % figure"));
        Assert.Equal(
            new[] { PercentFigureId },
            await FigureIdsAsync(client, search: "LITERAL % FIGURE"));

        Assert.Empty(await FigureIdsAsync(client, search: "literal percent character"));
        Assert.Empty(await FigureIdsAsync(client, search: "control figure whose"));
    }

    /// <summary>
    /// The category filter accepts the canonical slug or the display name in any case,
    /// and combines with search.
    /// </summary>
    [Fact(DisplayName = "Contract.Catalog.CategoryFilterAcceptsSlugAndName")]
    public async Task CategoryFilterAcceptsSlugAndName()
    {
        await using var factory = new ContractWebApplicationFactory(
            inMemoryCatalogDatabase: true);
        await ImportAsync(factory, LiteralSearchDocument);
        using var client = factory.CreateClient();
        var literalSearch = new[]
        {
            PercentFigureId,
            UnderscoreFigureId,
            EscapeFigureId,
        };

        Assert.Equal(
            literalSearch,
            await FigureIdsAsync(client, category: "literal-search"));
        Assert.Equal(
            literalSearch,
            await FigureIdsAsync(client, category: "Literal Search"));
        Assert.Equal(
            literalSearch,
            await FigureIdsAsync(client, category: "LITERAL SEARCH"));
        Assert.Equal(
            new[] { ControlFigureId },
            await FigureIdsAsync(client, category: "contract-controls"));

        Assert.Equal(
            new[] { UnderscoreFigureId },
            await FigureIdsAsync(client, category: "literal-search", search: "_"));
        Assert.Equal(
            new[] { EscapeFigureId },
            await FigureIdsAsync(client, category: "LITERAL SEARCH", search: "!"));

        // The slug is matched ordinally, so a slug-cased alias is not a category.
        Assert.Empty(await FigureIdsAsync(client, category: "LITERAL-SEARCH"));
        Assert.Empty(await FigureIdsAsync(client, category: "unknown-category"));
    }

    /// <summary>
    /// Only a canonical lowercase hyphenated UUID resolves a figure; every other
    /// spelling of the same identity is unknown.
    /// </summary>
    [Fact(DisplayName = "Contract.Catalog.FigureIdentityIsCanonical")]
    public async Task GetFigureReturns404ForUnknownId()
    {
        await using var factory = new ContractWebApplicationFactory(
            inMemoryCatalogDatabase: true);
        await ImportAsync(factory, LiteralSearchDocument);
        using var client = factory.CreateClient();

        using var canonical = await client.GetAsync($"/figure/{PercentFigureId}");
        Assert.Equal(HttpStatusCode.OK, canonical.StatusCode);
        Assert.Equal("text/html", canonical.Content.Headers.ContentType?.MediaType);

        foreach (var unknown in new[]
        {
            PercentFigureId.ToUpperInvariant(),
            AbsentFigureId,
            "not-a-uuid",
            "3a3a3a3a333343338333333333333331",
            "{3a3a3a3a-3333-4333-8333-333333333331}",
            $" {PercentFigureId}",
        })
        {
            using var response = await client.GetAsync(
                $"/figure/{Uri.EscapeDataString(unknown)}");

            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
    }

    /// <summary>
    /// Encoded and back-slash aliases of the image route are rejected on the original
    /// request target, before routing, while canonical targets still answer.
    /// </summary>
    [Fact(DisplayName = "Contract.Catalog.AliasesAreRejectedBeforeRouting")]
    public async Task ImageRequestRejectsPathTraversal()
    {
        await using var factory = new ContractWebApplicationFactory();

        // Each alias is routed at the path it would normalize to, so a connector that
        // stopped inspecting the original target would answer 200 or 401 instead of 404.
        foreach (var (rawTarget, routedPath) in new[]
        {
            ("/images/../healthz", "/healthz"),
            ("/images/..\\healthz", "/healthz"),
            ("/images/..%2Fhealthz", "/healthz"),
            ("/images/..%5Chealthz", "/healthz"),
            ("/images/%2e%2e/healthz", "/healthz"),
            ("/images/..%252Fhealthz", "/healthz"),
            ("/perftest\\catalog", "/perftest/catalog"),
            ("/perftest%2Fcatalog", "/perftest/catalog"),
            ("/perftest%5Ccatalog", "/perftest/catalog"),
        })
        {
            Assert.Equal(
                StatusCodes.Status404NotFound,
                await RawStatusAsync(factory, rawTarget, routedPath));
        }

        Assert.Equal(
            StatusCodes.Status200OK,
            await RawStatusAsync(factory, "/healthz", "/healthz"));
        Assert.Equal(
            StatusCodes.Status401Unauthorized,
            await RawStatusAsync(factory, "/perftest/catalog", "/perftest/catalog"));

        using var client = factory.CreateClient();
        using var canonical = await client.GetAsync($"/images/{CanonicalImageKey}");
        Assert.Equal(HttpStatusCode.OK, canonical.StatusCode);
        Assert.Equal("image/png", canonical.Content.Headers.ContentType?.MediaType);
    }

    /// <summary>
    /// Replaying the seed import - exactly what a second start performs - inserts
    /// nothing and skips every record, leaving the catalog counts unchanged.
    /// </summary>
    [Fact(DisplayName = "Contract.Catalog.StartupImportIsIdempotent")]
    public async Task StartupImportIsIdempotentAcrossTwoStarts()
    {
        await using var factory = new ContractWebApplicationFactory(
            inMemoryCatalogDatabase: true);

        var first = await ImportSeedAsync(factory);
        Assert.Equal(new ImportResult(198, 0, 198), first);
        Assert.Equal(198, await CountFiguresAsync(factory));
        Assert.Equal(20, await CountCategoriesAsync(factory));

        var second = await ImportSeedAsync(factory);
        Assert.Equal(new ImportResult(0, 198, 198), second);
        Assert.Equal(198, await CountFiguresAsync(factory));
        Assert.Equal(20, await CountCategoriesAsync(factory));

        var supplemental = await ImportAsync(factory, LiteralSearchDocument);
        Assert.Equal(new ImportResult(4, 0, 4), supplemental);
        Assert.Equal(202, await CountFiguresAsync(factory));
        Assert.Equal(22, await CountCategoriesAsync(factory));

        Assert.Equal(
            new ImportResult(0, 4, 4),
            await ImportAsync(factory, LiteralSearchDocument));
        Assert.Equal(202, await CountFiguresAsync(factory));
        Assert.Equal(22, await CountCategoriesAsync(factory));
    }

    private static async Task<ImportResult> ImportAsync(
        ContractWebApplicationFactory factory,
        string document)
    {
        using var scope = factory.Services.CreateScope();
        var importer = scope.ServiceProvider.GetRequiredService<ImportService>();
        await using var stream = new MemoryStream(Encoding.UTF8.GetBytes(document));
        return await importer.ImportAsync(stream, CancellationToken.None);
    }

    /// <summary>
    /// Replays exactly what a start performs: the configured seed through ImportService.
    /// </summary>
    private static async Task<ImportResult> ImportSeedAsync(
        ContractWebApplicationFactory factory)
    {
        using var scope = factory.Services.CreateScope();
        var importer = scope.ServiceProvider.GetRequiredService<ImportService>();
        await using var stream = File.OpenRead(
            Path.Combine(
                ContractWebApplicationFactory.RepositoryRoot(),
                "data",
                "catalog.json"));
        return await importer.ImportAsync(stream, CancellationToken.None);
    }

    private static async Task<int> CountFiguresAsync(
        ContractWebApplicationFactory factory)
    {
        using var scope = factory.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
        return await database.Figures.CountAsync();
    }

    private static async Task<int> CountCategoriesAsync(
        ContractWebApplicationFactory factory)
    {
        using var scope = factory.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
        return await database.Categories.CountAsync();
    }

    private static async Task<string[]> FigureIdsAsync(
        HttpClient client,
        string? category = null,
        string? search = null)
    {
        var parameters = new List<string>();
        if (search is not null)
        {
            parameters.Add($"search={Uri.EscapeDataString(search)}");
        }

        if (category is not null)
        {
            parameters.Add($"category={Uri.EscapeDataString(category)}");
        }

        using var response = await client.GetAsync(
            parameters.Count == 0 ? "/" : $"/?{string.Join("&", parameters)}");
        response.EnsureSuccessStatusCode();
        var html = await response.Content.ReadAsStringAsync();
        return FigureId()
            .Matches(html)
            .Select(match => match.Groups["id"].Value)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(id => id, StringComparer.Ordinal)
            .ToArray();
    }

    /// <summary>
    /// Issues a request whose original target keeps aliases that a client would normalize.
    /// </summary>
    private static async Task<int> RawStatusAsync(
        ContractWebApplicationFactory factory,
        string rawTarget,
        string routedPath)
    {
        var context = await factory.Server.SendAsync(
            context =>
            {
                context.Request.Method = HttpMethods.Get;
                context.Request.Path = routedPath;
                context.Features.Get<IHttpRequestFeature>()!.RawTarget = rawTarget;
            });
        return context.Response.StatusCode;
    }

    [GeneratedRegex("data-figure-id=\"(?<id>[^\"]+)\"", RegexOptions.CultureInvariant)]
    private static partial Regex FigureId();
}
