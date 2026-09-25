package com.microsoft.microhack.catalog.model;

/** Exposes the stable path-neutral catalog DTO. */
public record CatalogFigureDto(
        String productId,
        String name,
        String description,
        String category,
        String categorySlug,
        String filename) {
}
