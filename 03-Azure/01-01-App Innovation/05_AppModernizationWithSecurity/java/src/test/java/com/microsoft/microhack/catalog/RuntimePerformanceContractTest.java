package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.service.CatalogDependencyUnavailableException;
import com.microsoft.microhack.catalog.service.CatalogQueryTimeoutException;
import com.microsoft.microhack.catalog.service.PerformanceCatalogService;
import com.microsoft.microhack.catalog.web.PerformanceController;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Emits the exact native JUnit performance evidence names required by the handoff validator. */
class RuntimePerformanceContractTest {

    @Test
    @DisplayName("Contract.Performance.DatabaseFailureIsControlled")
    void databaseFailureIsControlled() {
        PerformanceCatalogService service = mock(PerformanceCatalogService.class);
        when(service.execute()).thenThrow(
                new CatalogDependencyUnavailableException(new RuntimeException("outage")));
        PerformanceController controller = controller(service);

        var response = controller.execute("test-api-key");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "unavailable",
                "error", "catalog_dependency_unavailable"));
        assertThat(response.getBody().toString()).doesNotContainIgnoringCase("stack");
    }

    @Test
    @DisplayName("Contract.Performance.TimeoutIsControlled")
    void timeoutIsControlled() {
        PerformanceCatalogService service = mock(PerformanceCatalogService.class);
        when(service.execute()).thenThrow(
                new CatalogQueryTimeoutException(new RuntimeException("timeout")));
        PerformanceController controller = controller(service);

        var response = controller.execute("test-api-key");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "unavailable",
                "error", "catalog_query_timeout"));
        assertThat(response.getBody().toString()).doesNotContainIgnoringCase("stack");
    }

    @Test
    @DisplayName("Contract.Performance.MissingKeyReturnsUnauthorized")
    void missingKeyReturnsUnauthorized() {
        var response = controller(mock(PerformanceCatalogService.class)).execute(null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("Contract.Performance.InvalidKeyReturnsUnauthorized")
    void invalidKeyReturnsUnauthorized() {
        var response = controller(mock(PerformanceCatalogService.class)).execute("wrong");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    @DisplayName("Contract.Performance.MissingWorkFactorUsesDefault")
    void missingWorkFactorUsesDefault() {
        assertThat(CatalogRuntimeOptions.parseWorkFactor(null)).isEqualTo(10);
        assertThat(CatalogRuntimeOptions.parseWorkFactor(" ")).isEqualTo(10);
    }

    @Test
    @DisplayName("Contract.Performance.BoundsAreAccepted")
    void boundsAreAccepted() {
        assertThat(CatalogRuntimeOptions.parseWorkFactor("1")).isEqualTo(1);
        assertThat(CatalogRuntimeOptions.parseWorkFactor("25")).isEqualTo(25);
    }

    @Test
    @DisplayName("Contract.Performance.InvalidWorkFactorsFailStartup")
    void invalidWorkFactorsFailStartup() {
        for (String value : new String[] {"0", "-1", "26", "not-an-integer"}) {
            assertThatThrownBy(() -> CatalogRuntimeOptions.parseWorkFactor(value))
                    .isInstanceOf(IllegalStateException.class);
        }
    }

    private static PerformanceController controller(PerformanceCatalogService service) {
        return new PerformanceController(service, ContractTestOptions.options());
    }
}
