package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.StandardEnvironment;

/**
 * Guards the observability identity contract. DEPLOYMENT_ENVIRONMENT,
 * OTEL_SERVICE_VERSION and CONTAINER_APP_REVISION must fail startup when absent
 * instead of falling back to a silent default, because the workshop telemetry
 * challenge asks participants which environment and which revision emitted a
 * span. A misconfigured deployment that starts anyway and reports a placeholder
 * version or revision breaks that lesson without any visible symptom.
 */
class RuntimeIdentityConfigurationTest {

    @Test
    void missingDeploymentEnvironmentFailsStartup() {
        assertMissingVariableFailsStartup("DEPLOYMENT_ENVIRONMENT");
    }

    @Test
    void missingServiceVersionFailsStartup() {
        assertMissingVariableFailsStartup("OTEL_SERVICE_VERSION");
    }

    @Test
    void missingRevisionNameFailsStartup() {
        assertMissingVariableFailsStartup("CONTAINER_APP_REVISION");
    }

    @Test
    void deploymentEnvironmentRejectsValuesOtherThanLab() {
        Map<String, Object> values = defaults();
        values.put("DEPLOYMENT_ENVIRONMENT", "production");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> CatalogRuntimeOptions.from(environment(values), "test"));

        assertThat(exception)
                .hasMessageContaining("DEPLOYMENT_ENVIRONMENT")
                .hasMessageContaining("lab");
    }

    /**
     * Positive control. Proves the baseline map below is complete, so a failure
     * above is caused by the removed variable and not by unrelated drift.
     */
    @Test
    void suppliedRuntimeIdentityVariablesReachTheOptions() {
        CatalogRuntimeOptions options = CatalogRuntimeOptions.from(
                environment(defaults()),
                "test-instance");

        assertThat(options.deploymentEnvironment()).isEqualTo("lab");
        assertThat(options.serviceVersion()).isEqualTo("contract-test");
        assertThat(options.revisionName()).isEqualTo("contract-test");
    }

    private static void assertMissingVariableFailsStartup(String variableName) {
        Map<String, Object> values = defaults();
        assertThat(values.remove(variableName))
                .as("%s is not part of the baseline configuration", variableName)
                .isNotNull();

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> CatalogRuntimeOptions.from(environment(values), "test"));

        // The variable name has to appear so a facilitator can tell which value is
        // missing. "is required" pins the failure to absence rather than to a
        // downstream value check: defaulting DEPLOYMENT_ENVIRONMENT to something
        // other than "lab" would still name the variable, but would report a value
        // violation instead of a missing configuration entry.
        assertThat(exception)
                .as("%s must fail startup when absent", variableName)
                .hasMessageContaining(variableName)
                .hasMessageContaining("is required");
    }

    private static StandardEnvironment environment(Map<String, Object> values) {
        StandardEnvironment environment = new StandardEnvironment();
        // Isolation strategy: StandardEnvironment resolves from the real process
        // environment and the JVM system properties by default. Both are
        // process-global and shared with every other test in the surefire JVM, so a
        // developer or CI agent that exports OTEL_SERVICE_VERSION would satisfy the
        // "absent" case and silently stop this regression test from biting.
        // Dropping those two sources leaves the supplied map as the only input.
        // Nothing here writes to shared state either, so these tests cannot
        // interfere with any other test regardless of execution order.
        environment.getPropertySources()
                .remove(StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME);
        environment.getPropertySources()
                .remove(StandardEnvironment.SYSTEM_PROPERTIES_PROPERTY_SOURCE_NAME);
        environment.getPropertySources()
                .addFirst(new MapPropertySource("runtime-identity", values));
        return environment;
    }

    private static Map<String, Object> defaults() {
        Map<String, Object> values = new HashMap<>();
        values.put("CATALOG_DATABASE_HOST", "localhost");
        values.put("CATALOG_DATABASE_PORT", "5432");
        values.put("CATALOG_DATABASE_NAME", "catalog");
        values.put("CATALOG_DATABASE_USERNAME", "catalog");
        values.put("CATALOG_DATABASE_PASSWORD", "local-password");
        values.put("CATALOG_IMAGES_PATH", ".");
        values.put("CATALOG_SEED_PATH", "catalog.json");
        values.put("CATALOG_STARTUP_IMPORT_ENABLED", "false");
        values.put("PERFTEST_API_KEY", "test-api-key");
        values.put("DEPLOYMENT_ENVIRONMENT", "lab");
        values.put("OTEL_SERVICE_VERSION", "contract-test");
        values.put("CONTAINER_APP_REVISION", "contract-test");
        values.put("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317");
        return values;
    }
}
