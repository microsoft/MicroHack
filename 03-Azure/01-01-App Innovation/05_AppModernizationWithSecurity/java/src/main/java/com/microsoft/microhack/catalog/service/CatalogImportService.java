package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.model.ImportResult;
import io.opentelemetry.api.trace.Span;
import java.io.InputStream;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/** Records import telemetry around the complete transactional commit boundary. */
@Service
public class CatalogImportService {

    private static final Logger LOGGER = LoggerFactory.getLogger(CatalogImportService.class);
    private final CatalogImportTransaction transaction;
    private final CatalogTelemetry telemetry;

    public CatalogImportService(
            CatalogImportTransaction transaction,
            CatalogTelemetry telemetry) {
        this.transaction = transaction;
        this.telemetry = telemetry;
    }

    /** Starts telemetry before parsing and reports success only after the transaction commits. */
    public ImportResult importDocument(InputStream input) {
        Span span = telemetry.startSpan("catalog.import");
        try (var scope = span.makeCurrent()) {
            ImportResult result = transaction.execute(input);
            span.setAttribute("catalog.import.inserted", result.inserted());
            span.setAttribute("catalog.import.skipped", result.skipped());
            span.setAttribute("catalog.import.rejected", 0);
            telemetry.recordImport(result.inserted(), result.skipped(), 0);
            CatalogTelemetry.log(LOGGER, "catalog.import.completed", Map.of(
                    "catalog.import.inserted", result.inserted(),
                    "catalog.import.skipped", result.skipped()));
            return result;
        } catch (RuntimeException exception) {
            int rejected = 1;
            span.setAttribute("catalog.import.inserted", 0);
            span.setAttribute("catalog.import.skipped", 0);
            span.setAttribute("catalog.import.rejected", rejected);
            telemetry.recordImport(0, 0, rejected);
            CatalogTelemetry.failure(LOGGER, "catalog.import.failed", span, exception, Map.of(
                    "catalog.import.inserted", 0,
                    "catalog.import.skipped", 0,
                    "catalog.import.rejected", rejected));
            throw exception;
        } finally {
            span.end();
        }
    }
}
