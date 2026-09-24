package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.domain.Figure;
import com.microsoft.microhack.catalog.model.CatalogFigureDto;
import com.microsoft.microhack.catalog.repository.CategoryRepository;
import com.microsoft.microhack.catalog.repository.FigureRepository;
import io.opentelemetry.api.trace.Span;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/** Provides ordered catalog queries and stable DTO mapping. */
@Service
public class CatalogService {

    private static final Logger LOGGER = LoggerFactory.getLogger(CatalogService.class);
    private final FigureRepository figures;
    private final CategoryRepository categories;
    private final CatalogTelemetry telemetry;

    public CatalogService(
            FigureRepository figures,
            CategoryRepository categories,
            CatalogTelemetry telemetry) {
        this.figures = figures;
        this.categories = categories;
        this.telemetry = telemetry;
    }

    /** Queries only the name field and exact category slug/display name. */
    public List<CatalogFigureDto> list(String search, String category) {
        String normalizedSearch = blankToNull(search);
        String normalizedCategory = blankToNull(category);
        String filter = normalizedSearch != null && normalizedCategory != null
                ? "search+category"
                : normalizedSearch != null ? "search" : normalizedCategory != null ? "category" : "all";
        long started = System.nanoTime();
        Span span = telemetry.startSpan("catalog.query");
        span.setAttribute("catalog.query.filter", filter);
        span.setAttribute("catalog.query.result_count", 0);
        try (var scope = span.makeCurrent()) {
            long databaseStarted = System.nanoTime();
            Span databaseSpan = telemetry.startDatabaseSpan("select");
            List<CatalogFigureDto> result;
            try (var databaseScope = databaseSpan.makeCurrent()) {
                result = query(normalizedSearch, normalizedCategory)
                        .stream()
                        .map(CatalogService::toDto)
                        .toList();
            } catch (RuntimeException exception) {
                telemetry.databaseFailure(LOGGER, databaseSpan, "select", exception);
                throw exception;
            } finally {
                telemetry.recordDatabase(
                        (System.nanoTime() - databaseStarted) / 1_000_000_000.0,
                        "select");
                databaseSpan.end();
            }
            span.setAttribute("catalog.query.result_count", result.size());
            return result;
        } catch (RuntimeException exception) {
            CatalogTelemetry.failure(LOGGER, "catalog.query.failed", span, exception, Map.of(
                    "catalog.query.filter", filter));
            throw exception;
        } finally {
            double seconds = (System.nanoTime() - started) / 1_000_000_000.0;
            telemetry.recordQuery(seconds, filter);
            span.end();
        }
    }

    public Optional<CatalogFigureDto> find(UUID id) {
        return figures.findById(id).map(CatalogService::toDto);
    }

    public List<com.microsoft.microhack.catalog.domain.Category> categories() {
        return categories.findAllByOrderByNameAsc();
    }

    public static CatalogFigureDto toDto(Figure figure) {
        return new CatalogFigureDto(
                figure.getId().toString(),
                figure.getName(),
                figure.getDescription(),
                figure.getCategory().getName(),
                figure.getCategory().getSlug(),
                figure.getImageFile());
    }

    private List<Figure> query(String search, String category) {
        String escapedSearch = search == null ? null : escapeLikeLiteral(search);
        if (search != null && category != null) {
            return figures.findBySearchAndCategory(escapedSearch, category);
        }
        if (search != null) {
            return figures.findByNameLiteral(escapedSearch);
        }
        if (category != null) {
            return figures.findByCategory(category);
        }
        return figures.findAllByOrderByIdAsc();
    }

    /** Escapes every character with SQL LIKE semantics using the repository's {@code !} escape. */
    static String escapeLikeLiteral(String value) {
        return value.replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
