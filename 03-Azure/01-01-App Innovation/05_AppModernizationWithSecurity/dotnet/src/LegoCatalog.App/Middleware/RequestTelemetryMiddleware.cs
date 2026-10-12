using Microsoft.AspNetCore.Routing;

namespace LegoCatalog.App.Middleware;

/// <summary>
/// Emits one structured completion log for every application HTTP request.
/// </summary>
public sealed class RequestTelemetryMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestTelemetryMiddleware> _logger;

    public RequestTelemetryMiddleware(
        RequestDelegate next,
        ILogger<RequestTelemetryMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch
        {
            if (!context.Response.HasStarted)
            {
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            }

            throw;
        }
        finally
        {
            var route = (context.GetEndpoint() as RouteEndpoint)
                ?.RoutePattern
                .RawText
                ?? context.Request.Path.Value
                ?? "/";
            using (_logger.BeginScope(
                new Dictionary<string, object>
                {
                    ["http.request.method"] = context.Request.Method,
                    ["http.route"] = route,
                    ["http.response.status_code"] = context.Response.StatusCode,
                }))
            {
                _logger.LogInformation("http.server.request");
            }
        }
    }
}
