using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using LegoCatalog.App.Configuration;

namespace LegoCatalog.App.Tests;

public sealed class PerformanceContractTests
{
    [Fact(DisplayName = "Contract.Performance.DatabaseFailureIsControlled")]
    public async Task DatabaseFailureIsControlled()
    {
        await using var factory = new ContractWebApplicationFactory(
            performanceBehavior: PerformanceBehavior.DependencyUnavailable);
        using var client = factory.CreateClient();
        using var request = AuthorizedRequest();

        using var response = await client.SendAsync(request);
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(
            "catalog_dependency_unavailable",
            payload.GetProperty("error").GetString());
        Assert.DoesNotContain(
            "stack",
            await response.Content.ReadAsStringAsync(),
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact(DisplayName = "Contract.Performance.TimeoutIsControlled")]
    public async Task TimeoutIsControlled()
    {
        await using var factory = new ContractWebApplicationFactory(
            performanceBehavior: PerformanceBehavior.Timeout);
        using var client = factory.CreateClient();
        using var request = AuthorizedRequest();

        using var response = await client.SendAsync(request);
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal(HttpStatusCode.GatewayTimeout, response.StatusCode);
        Assert.Equal(
            "catalog_query_timeout",
            payload.GetProperty("error").GetString());
    }

    [Fact(DisplayName = "Contract.Performance.MissingKeyReturnsUnauthorized")]
    public async Task MissingKeyReturnsUnauthorized()
    {
        await using var factory = new ContractWebApplicationFactory();
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/perftest/catalog");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact(DisplayName = "Contract.Performance.InvalidKeyReturnsUnauthorized")]
    public async Task InvalidKeyReturnsUnauthorized()
    {
        await using var factory = new ContractWebApplicationFactory();
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            "/perftest/catalog");
        request.Headers.Add("x-api-key", "invalid");

        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact(DisplayName = "Contract.Performance.MissingWorkFactorUsesDefault")]
    public void MissingWorkFactorUsesDefault()
    {
        Assert.Equal(
            CatalogRuntimeOptions.DefaultWorkFactor,
            CatalogRuntimeOptions.ParseWorkFactor(null));
    }

    [Fact(DisplayName = "Contract.Performance.BoundsAreAccepted")]
    public void BoundsAreAccepted()
    {
        Assert.Equal(1, CatalogRuntimeOptions.ParseWorkFactor("1"));
        Assert.Equal(25, CatalogRuntimeOptions.ParseWorkFactor("25"));
    }

    [Fact(DisplayName = "Contract.Performance.InvalidWorkFactorsFailStartup")]
    public void InvalidWorkFactorsFailStartup()
    {
        foreach (var value in new[] { "0", "-1", "26", "not-an-integer" })
        {
            Assert.Throws<InvalidOperationException>(
                () => CatalogRuntimeOptions.ParseWorkFactor(value));
        }
    }

    private static HttpRequestMessage AuthorizedRequest()
    {
        var request = new HttpRequestMessage(
            HttpMethod.Get,
            "/perftest/catalog");
        request.Headers.Add("x-api-key", "test-api-key");
        return request;
    }
}
