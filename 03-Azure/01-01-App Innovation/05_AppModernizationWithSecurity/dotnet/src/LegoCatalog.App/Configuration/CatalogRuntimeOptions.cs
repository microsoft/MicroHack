using Microsoft.Data.SqlClient;

namespace LegoCatalog.App.Configuration;

/// <summary>
/// Holds validated process configuration shared by catalog services.
/// </summary>
public sealed record CatalogRuntimeOptions(
    string SqlConnectionString,
    string ImagesPath,
    string SeedPath,
    bool StartupImportEnabled,
    string PerformanceApiKey,
    int PerformanceWorkFactor,
    string ServiceVersion,
    string DeploymentEnvironment,
    string RevisionName)
{
    public const int DefaultWorkFactor = 10;
    public const int MaximumWorkFactor = 25;

    /// <summary>
    /// Reads and validates the frozen environment/configuration contract.
    /// </summary>
    public static CatalogRuntimeOptions Load(
        IConfiguration configuration,
        string contentRootPath)
    {
        var host = Required(
            configuration,
            "CATALOG_DATABASE_HOST",
            "Catalog:Database:Host");
        var database = Required(
            configuration,
            "CATALOG_DATABASE_NAME",
            "Catalog:Database:Name");
        var username = Optional(
            configuration,
            "CATALOG_DATABASE_USERNAME",
            "Catalog:Database:Username");
        var password = Optional(
            configuration,
            "CATALOG_DATABASE_PASSWORD",
            "Catalog:Database:Password");
        if (string.IsNullOrWhiteSpace(username) != string.IsNullOrWhiteSpace(password))
        {
            throw new InvalidOperationException(
                "CATALOG_DATABASE_USERNAME and CATALOG_DATABASE_PASSWORD must be configured together.");
        }

        var port = ParseOptionalPort(configuration["CATALOG_DATABASE_PORT"]);
        var isManagedHost = host.EndsWith(
            ".database.windows.net",
            StringComparison.OrdinalIgnoreCase);
        var connection = new SqlConnectionStringBuilder
        {
            DataSource = port is null ? host : $"{host},{port}",
            InitialCatalog = database,
            Encrypt = isManagedHost,
            TrustServerCertificate = !isManagedHost,
            ConnectTimeout = 5,
            ApplicationName = "mh-catalog-dotnet",
            MultipleActiveResultSets = false,
            PersistSecurityInfo = false,
        };
        if (username is null)
        {
            connection.IntegratedSecurity = true;
        }
        else
        {
            connection.UserID = username;
            connection.Password = password;
        }

        var imagesPath = ResolvePath(
            Required(configuration, "CATALOG_IMAGES_PATH", "Catalog:ImagesPath"),
            contentRootPath);
        var seedPath = ResolvePath(
            Required(configuration, "CATALOG_SEED_PATH", "Catalog:SeedPath"),
            contentRootPath);
        var startupImportEnabled = ParseBoolean(
            configuration["CATALOG_STARTUP_IMPORT_ENABLED"]
                ?? configuration["Catalog:StartupImportEnabled"],
            defaultValue: true,
            "CATALOG_STARTUP_IMPORT_ENABLED");
        var apiKey = Required(configuration, "PERFTEST_API_KEY");
        var workFactor = ParseWorkFactor(configuration["PERFTEST_WORK_FACTOR"]);
        var deploymentEnvironment = Required(configuration, "DEPLOYMENT_ENVIRONMENT");
        if (!string.Equals(deploymentEnvironment, "lab", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "DEPLOYMENT_ENVIRONMENT must be 'lab' for the workshop contract.");
        }

        return new CatalogRuntimeOptions(
            connection.ConnectionString,
            imagesPath,
            seedPath,
            startupImportEnabled,
            apiKey,
            workFactor,
            Required(configuration, "OTEL_SERVICE_VERSION"),
            deploymentEnvironment,
            Required(configuration, "CONTAINER_APP_REVISION"));
    }

    /// <summary>
    /// Parses the bounded performance work factor.
    /// </summary>
    public static int ParseWorkFactor(string? rawValue)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return DefaultWorkFactor;
        }

        if (!int.TryParse(rawValue, out var parsed)
            || parsed < 1
            || parsed > MaximumWorkFactor)
        {
            throw new InvalidOperationException(
                $"PERFTEST_WORK_FACTOR must be an integer from 1 through {MaximumWorkFactor}.");
        }

        return parsed;
    }

    private static int? ParseOptionalPort(string? rawValue)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return null;
        }

        if (!int.TryParse(rawValue, out var port) || port is < 1 or > 65535)
        {
            throw new InvalidOperationException(
                "CATALOG_DATABASE_PORT must be an integer from 1 through 65535.");
        }

        return port;
    }

    private static bool ParseBoolean(
        string? rawValue,
        bool defaultValue,
        string name)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return defaultValue;
        }

        if (!bool.TryParse(rawValue, out var parsed))
        {
            throw new InvalidOperationException($"{name} must be true or false.");
        }

        return parsed;
    }

    private static string ResolvePath(string path, string contentRootPath)
    {
        return Path.GetFullPath(
            Path.IsPathRooted(path) ? path : Path.Combine(contentRootPath, path));
    }

    private static string Required(
        IConfiguration configuration,
        string key,
        string? fallbackKey = null)
    {
        return Optional(configuration, key, fallbackKey)
            ?? throw new InvalidOperationException($"{key} is required.");
    }

    private static string? Optional(
        IConfiguration configuration,
        string key,
        string? fallbackKey = null)
    {
        var value = configuration[key]
            ?? (fallbackKey is null ? null : configuration[fallbackKey]);
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
