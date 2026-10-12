package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import ch.qos.logback.classic.joran.JoranConfigurator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.microhack.catalog.config.CatalogResourceIdentity;
import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.repository.CategoryRepository;
import com.microsoft.microhack.catalog.repository.FigureRepository;
import com.microsoft.microhack.catalog.service.CatalogDocumentParser;
import com.microsoft.microhack.catalog.service.CatalogImportService;
import com.microsoft.microhack.catalog.service.CatalogImportTransaction;
import com.microsoft.microhack.catalog.service.CatalogImportTransactionWorker;
import com.microsoft.microhack.catalog.service.CatalogImportValidationException;
import com.microsoft.microhack.catalog.service.CatalogQueryTimeoutException;
import com.microsoft.microhack.catalog.service.CatalogService;
import com.microsoft.microhack.catalog.service.CatalogTelemetry;
import com.microsoft.microhack.catalog.service.PerformanceCatalogService;
import com.microsoft.microhack.catalog.web.RequestTelemetryFilter;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributesBuilder;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.logs.SdkLoggerProvider;
import io.opentelemetry.sdk.logs.data.LogRecordData;
import io.opentelemetry.sdk.logs.export.SimpleLogRecordProcessor;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.data.MetricData;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.testing.exporter.InMemoryLogRecordExporter;
import io.opentelemetry.sdk.testing.exporter.InMemoryMetricReader;
import io.opentelemetry.sdk.testing.exporter.InMemorySpanExporter;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor;
import jakarta.validation.Validation;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.web.servlet.HandlerMapping;

/** Proves frozen traces, metrics, and bridged logs with real SDK exporters. */
class TelemetryContractTest {

    private InMemorySpanExporter spans;
    private InMemoryMetricReader metrics;
    private InMemoryLogRecordExporter logs;
    private SdkTracerProvider tracerProvider;
    private SdkMeterProvider meterProvider;
    private SdkLoggerProvider loggerProvider;
    private CatalogTelemetry telemetry;
    private CatalogRuntimeOptions options;

    @BeforeEach
    void configureSdkAndProductionLogbackBridge() throws Exception {
        options = new CatalogRuntimeOptions(
                "database.internal",
                "catalog",
                Path.of("images"),
                Path.of("catalog.json"),
                true,
                "test-key",
                3,
                "1.0-test",
                "lab",
                "revision-test",
                "instance-test",
                "http://localhost:4317");
        AttributesBuilder attributes = Attributes.builder();
        CatalogResourceIdentity.attributes(options).forEach(attributes::put);
        Resource resource = Resource.create(attributes.build());

        spans = InMemorySpanExporter.create();
        metrics = InMemoryMetricReader.create();
        logs = InMemoryLogRecordExporter.create();
        tracerProvider = SdkTracerProvider.builder()
                .setResource(resource)
                .addSpanProcessor(SimpleSpanProcessor.create(spans))
                .build();
        meterProvider = SdkMeterProvider.builder()
                .setResource(resource)
                .registerMetricReader(metrics)
                .build();
        loggerProvider = SdkLoggerProvider.builder()
                .setResource(resource)
                .addLogRecordProcessor(SimpleLogRecordProcessor.create(logs))
                .build();
        OpenTelemetrySdk sdk = OpenTelemetrySdk.builder()
                .setTracerProvider(tracerProvider)
                .setMeterProvider(meterProvider)
                .setLoggerProvider(loggerProvider)
                .build();
        configureProductionLogback(sdk);
        telemetry = new CatalogTelemetry(sdk, options);
    }

    @AfterEach
    void closeSdk() {
        loggerProvider.close();
        meterProvider.close();
        tracerProvider.close();
        logs.close();
        spans.close();
    }

    @Test
    @DisplayName("Contract.Telemetry.FinalResponseStatus")
    void httpSignalAndFullResourceIdentityReachLogExporter() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest(
                "GET", "/figure/44444444-4444-4444-8444-444444444444");
        request.setServerName("catalog.test");
        MockHttpServletResponse response = new MockHttpServletResponse();
        new RequestTelemetryFilter(telemetry).doFilter(
                request,
                response,
                (ignoredRequest, ignoredResponse) -> {
                    request.setAttribute(
                            HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE,
                            "/figure/{id}");
                    response.setStatus(404);
                });

