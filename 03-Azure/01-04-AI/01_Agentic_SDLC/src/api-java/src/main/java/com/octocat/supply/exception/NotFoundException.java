package com.octocat.supply.exception;

public class NotFoundException extends ApiException {
    public NotFoundException(String message) {
        super("NOT_FOUND", message);
    }
}
