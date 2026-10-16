package com.microsoft.microhack.catalog.service;

/** Signals a controlled database query timeout. */
public class CatalogQueryTimeoutException extends RuntimeException {

    public CatalogQueryTimeoutException(Throwable cause) {
        super("The catalog query timed out.", cause);
    }
}
