package com.microsoft.microhack.catalog.model;

import java.util.List;

/** Reports bounded database work and the resulting canonical catalog. */
public record PerformanceResult(
        int iterations,
        int itemCount,
        double elapsedMilliseconds,
        List<CatalogFigureDto> items) {
}
