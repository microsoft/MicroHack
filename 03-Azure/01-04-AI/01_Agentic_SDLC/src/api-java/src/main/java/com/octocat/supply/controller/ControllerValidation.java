package com.octocat.supply.controller;

import com.octocat.supply.exception.ValidationException;

final class ControllerValidation {
    private ControllerValidation() {
    }

    static void requireText(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ValidationException(fieldName + " is required");
        }
    }

    static void requirePositive(Integer value, String fieldName) {
        if (value == null || value <= 0) {
            throw new ValidationException(fieldName + " is required");
        }
    }
}
