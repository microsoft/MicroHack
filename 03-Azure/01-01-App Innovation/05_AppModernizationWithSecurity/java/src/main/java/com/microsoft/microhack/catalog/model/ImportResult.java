package com.microsoft.microhack.catalog.model;

/** Reports complete accounting for one accepted import. */
public record ImportResult(int inserted, int skipped, int total) {
}
