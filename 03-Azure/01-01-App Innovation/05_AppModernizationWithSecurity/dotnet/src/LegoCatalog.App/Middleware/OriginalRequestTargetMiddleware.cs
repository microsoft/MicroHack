using Microsoft.AspNetCore.Http.Features;
using System.Text.RegularExpressions;

namespace LegoCatalog.App.Middleware;

/// <summary>
/// Rejects noncanonical original request paths before routing can normalize aliases.
/// </summary>
public sealed partial class OriginalRequestTargetMiddleware
{
    private readonly RequestDelegate _next;

    public OriginalRequestTargetMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        var rawTarget = context.Features.Get<IHttpRequestFeature>()?.RawTarget
            ?? context.Request.Path.Value
            ?? "/";
        var rawPath = rawTarget.Split('?', 2)[0];
        if (IsUnsafe(rawPath))
        {
            context.Response.StatusCode = StatusCodes.Status404NotFound;
            return;
        }

        await _next(context);
    }

    private static bool IsUnsafe(string rawPath)
    {
        var candidate = rawPath;
        for (var depth = 0; depth < 3; depth++)
        {
            if (candidate.Contains('\\')
                || EncodedSeparator().IsMatch(candidate)
                || candidate.Split('/', StringSplitOptions.RemoveEmptyEntries)
                    .Any(segment => segment is "." or ".."))
            {
                return true;
            }

            var decoded = Uri.UnescapeDataString(candidate);
            if (string.Equals(decoded, candidate, StringComparison.Ordinal))
            {
                return false;
            }

            candidate = decoded;
        }

        return false;
    }

    [GeneratedRegex("%(?:2f|5c)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex EncodedSeparator();
}
