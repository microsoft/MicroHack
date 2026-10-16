package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.model.CatalogFigureDto;
import com.microsoft.microhack.catalog.model.PerformanceResult;
import io.opentelemetry.api.trace.Span;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/** Executes deterministic bounded PostgreSQL-safe work for load exercises. */
@Service
public class PerformanceCatalogService {

    private static final Logger LOGGER = LoggerFactory.getLogger(PerformanceCatalogService.class);
    private static final String BOUNDED_WORK = """
            SELECT COALESCE(sum((hashtextextended(
                f.id::text || f.name || work.n::text, 0) & 2147483647)::bigint), 0)
            FROM public.figures AS f
            CROSS JOIN generate_series(1, 16) AS work(n)
            """;
    private final JdbcTemplate jdbc;
    private final CatalogService catalog;
    private final CatalogRuntimeOptions options;
    private final CatalogTelemetry telemetry;

    public PerformanceCatalogService(
            JdbcTemplate jdbc,
            CatalogService catalog,
            CatalogRuntimeOptions options,
            CatalogTelemetry telemetry) {
        this.jdbc = jdbc;
        this.catalog = catalog;
        this.options = options;
        this.telemetry = telemetry;
        this.jdbc.setQueryTimeout(10);
    }

    /** Performs the configured work factor and returns the canonical ordered DTOs. */
    public PerformanceResult execute() {
        long started = System.nanoTime();
        Span span = telemetry.startSpan("catalog.performance");
        span.setAttribute("catalog.performance.work_factor", options.performanceWorkFactor());
        span.setAttribute("catalog.performance.item_count", 0);
        try (var scope = span.makeCurrent()) {
            long databaseStarted = System.nanoTime();
            Span databaseSpan = telemetry.startDatabaseSpan("execute");
            try (var databaseScope = databaseSpan.makeCurrent()) {
                for (int iteration = 0; iteration < options.performanceWorkFactor(); iteration++) {
                    jdbc.queryForObject(BOUNDED_WORK, Long.class);
                }
            } catch (RuntimeException exception) {
                telemetry.databaseFailure(LOGGER, databaseSpan, "execute", exception);
                throw exception;
            } finally {
                telemetry.recordDatabase(
                        (System.nanoTime() - databaseStarted) / 1_000_000_000.0,
                        "execute");
                databaseSpan.end();
            }
            List<CatalogFigureDto> items = catalog.list(null, null);
            double seconds = (System.nanoTime() - started) / 1_000_000_000.0;
            telemetry.recordPerformance(seconds, options.performanceWorkFactor());
            span.setAttribute("catalog.performance.item_count", items.size());
            CatalogTelemetry.log(LOGGER, "catalog.performance.completed", Map.of(
                    "catalog.performance.work_factor", options.performanceWorkFactor(),
                    "catalog.performance.item_count", items.size()));
            return new PerformanceResult(
                    options.performanceWorkFactor(),
                    items.size(),
                    seconds * 1000.0,
                    items);
        } catch (QueryTimeoutException exception) {
            CatalogTelemetry.failure(LOGGER, "catalog.performance.failed", span, exception, Map.of(
                    "catalog.performance.work_factor", options.performanceWorkFactor()));
            throw new CatalogQueryTimeoutException(exception);
        } catch (DataAccessException exception) {
            CatalogTelemetry.failure(LOGGER, "catalog.performance.failed", span, exception, Map.of(
                    "catalog.performance.work_factor", options.performanceWorkFactor()));
            throw new CatalogDependencyUnavailableException(exception);
        } finally {
            span.end();
        }
    }
}
