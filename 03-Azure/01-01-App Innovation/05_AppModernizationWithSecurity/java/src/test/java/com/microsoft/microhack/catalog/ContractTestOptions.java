package com.microsoft.microhack.catalog;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import java.nio.file.Path;

/** Builds explicit non-secret options for isolated unit tests. */
final class ContractTestOptions {

    private ContractTestOptions() {
    }

    static CatalogRuntimeOptions options() {
        return new CatalogRuntimeOptions(
                "localhost",
                "catalog",
                Path.of("."),
                Path.of("catalog.json"),
                true,
                "test-api-key",
                10,
                "test-version",
                "lab",
                "test-revision",
                "test-instance",
                "http://localhost:4317");
    }
}
