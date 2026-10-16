using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace LegoCatalog.App.Services;

/// <summary>
/// Implements the frozen category-slug-v1 normalization algorithm.
/// </summary>
public static partial class CategorySlug
{
    /// <summary>
    /// Normalizes a display name into its stable ASCII slug.
    /// </summary>
    public static string Normalize(string value)
    {
        ArgumentNullException.ThrowIfNull(value);
        var normalized = value.Trim().Normalize(NormalizationForm.FormKD).ToLowerInvariant();
        var builder = new StringBuilder(normalized.Length);
        foreach (var rune in normalized.EnumerateRunes())
        {
            var category = Rune.GetUnicodeCategory(rune);
            if (category is UnicodeCategory.NonSpacingMark
                or UnicodeCategory.SpacingCombiningMark
                or UnicodeCategory.EnclosingMark)
            {
                continue;
            }

            if (rune.Value is '\'' or '\u2019')
            {
                continue;
            }

            builder.Append(rune.ToString());
        }

        return NonAsciiAlphanumericRun()
            .Replace(builder.ToString(), "-")
            .Trim('-');
    }

    [GeneratedRegex("[^a-z0-9]+", RegexOptions.CultureInvariant)]
    private static partial Regex NonAsciiAlphanumericRun();
}
