using LegoCatalog.App.Middleware;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;

namespace LegoCatalog.App.Tests;

public sealed class OriginalRequestTargetMiddlewareTests
{
    [Theory]
    [InlineData("/images/../healthz")]
    [InlineData("/images\\..\\healthz")]
    [InlineData("/images/%2e%2e%2fhealthz")]
    [InlineData("/images/%2e%2e%5chealthz")]
    [InlineData("/images/%252e%252e%252fhealthz")]
    [InlineData("/perftest\\catalog")]
    [InlineData("/perftest%5ccatalog")]
    public async Task UnsafeOriginalTargetsReturnNotFound(string rawTarget)
    {
        var nextCalled = false;
        var middleware = new OriginalRequestTargetMiddleware(
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });
        var context = ContextWithRawTarget(rawTarget);

        await middleware.InvokeAsync(context);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status404NotFound, context.Response.StatusCode);
    }

    [Fact]
    public async Task CanonicalOriginalTargetContinues()
    {
        var nextCalled = false;
        var middleware = new OriginalRequestTargetMiddleware(
            context =>
            {
                nextCalled = true;
                context.Response.StatusCode = StatusCodes.Status200OK;
                return Task.CompletedTask;
            });
        var context = ContextWithRawTarget(
            "/figure/10000000-0000-4000-8000-000000000001");

        await middleware.InvokeAsync(context);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
    }

    private static DefaultHttpContext ContextWithRawTarget(string rawTarget)
    {
        var context = new DefaultHttpContext();
        context.Features.Set<IHttpRequestFeature>(
            new HttpRequestFeature
            {
                Path = rawTarget,
                RawTarget = rawTarget,
            });
        return context;
    }
}