        var span = spans.getFinishedSpanItems().get(0);
        assertThat(span.getKind()).isEqualTo(SpanKind.SERVER);
        assertThat(span.getAttributes().get(AttributeKey.stringKey("http.route")))
                .isEqualTo("/figure/{id}");
        assertThat(span.getAttributes().get(AttributeKey.longKey("http.response.status_code")))
                .isEqualTo(404L);
        var httpPoint = metric(CatalogTelemetry.HTTP_DURATION_METRIC)
                .getHistogramData()
                .getPoints()
                .iterator()
                .next();
        assertThat(httpPoint.getAttributes().get(AttributeKey.stringKey("http.route")))
                .isEqualTo("/figure/{id}");
        assertThat(httpPoint.getAttributes().get(AttributeKey.longKey("http.response.status_code")))
                .isEqualTo(404L);
        LogRecordData record = log("http.server.request");
        assertAttributes(record, Map.of(
                "http.request.method", "GET",
                "http.route", "/figure/{id}",
                "http.response.status_code", "404"));
        assertFullResource(record);

        logs.reset();
        MockHttpServletResponse failedResponse = new MockHttpServletResponse();
        assertThatThrownBy(() -> new RequestTelemetryFilter(telemetry).doFilter(
                        request,
                        failedResponse,
                        (ignoredRequest, ignoredResponse) -> {
                            failedResponse.setStatus(418);
                            failedResponse.flushBuffer();
                            throw new jakarta.servlet.ServletException("request failed");
                        }))
                .isInstanceOf(jakarta.servlet.ServletException.class);
        assertThat(failedResponse.getStatus()).isEqualTo(418);
        assertAttributes(log("exception"), Map.of(
                "exception.type", jakarta.servlet.ServletException.class.getName(),
                "exception.message", "request failed"));
        var failureSpan = spans.getFinishedSpanItems().get(1);
        assertThat(failureSpan.getAttributes().get(AttributeKey.stringKey("http.route")))
                .isEqualTo("/figure/{id}");
        assertThat(failureSpan.getAttributes().get(
                AttributeKey.longKey("http.response.status_code")))
                .isEqualTo(418L);
        assertThat(metric(CatalogTelemetry.HTTP_DURATION_METRIC)
                        .getHistogramData()
                        .getPoints())
                .anySatisfy(point -> {
                    assertThat(point.getAttributes().get(
                            AttributeKey.stringKey("http.route")))
                            .isEqualTo("/figure/{id}");
                    assertThat(point.getAttributes().get(
                            AttributeKey.longKey("http.response.status_code")))
                            .isEqualTo(418L);
                });
        assertAttributes(log("http.server.request"), Map.of(
                "http.request.method", "GET",
                "http.route", "/figure/{id}",
                "http.response.status_code", "418"));

