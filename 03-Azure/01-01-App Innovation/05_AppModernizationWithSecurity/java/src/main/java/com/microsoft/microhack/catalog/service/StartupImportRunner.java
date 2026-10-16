package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/** Executes the configured idempotent startup import after Flyway and JPA validation. */
@Component
public class StartupImportRunner implements ApplicationRunner {

    private static final Logger LOGGER = LoggerFactory.getLogger(StartupImportRunner.class);
    private final CatalogRuntimeOptions options;
    private final CatalogImportService importService;
    private final StartupState startupState;

    public StartupImportRunner(
            CatalogRuntimeOptions options,
            CatalogImportService importService,
            StartupState startupState) {
        this.options = options;
        this.importService = importService;
        this.startupState = startupState;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!options.startupImportEnabled()) {
            startupState.ready();
            return;
        }
        try (InputStream input = Files.newInputStream(options.seedPath())) {
            importService.importDocument(input);
            startupState.ready();
        } catch (IOException exception) {
            startupState.failed();
            CatalogTelemetry.logFailure(
                    LOGGER,
                    "catalog.import.failed",
                    exception,
                    java.util.Map.of("catalog.import.rejected", 1));
        } catch (RuntimeException exception) {
            startupState.failed();
        }
    }
}
