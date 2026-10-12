package com.microsoft.microhack.catalog.service;

import java.util.UUID;

/** Carries one fully validated import item into the transactional publication phase. */
public record ValidatedCatalogItem(
        UUID productId,
        String name,
        String description,
        String category,
        String categorySlug,
        String filename) {
}
