package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.service.StartupState;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Separates process-only liveness from database and startup-import readiness. */
@RestController
public class HealthController {

    private final JdbcTemplate jdbc;
    private final StartupState startupState;

    public HealthController(JdbcTemplate jdbc, StartupState startupState) {
        this.jdbc = jdbc;
        this.startupState = startupState;
    }

    @GetMapping("/healthz")
    public Map<String, String> liveness() {
        return Map.of("status", "healthy");
    }

    @GetMapping("/readyz")
    public ResponseEntity<Map<String, Object>> readiness() {
        boolean databaseReady = databaseReady();
        String importStatus = switch (startupState.status()) {
            case READY -> "ready";
            case FAILED -> "failed";
            case NOT_READY -> "not_ready";
        };
        boolean ready = databaseReady && startupState.status() == StartupState.Status.READY;
        Map<String, String> checks = new LinkedHashMap<>();
        checks.put("database", databaseReady ? "ready" : "not_ready");
        checks.put("import", importStatus);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", ready ? "ready" : "not_ready");
        body.put("checks", checks);
        return ResponseEntity.status(ready ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
                .body(body);
    }

    private boolean databaseReady() {
        try {
            return Integer.valueOf(1).equals(jdbc.queryForObject("SELECT 1", Integer.class));
        } catch (DataAccessException exception) {
            return false;
        }
    }
}
