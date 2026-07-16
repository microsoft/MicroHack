package com.octocat.supply.exception;

public class DatabaseException extends ApiException {
    public DatabaseException(String message) {
        super("DATABASE_ERROR", message);
    }
}
