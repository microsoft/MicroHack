package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.model.PerformanceResult;
import com.microsoft.microhack.catalog.service.CatalogDependencyUnavailableException;
import com.microsoft.microhack.catalog.service.CatalogQueryTimeoutException;
import com.microsoft.microhack.catalog.service.PerformanceCatalogService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/** Enforces API-key authentication and frozen performance failure responses. */
@RestController
public class PerformanceController {

    private final PerformanceCatalogService performance;
    private final byte[] expectedKey;

    public PerformanceController(
            PerformanceCatalogService performance,
            CatalogRuntimeOptions options) {
        this.performance = performance;
        expectedKey = options.performanceApiKey().getBytes(StandardCharsets.UTF_8);
    }

    @GetMapping("/perftest/catalog")
    public ResponseEntity<?> execute(
            @RequestHeader(name = "x-api-key", required = false) String apiKey) {
        byte[] actual = apiKey == null
                ? new byte[0]
                : apiKey.getBytes(StandardCharsets.UTF_8);
        if (!MessageDigest.isEqual(expectedKey, actual)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(failureBody("unauthorized", "invalid_api_key"));
        }
        try {
            PerformanceResult result = performance.execute();
            return ResponseEntity.ok(result);
        } catch (CatalogQueryTimeoutException exception) {
            return ResponseEntity.status(HttpStatus.GATEWAY_TIMEOUT)
                    .body(failureBody("unavailable", "catalog_query_timeout"));
        } catch (CatalogDependencyUnavailableException exception) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(failureBody("unavailable", "catalog_dependency_unavailable"));
        }
    }

    private static Map<String, String> failureBody(String status, String error) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("status", status);
        body.put("error", error);
        return body;
    }
}
