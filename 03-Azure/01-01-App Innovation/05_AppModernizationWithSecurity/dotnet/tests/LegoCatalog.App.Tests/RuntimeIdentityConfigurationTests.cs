using LegoCatalog.App.Configuration;
using Microsoft.Extensions.Configuration;

namespace LegoCatalog.App.Tests;

/// <summary>
/// Guards the observability identity contract. DEPLOYMENT_ENVIRONMENT,
/// OTEL_SERVICE_VERSION and CONTAINER_APP_REVISION must fail startup when absent
/// instead of falling back to a silent default, because the workshop telemetry
/// challenge asks participants which environment and which revision emitted a
/// span. A misconfigured deployment that starts anyway and reports "1.0.0" or
/// "local" breaks that lesson without any visible symptom.
/// </summary>
public sealed class RuntimeIdentityConfigurationTests
{
    // Isolation strategy: every test here binds an injected in-memory IConfiguration
    // and never reads or mutates process environment variables.
    //
    // Why not Environment.SetEnvironmentVariable with a try/finally restore?
    // ContractWebApplicationFactory sets these exact names process-wide in its
    // constructor, environment variables are process-global, and xUnit runs test
    // classes in parallel by default (no xunit.runner.json, no
    // CollectionBehavior attribute in this assembly). Clearing
    // OTEL_SERVICE_VERSION here would race with a factory-backed test class
    // reading it, in either direction. An injected configuration source shares no
    // state at all, so no collection fixture and no DisableTestParallelization is
    // needed and the tests cannot flake.

    [Theory]
    [InlineData("DEPLOYMENT_ENVIRONMENT")]
    [InlineData("OTEL_SERVICE_VERSION")]
    [InlineData("CONTAINER_APP_REVISION")]
    public void MissingRuntimeIdentityVariableFailsFast(string variableName)
    {
        var configuration = ConfigurationWithout(variableName);

        var exception = Assert.Throws<InvalidOperationException>(
            () => CatalogRuntimeOptions.Load(
                configuration,
                Directory.GetCurrentDirectory()));

        // The variable name has to appear so a facilitator can tell which value is
        // missing. "is required" pins the failure to absence rather than to a
        // downstream value check: reverting DEPLOYMENT_ENVIRONMENT to a default of
        // something other than "lab" would still name the variable, but would
        // report a value violation instead of a missing configuration entry.
        Assert.Contains(variableName, exception.Message, StringComparison.Ordinal);
        Assert.Contains("is required", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void DeploymentEnvironmentRejectsValuesOtherThanLab()
    {
        var configuration = Configuration(
            new Dictionary<string, string?>
            {
                ["DEPLOYMENT_ENVIRONMENT"] = "production",
            });

        var exception = Assert.Throws<InvalidOperationException>(
            () => CatalogRuntimeOptions.Load(
                configuration,
                Directory.GetCurrentDirectory()));

        Assert.Contains("DEPLOYMENT_ENVIRONMENT", exception.Message, StringComparison.Ordinal);
        Assert.Contains("lab", exception.Message, StringComparison.Ordinal);
    }

    /// <summary>
    /// Positive control. Proves the baseline configuration below is complete, so a
    /// failure above is caused by the removed variable and not by unrelated drift.
    /// </summary>
    [Fact]
    public void SuppliedRuntimeIdentityVariablesReachTheOptions()
    {
        var options = CatalogRuntimeOptions.Load(
            Configuration(new Dictionary<string, string?>()),
            Directory.GetCurrentDirectory());

        Assert.Equal("lab", options.DeploymentEnvironment);
        Assert.Equal("contract-test", options.ServiceVersion);
        Assert.Equal("contract-test", options.RevisionName);
    }

    /// <summary>
    /// Drops the key outright rather than mapping it to null, so the binder sees a
    /// genuinely absent entry instead of a present-but-empty one.
    /// </summary>
    private static IConfiguration ConfigurationWithout(string variableName)
    {
        var values = BaselineValues();
        Assert.True(
            values.Remove(variableName),
            $"{variableName} is not part of the baseline configuration.");
        return Build(values);
    }

    private static IConfiguration Configuration(
        IDictionary<string, string?> overrides)
    {
        var values = BaselineValues();
        foreach (var (key, value) in overrides)
        {
            values[key] = value;
        }

        return Build(values);
    }

    private static Dictionary<string, string?> BaselineValues()
    {
        return new Dictionary<string, string?>
        {
            ["CATALOG_DATABASE_HOST"] = @".\SQLEXPRESS",
            ["CATALOG_DATABASE_NAME"] = "LegoCatalog",
            ["CATALOG_IMAGES_PATH"] = ".",
            ["CATALOG_SEED_PATH"] = "catalog.json",
            ["CATALOG_STARTUP_IMPORT_ENABLED"] = "false",
            ["PERFTEST_API_KEY"] = "test-api-key",
            ["DEPLOYMENT_ENVIRONMENT"] = "lab",
            ["OTEL_SERVICE_VERSION"] = "contract-test",
            ["CONTAINER_APP_REVISION"] = "contract-test",
        };
    }

    private static IConfiguration Build(Dictionary<string, string?> values)
    {
        // AddInMemoryCollection only. No AddEnvironmentVariables, so a variable
        // exported into the test process cannot leak in and mask an absent key.
        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }
}
