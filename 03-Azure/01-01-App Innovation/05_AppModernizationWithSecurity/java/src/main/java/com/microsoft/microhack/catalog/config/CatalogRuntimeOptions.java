package com.microsoft.microhack.catalog.config;

import java.nio.file.Path;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Objects;
import org.springframework.core.env.Environment;

/** Holds the validated and bounded runtime configuration. */
public record CatalogRuntimeOptions(
        String databaseHost,
        String databaseName,
        Path imagesPath,
        Path seedPath,
        boolean startupImportEnabled,
        String performanceApiKey,
        int performanceWorkFactor,
        String serviceVersion,
        String deploymentEnvironment,
        String revisionName,
        String serviceInstanceId,
        String otlpEndpoint) {

    public static final String SERVICE_NAME = "mh-catalog-java";
    public static final String SERVICE_NAMESPACE = "app-innovation";
    public static final int DEFAULT_WORK_FACTOR = 10;
    public static final int MAXIMUM_WORK_FACTOR = 25;

    /** Reads and validates every application and resource variable. */
    public static CatalogRuntimeOptions from(Environment environment, String instanceId) {
        String databaseHost = require(environment, "CATALOG_DATABASE_HOST");
        parsePort(environment.getProperty("CATALOG_DATABASE_PORT"));
        String databaseName = require(environment, "CATALOG_DATABASE_NAME");
        require(environment, "CATALOG_DATABASE_USERNAME");
        require(environment, "CATALOG_DATABASE_PASSWORD");

        String deploymentEnvironment = require(environment, "DEPLOYMENT_ENVIRONMENT");
        if (!"lab".equals(deploymentEnvironment)) {
            throw new IllegalStateException("DEPLOYMENT_ENVIRONMENT must be 'lab'.");
        }
        String apiKey = require(environment, "PERFTEST_API_KEY");
        if (apiKey.length() > 1024) {
            throw new IllegalStateException("PERFTEST_API_KEY must not exceed 1024 characters.");
        }
        return new CatalogRuntimeOptions(
                databaseHost,
                databaseName,
                Path.of(require(environment, "CATALOG_IMAGES_PATH")).toAbsolutePath().normalize(),
                Path.of(require(environment, "CATALOG_SEED_PATH")).toAbsolutePath().normalize(),
                parseBoolean(
                        environment.getProperty("CATALOG_STARTUP_IMPORT_ENABLED"),
                        "CATALOG_STARTUP_IMPORT_ENABLED"),
                apiKey,
                parseWorkFactor(environment.getProperty("PERFTEST_WORK_FACTOR")),
                bounded(require(environment, "OTEL_SERVICE_VERSION"), "OTEL_SERVICE_VERSION", 128),
                deploymentEnvironment,
                bounded(require(environment, "CONTAINER_APP_REVISION"), "CONTAINER_APP_REVISION", 128),
                bounded(Objects.requireNonNull(instanceId), "service.instance.id", 128),
                parseEndpoint(require(environment, "OTEL_EXPORTER_OTLP_ENDPOINT")));
    }

    /** Parses the bounded performance work factor. */
    public static int parseWorkFactor(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return DEFAULT_WORK_FACTOR;
        }
        try {
            int value = Integer.parseInt(rawValue);
            if (value < 1 || value > MAXIMUM_WORK_FACTOR) {
                throw new IllegalStateException(workFactorMessage());
            }
            return value;
        } catch (NumberFormatException exception) {
            throw new IllegalStateException(workFactorMessage(), exception);
        }
    }

    private static String workFactorMessage() {
        return "PERFTEST_WORK_FACTOR must be an integer from 1 through "
                + MAXIMUM_WORK_FACTOR + ".";
    }

    private static boolean parseBoolean(String rawValue, String name) {
        if (rawValue == null || rawValue.isBlank()) {
            return true;
        }
        if ("true".equalsIgnoreCase(rawValue)) {
            return true;
        }
        if ("false".equalsIgnoreCase(rawValue)) {
            return false;
        }
        throw new IllegalStateException(name + " must be true or false.");
    }

    private static void parsePort(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return;
        }
        try {
            int port = Integer.parseInt(rawValue);
            if (port < 1 || port > 65535) {
                throw new IllegalStateException("CATALOG_DATABASE_PORT must be from 1 through 65535.");
            }
        } catch (NumberFormatException exception) {
            throw new IllegalStateException(
                    "CATALOG_DATABASE_PORT must be from 1 through 65535.", exception);
        }
    }

    private static String require(Environment environment, String name) {
        return bounded(environment.getProperty(name), name, 4096);
    }

    private static String bounded(String value, String name, int maximumLength) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(name + " is required.");
        }
        String trimmed = value.trim();
        if (trimmed.length() > maximumLength) {
            throw new IllegalStateException(name + " exceeds its maximum length.");
        }
        return trimmed;
    }

    private static String parseEndpoint(String value) {
        try {
            URI uri = new URI(value);
            if (!uri.isAbsolute()
                    || (!"http".equalsIgnoreCase(uri.getScheme())
                    && !"https".equalsIgnoreCase(uri.getScheme()))) {
                throw new IllegalStateException(
                        "OTEL_EXPORTER_OTLP_ENDPOINT must be an absolute HTTP(S) URI.");
            }
            return uri.toString();
        } catch (URISyntaxException exception) {
            throw new IllegalStateException(
                    "OTEL_EXPORTER_OTLP_ENDPOINT must be an absolute HTTP(S) URI.", exception);
        }
    }
}
