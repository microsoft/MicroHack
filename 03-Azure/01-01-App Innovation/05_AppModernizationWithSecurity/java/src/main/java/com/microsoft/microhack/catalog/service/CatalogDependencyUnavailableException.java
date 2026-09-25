package com.microsoft.microhack.catalog.service;

/** Signals a controlled unavailable database dependency. */
public class CatalogDependencyUnavailableException extends RuntimeException {

    public CatalogDependencyUnavailableException(Throwable cause) {
        super("The catalog dependency is unavailable.", cause);
    }
}
