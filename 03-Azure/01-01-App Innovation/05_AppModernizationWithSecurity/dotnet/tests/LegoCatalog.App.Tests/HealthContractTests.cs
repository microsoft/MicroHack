using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using LegoCatalog.App.Services;

namespace LegoCatalog.App.Tests;

public sealed class HealthContractTests
{
    [Fact(DisplayName = "Contract.Health.LivenessSurvivesDatabaseOutage")]
    public async Task LivenessSurvivesDatabaseOutage()
    {
        await using var factory = new ContractWebApplicationFactory(
            databaseReady: false);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/healthz");
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("healthy", payload.GetProperty("status").GetString());
    }

    [Fact(DisplayName = "Contract.Health.ReadinessFailsDuringDatabaseOutage")]
    public async Task ReadinessFailsDuringDatabaseOutage()
    {
        await using var factory = new ContractWebApplicationFactory(
            databaseReady: false);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/readyz");
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("not_ready", payload.GetProperty("status").GetString());
        Assert.Equal(
            "not_ready",
            payload.GetProperty("checks").GetProperty("database").GetString());
        Assert.Equal(
            "ready",
            payload.GetProperty("checks").GetProperty("import").GetString());
    }

    [Fact(DisplayName = "Contract.Health.ReadinessReportsImportFailure")]
    public async Task ReadinessReportsImportFailure()
    {
        await using var factory = new ContractWebApplicationFactory(
            startupStatus: StartupStatus.Failed);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/readyz");
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(
            "ready",
            payload.GetProperty("checks").GetProperty("database").GetString());
        Assert.Equal(
            "failed",
            payload.GetProperty("checks").GetProperty("import").GetString());
    }
}
