package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.repository.CategoryRepository;
import com.microsoft.microhack.catalog.repository.FigureRepository;
import com.microsoft.microhack.catalog.service.CatalogDocumentParser;
import com.microsoft.microhack.catalog.service.CatalogImportService;
import com.microsoft.microhack.catalog.service.CatalogImportTransactionWorker;
import com.microsoft.microhack.catalog.service.CatalogTelemetry;
import com.microsoft.microhack.catalog.service.StartupImportRunner;
import com.microsoft.microhack.catalog.service.StartupState;
import com.microsoft.microhack.catalog.web.HealthController;
import io.opentelemetry.api.OpenTelemetry;
import jakarta.validation.Validation;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;

/** Emits the exact native JUnit health evidence names required by the handoff validator. */
class RuntimeHealthContractTest {

    @TempDir
    Path temporaryDirectory;

    @Test
    @DisplayName("Contract.Health.LivenessSurvivesDatabaseOutage")
    void livenessSurvivesDatabaseOutage() {
        HealthController controller = new HealthController(failingDatabase(), readyImport());

        assertThat(controller.liveness()).isEqualTo(Map.of("status", "healthy"));
    }

    @Test
    @DisplayName("Contract.Health.ReadinessFailsDuringDatabaseOutage")
    void readinessFailsDuringDatabaseOutage() {
        HealthController controller = new HealthController(failingDatabase(), readyImport());

        var response = controller.readiness();

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "not_ready",
                "checks", Map.of("database", "not_ready", "import", "ready")));
    }

    @Test
    @DisplayName("Contract.Health.ReadinessReportsImportFailure")
    void readinessReportsImportFailure() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject("SELECT 1", Integer.class)).thenReturn(1);
        StartupState startupState = new StartupState();
        startupState.failed();
        HealthController controller = new HealthController(jdbc, startupState);

        var response = controller.readiness();

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "status", "not_ready",
                "checks", Map.of("database", "ready", "import", "failed")));
    }

    @Test
    void invalidStartupDocumentFailsReadinessWithoutPersistence() throws Exception {
        Path seed = temporaryDirectory.resolve("invalid.json");
        Files.writeString(seed, """
                [{
                  "productId":"33333333-3333-4333-8333-333333333333",
                  "name":"Valid Prefix",
                  "description":"A valid prefix followed by an invalid catalog member.",
                  "category":"Startup Figures",
                  "filename":"33333333-3333-4333-8333-333333333333.png",
                  "imagePrompt":"Photorealistic construction-toy figure on a clean background."
                },null]
                """);
        CatalogRuntimeOptions options = new CatalogRuntimeOptions(
                "database.internal",
                "catalog",
                temporaryDirectory,
                seed,
                true,
                "test-key",
                1,
                "test",
                "lab",
                "test-revision",
                "test-instance",
                "http://localhost:4317");
        FigureRepository figures = mock(FigureRepository.class);
        CategoryRepository categories = mock(CategoryRepository.class);
        CatalogImportService imports = new CatalogImportService(
                new CatalogImportTransactionWorker(
                        new CatalogDocumentParser(
                                new ObjectMapper(),
                                Validation.buildDefaultValidatorFactory().getValidator()),
                        figures,
                        categories),
                new CatalogTelemetry(OpenTelemetry.noop(), options));
        StartupState startupState = new StartupState();

        new StartupImportRunner(options, imports, startupState)
                .run(mock(org.springframework.boot.ApplicationArguments.class));

        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject("SELECT 1", Integer.class)).thenReturn(1);
        assertThat(new HealthController(jdbc, startupState).readiness().getBody())
                .isEqualTo(Map.of(
                        "status", "not_ready",
                        "checks", Map.of("database", "ready", "import", "failed")));
        verifyNoInteractions(figures, categories);
    }

    private static JdbcTemplate failingDatabase() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject("SELECT 1", Integer.class))
                .thenThrow(new DataAccessResourceFailureException("expected outage"));
        return jdbc;
    }

    private static StartupState readyImport() {
        StartupState startupState = new StartupState();
        startupState.ready();
        return startupState;
    }
}
