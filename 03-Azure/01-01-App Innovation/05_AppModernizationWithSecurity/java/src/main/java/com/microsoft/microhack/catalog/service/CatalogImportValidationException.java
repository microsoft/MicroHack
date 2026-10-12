package com.microsoft.microhack.catalog.service;

/** Signals that an entire import document was rejected before publication. */
public class CatalogImportValidationException extends RuntimeException {

    public CatalogImportValidationException(String message) {
        super(message);
    }

    public CatalogImportValidationException(String message, Throwable cause) {
        super(message, cause);
    }
}
