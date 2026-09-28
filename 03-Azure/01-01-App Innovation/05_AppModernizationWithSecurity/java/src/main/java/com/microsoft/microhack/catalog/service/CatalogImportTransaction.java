package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.model.ImportResult;
import java.io.InputStream;

/** Executes one catalog import within its transaction boundary. */
@FunctionalInterface
public interface CatalogImportTransaction {

    /** Returns only after the complete document has committed successfully. */
    ImportResult execute(InputStream input);
}
