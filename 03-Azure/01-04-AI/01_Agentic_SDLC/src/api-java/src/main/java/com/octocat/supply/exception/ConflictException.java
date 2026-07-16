package com.octocat.supply.exception;

public class ConflictException extends ApiException {
    public ConflictException(String message) {
        super("CONFLICT_ERROR", message);
    }
}
