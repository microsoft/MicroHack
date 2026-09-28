package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.Tracer;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;

/** Owns custom catalog spans, semantic-convention metrics, and structured event logs. */
@Component
public class CatalogTelemetry {

    public static final String INSTRUMENTATION_NAME = "MicroHack.Catalog.Java";
    public static final String SERVICE_NAME = "mh-catalog-java";
    public static final String SERVICE_NAMESPACE = "app-innovation";
    public static final String DEPLOYMENT_ENVIRONMENT_ATTRIBUTE = "deployment.environment";
    public static final String REVISION_ATTRIBUTE = "azure.containerapps.revision.name";
    public static final String DATABASE_DURATION_METRIC = "db.client.operation.duration";
    public static final String DATABASE_DURATION_UNIT = "s";
    public static final String HTTP_DURATION_METRIC = "http.server.request.duration";
    public static final String HTTP_DURATION_UNIT = "s";
    public static final String IMPORT_RECORDS_METRIC = "catalog.import.records";
    public static final String IMPORT_RECORDS_UNIT = "{record}";
    public static final String QUERY_DURATION_METRIC = "catalog.query.duration";
    public static final String QUERY_DURATION_UNIT = "s";
    public static final String PERFORMANCE_DURATION_METRIC = "catalog.performance.duration";
    public static final String PERFORMANCE_DURATION_UNIT = "s";

    private final Tracer tracer;
    private final String databaseHost;
    private final String databaseName;
    private final LongCounter importRecords;
    private final DoubleHistogram httpDuration;
    private final DoubleHistogram databaseDuration;
    private final DoubleHistogram queryDuration;
    private final DoubleHistogram performanceDuration;

    public CatalogTelemetry(OpenTelemetry openTelemetry, CatalogRuntimeOptions options) {
        tracer = openTelemetry.getTracer(INSTRUMENTATION_NAME);
        databaseHost = options.databaseHost();
        databaseName = options.databaseName();
        var meter = openTelemetry.getMeter(INSTRUMENTATION_NAME);
        importRecords = meter.counterBuilder(IMPORT_RECORDS_METRIC)
                .setUnit(IMPORT_RECORDS_UNIT)
                .build();
        httpDuration = meter.histogramBuilder(HTTP_DURATION_METRIC)
                .setUnit(HTTP_DURATION_UNIT)
                .build();
        databaseDuration = meter.histogramBuilder(DATABASE_DURATION_METRIC)
                .setUnit(DATABASE_DURATION_UNIT)
                .build();
        queryDuration = meter.histogramBuilder(QUERY_DURATION_METRIC)
                .setUnit(QUERY_DURATION_UNIT)
                .build();
        performanceDuration = meter.histogramBuilder(PERFORMANCE_DURATION_METRIC)
                .setUnit(PERFORMANCE_DURATION_UNIT)
                .build();
    }

    public Span startSpan(String name) {
        return tracer.spanBuilder(name).setSpanKind(SpanKind.INTERNAL).startSpan();
    }

    public Span startHttpServerSpan() {
        return tracer.spanBuilder("http.server")
                .setSpanKind(SpanKind.SERVER)
                .startSpan();
    }

    /** Starts a database client span with the frozen semantic-convention attributes. */
    public Span startDatabaseSpan(String operation) {
        Span span = tracer.spanBuilder("db.client")
                .setSpanKind(SpanKind.CLIENT)
                .startSpan();
        span.setAttribute("db.system.name", "postgresql");
        span.setAttribute("db.operation.name", operation);
        span.setAttribute("db.namespace", databaseName);
        span.setAttribute("server.address", databaseHost);
        return span;
    }

    public void recordImport(int inserted, int skipped, int rejected) {
        importRecords.add(inserted,
                io.opentelemetry.api.common.Attributes.of(
                        AttributeKey.stringKey("catalog.import.outcome"), "inserted"));
        importRecords.add(skipped,
                io.opentelemetry.api.common.Attributes.of(
                        AttributeKey.stringKey("catalog.import.outcome"), "skipped"));
        importRecords.add(rejected,
                io.opentelemetry.api.common.Attributes.of(
                        AttributeKey.stringKey("catalog.import.outcome"), "rejected"));
    }

    public void recordHttp(double seconds, String method, String route, int statusCode) {
        var attributes = io.opentelemetry.api.common.Attributes.builder()
                .put("http.request.method", method)
                .put("http.response.status_code", statusCode);
        if (route != null) {
            attributes.put("http.route", route);
        }
        httpDuration.record(seconds, attributes.build());
    }

    public void recordDatabase(double seconds, String operation) {
        databaseDuration.record(seconds,
                io.opentelemetry.api.common.Attributes.builder()
                        .put("db.system.name", "postgresql")
                        .put("db.operation.name", operation)
                        .build());
    }

    public void recordQuery(double seconds, String filter) {
        queryDuration.record(seconds,
                io.opentelemetry.api.common.Attributes.of(
                        AttributeKey.stringKey("catalog.query.filter"), filter));
    }

    public void recordPerformance(double seconds, int workFactor) {
        performanceDuration.record(seconds,
                io.opentelemetry.api.common.Attributes.of(
                        AttributeKey.longKey("catalog.performance.work_factor"),
                        (long) workFactor));
    }

    /** Writes a structured event without ever including SQL or secret values. */
    public static void log(Logger logger, String event, java.util.Map<String, ?> fields) {
        fields.forEach((key, value) -> MDC.put(key, String.valueOf(value)));
        try {
            logger.info(event);
        } finally {
            fields.keySet().forEach(MDC::remove);
        }
    }

    /** Records exception evidence on a span and in a structured log. */
    public static void failure(
            Logger logger,
            String event,
            Span span,
            Exception exception,
            Map<String, ?> fields) {
        span.recordException(exception);
        span.setAttribute("exception.type", exception.getClass().getName());
        span.setAttribute("exception.message", exception.getMessage());
        logFailure(logger, event, exception, fields);
    }

    /** Emits a domain failure and the distinct frozen exception log signal. */
    public static void logFailure(
            Logger logger,
            String event,
            Exception exception,
            Map<String, ?> fields) {
        Map<String, Object> evidence = new LinkedHashMap<>(fields);
        evidence.put("exception.type", exception.getClass().getName());
        evidence.put("exception.message", String.valueOf(exception.getMessage()));
        evidence.forEach((key, value) -> MDC.put(key, String.valueOf(value)));
        try {
            logger.error(event);
            logger.error("exception");
        } finally {
            evidence.keySet().forEach(MDC::remove);
        }
    }

    public static void failure(Logger logger, String event, Span span, Exception exception) {
        failure(logger, event, span, exception, Map.of());
    }

    /** Emits only the frozen exception log for failures without a domain event. */
    public static void exception(Logger logger, Exception exception) {
        Map<String, Object> evidence = Map.of(
                "exception.type", exception.getClass().getName(),
                "exception.message", String.valueOf(exception.getMessage()));
        evidence.forEach((key, value) -> MDC.put(key, String.valueOf(value)));
        try {
            logger.error("exception");
        } finally {
            evidence.keySet().forEach(MDC::remove);
        }
    }

    /** Emits database failure evidence without SQL text or credentials. */
    public void databaseFailure(Logger logger, Span span, String operation, Exception exception) {
        failure(logger, "catalog.database.failed", span, exception, Map.of(
                "db.system.name", "postgresql",
                "db.operation.name", operation,
                "db.namespace", databaseName,
                "server.address", databaseHost));
    }
}