        logs.reset();
        MockHttpServletResponse uncommittedResponse = new MockHttpServletResponse();
        assertThatThrownBy(() -> new RequestTelemetryFilter(telemetry).doFilter(
                        request,
                        uncommittedResponse,
                        (ignoredRequest, ignoredResponse) -> {
                            throw new jakarta.servlet.ServletException("uncommitted failure");
                        }))
                .isInstanceOf(jakarta.servlet.ServletException.class);
        assertThat(uncommittedResponse.getStatus()).isEqualTo(500);
        var uncommittedSpan = spans.getFinishedSpanItems().get(2);
        assertThat(uncommittedSpan.getAttributes().get(
                AttributeKey.longKey("http.response.status_code")))
                .isEqualTo(500L);
        assertThat(metric(CatalogTelemetry.HTTP_DURATION_METRIC)
                        .getHistogramData()
                        .getPoints())
                .anySatisfy(point -> assertThat(point.getAttributes().get(
                               AttributeKey.longKey("http.response.status_code")))
                        .isEqualTo(500L));
        assertAttributes(log("http.server.request"), Map.of(
                "http.request.method", "GET",
                "http.route", "/figure/{id}",
                "http.response.status_code", "500"));
    }

    @Test
    @DisplayName("Contract.Telemetry.RejectedDocumentIncrementsOnce")
    void rejectedDocumentIncrementsOnce() {
        FigureRepository figures = mock(FigureRepository.class);
        CategoryRepository categories = mock(CategoryRepository.class);
        CatalogImportService service = importService(figures, categories);

        assertThatThrownBy(() -> service.importDocument(
                        stream(validItem().replace(
                               "\"category\":\"Telemetry Figures\"",
                               "\"category\":\"!!!\""))))
                .isInstanceOf(CatalogImportValidationException.class);

        assertLatestImportRejectedOne(1);
        assertThat(rejectedMetricCount()).isEqualTo(1);
        verifyNoInteractions(figures, categories);
    }

    @Test
    void importCompletedFailedAndExceptionSignalsReachLogExporter() {
        FigureRepository figures = mock(FigureRepository.class);
        CategoryRepository categories = mock(CategoryRepository.class);
        CatalogImportService service = importService(figures, categories);

        assertThatThrownBy(() -> service.importDocument(stream("null")))
                .isInstanceOf(CatalogImportValidationException.class);
        assertLatestImportRejectedOne(1);
        assertThatThrownBy(() -> service.importDocument(
                        stream(validItem().replace("Telemetry Figure", "x"))))
                .isInstanceOf(CatalogImportValidationException.class);
        assertLatestImportRejectedOne(2);
        assertThatThrownBy(() -> service.importDocument(
                        stream("[" + validItemObject() + "," + validItemObject() + "]")))
                .isInstanceOf(CatalogImportValidationException.class);
        assertLatestImportRejectedOne(3);
        assertThatThrownBy(() -> service.importDocument(
                        stream(validItem().replace("Telemetry Figure", "\u00a0\u00a0\u00a0"))))
                .isInstanceOf(CatalogImportValidationException.class);
        assertLatestImportRejectedOne(4);
        verifyNoInteractions(figures, categories);

        CatalogImportTransaction conflictingTransaction = input -> {
            throw new DataIntegrityViolationException("transaction conflict");
        };
        assertThatThrownBy(() -> new CatalogImportService(conflictingTransaction, telemetry)
                        .importDocument(stream(validItem())))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertLatestImportRejectedOne(5);
        assertThat(rejectedMetricCount()).isEqualTo(5);

        var span = importSpans().get(0);
        assertThat(span.getEvents()).anyMatch(event -> event.getName().equals("exception"));
        assertThat(metricNames()).contains(CatalogTelemetry.IMPORT_RECORDS_METRIC);
        assertAttributes(log("catalog.import.failed"), Map.of(
                "catalog.import.rejected", "1",
                "exception.type", CatalogImportValidationException.class.getName()));
        assertExceptionRecord(CatalogImportValidationException.class);

        logs.reset();
        when(figures.existsById(org.mockito.ArgumentMatchers.any())).thenReturn(true);
        service.importDocument(stream(validItem()));
        assertAttributes(log("catalog.import.completed"), Map.of(
                "catalog.import.inserted", "0",
                "catalog.import.skipped", "1"));
    }

    @Test
    void metricUnitsAndSecondValuesAreFrozen() {
        telemetry.recordHttp(0.11, "GET", "/figure/{id}", 200);
        telemetry.recordDatabase(0.22, "select");
        telemetry.recordQuery(0.33, "search");
        telemetry.recordPerformance(0.44, 3);
        telemetry.recordImport(0, 0, 1);

        assertHistogram(CatalogTelemetry.HTTP_DURATION_METRIC, CatalogTelemetry.HTTP_DURATION_UNIT, 0.11);
        assertHistogram(
                CatalogTelemetry.DATABASE_DURATION_METRIC,
                CatalogTelemetry.DATABASE_DURATION_UNIT,
                0.22);
        assertHistogram(CatalogTelemetry.QUERY_DURATION_METRIC, CatalogTelemetry.QUERY_DURATION_UNIT, 0.33);
        assertHistogram(
                CatalogTelemetry.PERFORMANCE_DURATION_METRIC,
                CatalogTelemetry.PERFORMANCE_DURATION_UNIT,
                0.44);
        assertThat(metric(CatalogTelemetry.IMPORT_RECORDS_METRIC).getUnit())
                .isEqualTo(CatalogTelemetry.IMPORT_RECORDS_UNIT);
        assertThat(rejectedMetricCount()).isEqualTo(1);
    }

    @Test
    void databaseAndQueryFailuresExportEveryFrozenLogAttribute() {
        FigureRepository figures = mock(FigureRepository.class);
        CategoryRepository categories = mock(CategoryRepository.class);
        when(figures.findAllByOrderByIdAsc())
                .thenThrow(new DataAccessResourceFailureException("database unavailable"));

        assertThatThrownBy(() -> new CatalogService(figures, categories, telemetry)
                        .list(null, null))
                .isInstanceOf(DataAccessResourceFailureException.class);

        Map<String, io.opentelemetry.sdk.trace.data.SpanData> exported =
                spans.getFinishedSpanItems().stream().collect(java.util.stream.Collectors.toMap(
                        item -> item.getName(), item -> item));
        assertThat(exported.get("db.client").getKind()).isEqualTo(SpanKind.CLIENT);
        assertThat(exported.get("catalog.query").getAttributes().get(
                AttributeKey.stringKey("catalog.query.filter")))
                .isEqualTo("all");
        assertAttributes(log("catalog.database.failed"), Map.of(
                "db.system.name", "postgresql",
                "db.operation.name", "select",
                "exception.type", DataAccessResourceFailureException.class.getName()));
        assertAttributes(log("catalog.query.failed"), Map.of(
                "catalog.query.filter", "all",
                "exception.type", DataAccessResourceFailureException.class.getName()));
        assertThat(logs("exception")).hasSize(2).allSatisfy(record -> {
            assertAttributes(record, Map.of(
                    "exception.type", DataAccessResourceFailureException.class.getName(),
                    "exception.message", "database unavailable"));
            assertFullResource(record);
        });
        assertThat(metricNames()).contains(
                CatalogTelemetry.DATABASE_DURATION_METRIC,
                CatalogTelemetry.QUERY_DURATION_METRIC);
    }

    @Test
    void performanceCompletedFailedAndExceptionSignalsReachLogExporter() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        CatalogService catalog = mock(CatalogService.class);
        when(jdbc.queryForObject(
                        org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.eq(Long.class)))
                .thenReturn(1L);
        when(catalog.list(null, null)).thenReturn(List.of());

        new PerformanceCatalogService(jdbc, catalog, options, telemetry).execute();
        assertAttributes(log("catalog.performance.completed"), Map.of(
                "catalog.performance.work_factor", "3",
                "catalog.performance.item_count", "0"));

        logs.reset();
        when(jdbc.queryForObject(
                        org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.eq(Long.class)))
                .thenThrow(new QueryTimeoutException("bounded work timed out"));
        assertThatThrownBy(() ->
                        new PerformanceCatalogService(jdbc, catalog, options, telemetry).execute())
                .isInstanceOf(CatalogQueryTimeoutException.class);

        assertAttributes(log("catalog.database.failed"), Map.of(
                "db.system.name", "postgresql",
                "db.operation.name", "execute",
                "exception.type", QueryTimeoutException.class.getName()));
        assertAttributes(log("catalog.performance.failed"), Map.of(
                "catalog.performance.work_factor", "3",
                "exception.type", QueryTimeoutException.class.getName()));
        assertThat(logs("exception")).hasSize(2).allSatisfy(record -> {
            assertAttributes(record, Map.of(
                    "exception.type", QueryTimeoutException.class.getName(),
                    "exception.message", "bounded work timed out"));
            assertFullResource(record);
        });
        assertThat(metricNames()).contains(CatalogTelemetry.DATABASE_DURATION_METRIC);
    }

    private void configureProductionLogback(OpenTelemetrySdk sdk) throws Exception {
        LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
        context.reset();
        JoranConfigurator configurator = new JoranConfigurator();
        configurator.setContext(context);
        try (InputStream configuration = getClass().getClassLoader()
                .getResourceAsStream("logback-spring.xml")) {
            assertThat(configuration).isNotNull();
            configurator.doConfigure(configuration);
        }
        Logger root = context.getLogger(Logger.ROOT_LOGGER_NAME);
        assertThat(root.getAppender("OPENTELEMETRY"))
                .isInstanceOf(OpenTelemetryAppender.class);
        OpenTelemetryAppender.install(sdk);
    }

    private CatalogImportService importService(
            FigureRepository figures,
            CategoryRepository categories) {
        return new CatalogImportService(
                new CatalogImportTransactionWorker(
                        new CatalogDocumentParser(
                                new ObjectMapper(),
                                Validation.buildDefaultValidatorFactory().getValidator()),
                        figures,
                        categories),
                telemetry);
    }

    private LogRecordData log(String event) {
        return logs(event).stream().findFirst().orElseThrow();
    }

    private List<LogRecordData> logs(String event) {
        return logs.getFinishedLogRecordItems().stream()
                .filter(record -> event.equals(record.getBodyValue().asString()))
                .toList();
    }

    private void assertExceptionRecord(Class<? extends Exception> type) {
        assertAttributes(log("exception"), Map.of(
                "exception.type", type.getName(),
                "exception.message", "catalog document root must be one JSON array"));
    }

    private void assertAttributes(LogRecordData record, Map<String, String> expected) {
        expected.forEach((name, value) ->
                assertThat(record.getAttributes().get(AttributeKey.stringKey(name)))
                        .as(name)
                        .isEqualTo(value));
        assertFullResource(record);
    }

    private void assertFullResource(LogRecordData record) {
        CatalogResourceIdentity.attributes(options).forEach((name, value) ->
                assertThat(record.getResource().getAttribute(AttributeKey.stringKey(name)))
                        .as(name)
                        .isEqualTo(value));
    }

    private List<String> metricNames() {
        return metrics.collectAllMetrics().stream().map(MetricData::getName).toList();
    }

    private MetricData metric(String name) {
        return metrics.collectAllMetrics().stream()
                .filter(metric -> name.equals(metric.getName()))
                .findFirst()
                .orElseThrow();
    }

    private void assertHistogram(String name, String unit, double expectedSum) {
        MetricData metric = metric(name);
        assertThat(metric.getUnit()).isEqualTo(unit);
        assertThat(metric.getHistogramData().getPoints())
                .singleElement()
                .satisfies(point -> assertThat(point.getSum()).isEqualTo(expectedSum));
    }

    private List<io.opentelemetry.sdk.trace.data.SpanData> importSpans() {
        return spans.getFinishedSpanItems().stream()
                .filter(item -> item.getName().equals("catalog.import"))
                .toList();
    }

    private void assertLatestImportRejectedOne(int expectedSpanCount) {
        assertThat(importSpans()).hasSize(expectedSpanCount);
        assertThat(importSpans().get(expectedSpanCount - 1)
                        .getAttributes()
                        .get(AttributeKey.longKey("catalog.import.rejected")))
                .isEqualTo(1L);
    }

    private long rejectedMetricCount() {
        return metric(CatalogTelemetry.IMPORT_RECORDS_METRIC)
                .getLongSumData()
                .getPoints()
                .stream()
                .filter(point -> "rejected".equals(point.getAttributes().get(
                        AttributeKey.stringKey("catalog.import.outcome"))))
                .mapToLong(point -> point.getValue())
                .sum();
    }

    private static ByteArrayInputStream stream(String document) {
        return new ByteArrayInputStream(document.getBytes(StandardCharsets.UTF_8));
    }

    private static String validItem() {
        return "[" + validItemObject() + "]";
    }

    private static String validItemObject() {
        return """
                {
                  "productId":"44444444-4444-4444-8444-444444444444",
                  "name":"Telemetry Figure",
                  "description":"A complete figure used to validate telemetry completion logs.",
                  "category":"Telemetry Figures",
                  "filename":"44444444-4444-4444-8444-444444444444.png",
                  "imagePrompt":"Photorealistic construction-toy figure on a clean studio background."
                }
                """;
    }
}
