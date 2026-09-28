package com.microsoft.microhack.catalog.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Represents one untrusted record from a catalog import document. */
public record CatalogImportItem(
        @NotBlank String productId,
        @NotBlank @Size(max = 80) String name,
        @NotBlank @Size(max = 1200) String description,
        @NotBlank @Size(max = 60) String category,
        @NotBlank String filename,
        @NotBlank String imagePrompt) {
}
