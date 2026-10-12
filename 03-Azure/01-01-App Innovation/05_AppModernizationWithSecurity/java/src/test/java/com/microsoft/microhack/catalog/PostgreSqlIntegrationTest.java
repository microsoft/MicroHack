package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.microsoft.microhack.catalog.model.ImportResult;
import com.microsoft.microhack.catalog.repository.CategoryRepository;
import com.microsoft.microhack.catalog.repository.FigureRepository;
import com.microsoft.microhack.catalog.service.CatalogImportService;
import com.microsoft.microhack.catalog.service.CatalogImportTransaction;
import com.microsoft.microhack.catalog.service.CatalogImportValidationException;
import com.microsoft.microhack.catalog.service.CatalogService;
import com.microsoft.microhack.catalog.service.CatalogTelemetry;
import com.microsoft.microhack.catalog.service.PerformanceCatalogService;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import io.opentelemetry.api.trace.Span;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/** Exercises Flyway, JPA validation, startup seed, HTTP, and transactional import on PostgreSQL. */
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class PostgreSqlIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse(
                    "postgres:18.6-bookworm@sha256:7d2695c3aa88e792e8b3b233e7e4adb296a20412c6c0ca361e3edaaacfada108")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("catalog")
            .withUsername("catalog")
            .withPassword("integration-password");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    CatalogImportService importService;

    @Autowired
    FigureRepository figures;

    @Autowired
    CategoryRepository categories;

    @Autowired
    PerformanceCatalogService performance;

    @Autowired
    CatalogService catalog;

    @Autowired
    TestRestTemplate http;

    @Autowired
    PlatformTransactionManager transactionManager;

    @LocalServerPort
    int port;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        Path root = ConformanceVectorTest.repositoryRoot();
        registry.add("CATALOG_DATABASE_HOST", POSTGRES::getHost);
        registry.add("CATALOG_DATABASE_PORT", () -> POSTGRES.getMappedPort(5432));
        registry.add("CATALOG_DATABASE_NAME", POSTGRES::getDatabaseName);
        registry.add("CATALOG_DATABASE_USERNAME", POSTGRES::getUsername);
        registry.add("CATALOG_DATABASE_PASSWORD", POSTGRES::getPassword);
        registry.add("CATALOG_DATABASE_SSL_MODE", () -> "disable");
        registry.add("CATALOG_IMAGES_PATH", () -> root.resolve("data/images").toString());
        registry.add("CATALOG_SEED_PATH", () -> root.resolve("data/catalog.json").toString());
        registry.add("CATALOG_STARTUP_IMPORT_ENABLED", () -> "true");
        registry.add("PERFTEST_API_KEY", () -> "integration-api-key");
        registry.add("PERFTEST_WORK_FACTOR", () -> "1");
        registry.add("OTEL_EXPORTER_OTLP_ENDPOINT", () -> "http://localhost:4317");
        registry.add("OTEL_SERVICE_VERSION", () -> "integration");
        registry.add("DEPLOYMENT_ENVIRONMENT", () -> "lab");
        registry.add("CONTAINER_APP_REVISION", () -> "integration");
        registry.add("otel.sdk.disabled", () -> "true");
    }

    @Test
    @Order(1)
    void startupImportAndCatalogHttpAreDeterministic() throws Exception {
        assertThat(figures.count()).isEqualTo(198);
        assertThat(categories.count()).isEqualTo(20);
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/html"))
                .andExpect(content().string(org.hamcrest.Matchers.containsString(
                        "data-figure-id=")));
        mockMvc.perform(get("/readyz"))
                .andExpect(status().isOk())
                .andExpect(content().json("""
                        {"status":"ready","checks":{"database":"ready","import":"ready"}}
                        """));
        String canonicalId = figures.findAllByOrderByIdAsc().get(0).getId().toString();
        mockMvc.perform(get("/figure/{id}", canonicalId))
                .andExpect(status().isOk());
        mockMvc.perform(get("/figure/{id}", canonicalId.toUpperCase(java.util.Locale.ROOT)))
                .andExpect(status().isNotFound());
    }

    @Test
    @Order(2)
    void validImportIsIdempotentAndInvalidDocumentIsAtomic() throws Exception {
        Path fixtures = ConformanceVectorTest.repositoryRoot().resolve("tests/acceptance/fixtures");
        long baselineFigures = figures.count();
        long baselineCategories = categories.count();
        try (InputStream input = Files.newInputStream(fixtures.resolve("catalog.valid.json"))) {
            ImportResult first = importService.importDocument(input);
            assertThat(first).isEqualTo(new ImportResult(2, 0, 2));
        }
        assertThat(figures.count()).isEqualTo(baselineFigures + 2);
        assertThat(categories.count()).isEqualTo(baselineCategories + 1);
        try (InputStream input = Files.newInputStream(fixtures.resolve("catalog.valid.json"))) {
            assertThat(importService.importDocument(input))
                    .isEqualTo(new ImportResult(0, 2, 2));
        }
        long publishedFigures = figures.count();
        long publishedCategories = categories.count();
        for (String fixture : new String[] {
            "catalog.invalid.json",
            "catalog.invalid-empty-slug.json"
        }) {
            try (InputStream input = Files.newInputStream(fixtures.resolve(fixture))) {
                assertThatThrownBy(() -> importService.importDocument(input))
                        .as(fixture)
                        .isInstanceOf(CatalogImportValidationException.class);
            }
            assertThat(figures.count()).isEqualTo(publishedFigures);
            assertThat(categories.count()).isEqualTo(publishedCategories);
        }

        String valid = strictItem("22222222-2222-4222-8222-222222222222");
        for (String invalid : new String[] {
                "null",
                "[null]",
                "[" + valid.replace("\"name\":\"Strict Upload\"", "\"name\":17") + "]",
                "[" + valid + "," + valid + "]",
                "[" + valid + "] []",
                "[" + valid + ",null]"
        }) {
            MockMultipartFile upload = new MockMultipartFile(
                    "catalogFile",
                    "catalog.json",
                    "application/json",
                    invalid.getBytes(StandardCharsets.UTF_8));
            mockMvc.perform(multipart("/import").file(upload))
                    .andExpect(status().isBadRequest());
            assertThat(figures.count()).isEqualTo(publishedFigures);
            assertThat(categories.count()).isEqualTo(publishedCategories);
        }
    }

    @Test
    @Order(3)
    void searchTreatsLikeWildcardsAndEscapeAsLiteralText() {
        importService.importDocument(stream("""
                [
                  {
                    "productId":"33333333-3333-4333-8333-333333333331",
                    "name":"Literal % Figure",
                    "description":"A catalog figure whose name contains a literal percent character.",
                    "category":"Literal Search",
                    "filename":"33333333-3333-4333-8333-333333333331.png",
                    "imagePrompt":"Photorealistic construction-toy figure with a literal percent symbol."
                  },
                  {
                    "productId":"33333333-3333-4333-8333-333333333332",
                    "name":"Literal _ Figure",
                    "description":"A catalog figure whose name contains a literal underscore character.",
                    "category":"Literal Search",
                    "filename":"33333333-3333-4333-8333-333333333332.png",
                    "imagePrompt":"Photorealistic construction-toy figure with a literal underscore symbol."
                  },
                  {
                    "productId":"33333333-3333-4333-8333-333333333333",
                    "name":"Literal ! Figure",
                    "description":"A catalog figure whose name contains the configured LIKE escape character.",
                    "category":"Literal Search",
                    "filename":"33333333-3333-4333-8333-333333333333.png",
                    "imagePrompt":"Photorealistic construction-toy figure with a literal exclamation symbol."
                  }
                ]
                """));

        assertThat(catalog.list("%", null))
                .extracting(item -> item.name())
                .containsExactly("Literal % Figure");
        assertThat(catalog.list("_", "literal-search"))
                .extracting(item -> item.name())
                .containsExactly("Literal _ Figure");
        assertThat(catalog.list("!", "LITERAL SEARCH"))
                .extracting(item -> item.name())
                .containsExactly("Literal ! Figure");
    }

    @Test
    @Order(4)
    void commitPhaseConflictEmitsOneRejectionAndNoCompletion() {
        CatalogImportTransaction commitFailure = input -> new TransactionTemplate(transactionManager)
                .execute(status -> {
                    TransactionSynchronizationManager.registerSynchronization(
                            new TransactionSynchronization() {
                                @Override
                                public void beforeCommit(boolean readOnly) {
                                    throw new DataIntegrityViolationException("commit conflict");
                                }
                            });
                    return new ImportResult(1, 0, 1);
                });
        CatalogTelemetry telemetry = mock(CatalogTelemetry.class);
        when(telemetry.startSpan("catalog.import")).thenReturn(Span.getInvalid());
        CatalogImportService boundary = new CatalogImportService(commitFailure, telemetry);
        Logger logger = (Logger) LoggerFactory.getLogger(CatalogImportService.class);
        ListAppender<ILoggingEvent> events = new ListAppender<>();
        events.start();
        logger.addAppender(events);
        try {
            assertThatThrownBy(() -> boundary.importDocument(stream(strictItem(
                            "55555555-5555-4555-8555-555555555555"))))
                    .isInstanceOf(DataIntegrityViolationException.class)
                    .hasMessage("commit conflict");
        } finally {
            logger.detachAppender(events);
            events.stop();
        }

        verify(telemetry).recordImport(0, 0, 1);
        verify(telemetry, never()).recordImport(anyInt(), anyInt(), eq(0));
        assertThat(events.list)
                .extracting(ILoggingEvent::getFormattedMessage)
                .contains("catalog.import.failed", "exception")
                .doesNotContain("catalog.import.completed");
    }

    @Test
    @Order(5)
    void performanceUsesConfiguredBoundAndReturnsCanonicalCorpus() {
        var result = performance.execute();

        assertThat(result.iterations()).isEqualTo(1);
        assertThat(result.itemCount()).isEqualTo((int) figures.count());
        assertThat(result.items()).hasSize(result.itemCount());
    }

    @Test
    @Order(6)
    void liveConnectorRejectsAliasesBeforeRouteMapping() throws Exception {
        for (String path : new String[] {
                "/images/../healthz",
                "/images/..\\healthz",
                "/images/..%2Fhealthz",
                "/images/..%5Chealthz",
                "/images/%2e%2e/healthz",
                "/images/..%252Fhealthz",
                "/perftest\\catalog",
                "/perftest%2Fcatalog",
                "/perftest%5Ccatalog"
        }) {
            assertThat(rawStatus(path))
                    .as(path)
                    .isEqualTo(404);
        }
        assertThat(rawStatus("/healthz")).isEqualTo(200);
        assertThat(rawStatus("/perftest/catalog")).isEqualTo(401);
    }

    private int rawStatus(String path) throws Exception {
        try (Socket socket = new Socket("127.0.0.1", port);
                OutputStreamWriter writer =
                        new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.US_ASCII);
                BufferedReader reader = new BufferedReader(
                        new InputStreamReader(socket.getInputStream(), StandardCharsets.US_ASCII))) {
            writer.write("GET " + path + " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n");
            writer.flush();
            String statusLine = reader.readLine();
            return Integer.parseInt(statusLine.split(" ")[1]);
        }
    }

    private static String strictItem(String productId) {
        return """
                {"productId":"%s","name":"Strict Upload",
                "description":"A complete strict upload validation figure for the catalog.",
                "category":"Strict Uploads","filename":"%s.png",
                "imagePrompt":"Photorealistic construction-toy figure on a clean studio background."}
                """.formatted(productId, productId);
    }

    private static ByteArrayInputStream stream(String document) {
        return new ByteArrayInputStream(document.getBytes(StandardCharsets.UTF_8));
    }
}
