package com.octocat.supply.exception;

public class ValidationException extends ApiException {
    public ValidationException(String message) {
        super("VALIDATION_ERROR", message);
    }
}
