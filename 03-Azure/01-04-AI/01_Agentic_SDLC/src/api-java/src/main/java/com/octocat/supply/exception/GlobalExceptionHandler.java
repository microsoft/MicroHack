package com.octocat.supply.exception;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<Map<String, Object>> handleNotFound(NotFoundException exception) {
        return error(HttpStatus.NOT_FOUND, exception);
    }

    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(ValidationException exception) {
        return error(HttpStatus.BAD_REQUEST, exception);
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<Map<String, Object>> handleConflict(ConflictException exception) {
        return error(HttpStatus.CONFLICT, exception);
    }

    @ExceptionHandler({DatabaseException.class, DataIntegrityViolationException.class})
    public ResponseEntity<Map<String, Object>> handleDatabase(RuntimeException exception) {
        ApiException apiException = exception instanceof ApiException api ? api : new DatabaseException("Database operation failed.");
        return error(HttpStatus.INTERNAL_SERVER_ERROR, apiException);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneric(Exception exception) {
        return error(HttpStatus.INTERNAL_SERVER_ERROR, new ApiException("INTERNAL_ERROR", "Internal server error."));
    }

    private ResponseEntity<Map<String, Object>> error(HttpStatus status, ApiException exception) {
        return ResponseEntity.status(status).body(Map.of(
            "error", Map.of(
                "code", exception.getCode(),
                "message", exception.getMessage()
            )
        ));
    }
}
