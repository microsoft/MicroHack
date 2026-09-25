using System.Text.Json;
using System.Text.Json.Serialization;

namespace LegoCatalog.App.Services;

/// <summary>
/// Parses and validates a complete catalog document before publication starts.
/// </summary>
public sealed class CatalogDocumentParser
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    /// <summary>
    /// Returns fully validated records or rejects the entire document.
    /// </summary>
    public async Task<IReadOnlyList<ValidatedCatalogItem>> ParseAsync(
        Stream jsonStream,
        CancellationToken cancellationToken)
    {
        List<CatalogInputItem?>? rawItems;
        try
        {
            rawItems = await JsonSerializer.DeserializeAsync<List<CatalogInputItem?>>(
                jsonStream,
                SerializerOptions,
                cancellationToken);
        }
        catch (JsonException exception)
        {
            throw new CatalogImportValidationException(
                "The catalog document is not valid contract JSON.",
                1,
                exception);
        }

        if (rawItems is null || rawItems.Count == 0)
        {
            throw new CatalogImportValidationException(
                "The catalog document must contain at least one record.",
                1);
        }

        var validated = new List<ValidatedCatalogItem>(rawItems.Count);
        var ids = new HashSet<Guid>();
        for (var index = 0; index < rawItems.Count; index++)
        {
            try
            {
                var item = rawItems[index]
                    ?? throw new CatalogImportValidationException(
                        "catalog records must be JSON objects.",
                        1);
                validated.Add(Validate(item, ids));
            }
            catch (CatalogImportValidationException exception)
            {
                throw new CatalogImportValidationException(
                    $"Record {index + 1} is invalid: {exception.Message}",
                    1,
                    exception);
            }
        }

        return validated;
    }

    private static ValidatedCatalogItem Validate(
        CatalogInputItem item,
        ISet<Guid> ids)
    {
        var name = RequireStoredText(item.Name, 3, 80, "name");
        var description = RequireStoredText(
            item.Description,
            20,
            1200,
            "description");
        var category = RequireStoredText(item.Category, 2, 60, "category");
        RequireCodePointText(item.ImagePrompt, 30, 260, "imagePrompt");
        if (item.ProductId is null
            || !Guid.TryParseExact(item.ProductId, "D", out var productId)
            || !string.Equals(
                productId.ToString("D"),
                item.ProductId,
                StringComparison.Ordinal))
        {
            throw new CatalogImportValidationException(
                "productId must be a canonical lowercase UUID.",
                1);
        }

        if (!ids.Add(productId))
        {
            throw new CatalogImportValidationException(
                "productId values must be unique within one document.",
                1);
        }

        var expectedFilename = $"{productId:D}.png";
        if (!string.Equals(
            item.Filename,
            expectedFilename,
            StringComparison.Ordinal))
        {
            throw new CatalogImportValidationException(
                $"filename must equal {expectedFilename}.",
                1);
        }

        var categorySlug = CategorySlug.Normalize(category);
        if (categorySlug.Length == 0)
        {
            throw new CatalogImportValidationException(
                "category must normalize to a non-empty slug.",
                1);
        }
        if (categorySlug.Length > 64)
        {
            throw new CatalogImportValidationException(
                "category must normalize to at most 64 ASCII characters.",
                1);
        }

        return new ValidatedCatalogItem(
            productId,
            name,
            description,
            category,
            categorySlug,
            item.Filename!);
    }

    private static string RequireStoredText(
        string? value,
        int minimumCodePoints,
        int maximumUtf16CodeUnits,
        string field)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new CatalogImportValidationException(
                $"{field} must not be blank.",
                1);
        }

        if (value.EnumerateRunes().Count() < minimumCodePoints)
        {
            throw new CatalogImportValidationException(
                $"{field} must contain at least {minimumCodePoints} Unicode code points.",
                1);
        }

        if (value.Length > maximumUtf16CodeUnits)
        {
            throw new CatalogImportValidationException(
                $"{field} must contain at most {maximumUtf16CodeUnits} UTF-16 code units.",
                1);
        }

        return value;
    }

    private static string RequireCodePointText(
        string? value,
        int minimum,
        int maximum,
        string field)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new CatalogImportValidationException(
                $"{field} must not be blank.",
                1);
        }

        var length = value.EnumerateRunes().Count();
        if (length < minimum || length > maximum)
        {
            throw new CatalogImportValidationException(
                $"{field} must contain from {minimum} through {maximum} Unicode code points.",
                1);
        }

        return value;
    }

    private sealed record CatalogInputItem(
        [property: JsonPropertyName("productId")] string? ProductId,
        [property: JsonPropertyName("name")] string? Name,
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("category")] string? Category,
        [property: JsonPropertyName("filename")] string? Filename,
        [property: JsonPropertyName("imagePrompt")] string? ImagePrompt);
}

public sealed record ValidatedCatalogItem(
    Guid ProductId,
    string Name,
    string Description,
    string Category,
    string CategorySlug,
    string Filename);

/// <summary>
/// Signals whole-document validation failure before publication.
/// </summary>
public sealed class CatalogImportValidationException : Exception
{
    public CatalogImportValidationException(
        string message,
        int rejectedCount,
        Exception? innerException = null)
        : base(message, innerException)
    {
        RejectedCount = rejectedCount;
    }

    public int RejectedCount { get; }
}
