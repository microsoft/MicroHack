package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.service.LocalImageStore;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** Verifies exact image bytes and rejects all non-canonical storage keys. */
class LocalImageStoreTest {

    @TempDir
    Path imageRoot;

    @Test
    void servesCanonicalPngBytesOnly() throws Exception {
        String key = "10000000-0000-4000-8000-000000000001.png";
        byte[] expected = new byte[] {1, 2, 3};
        Files.write(imageRoot.resolve(key), expected);
        LocalImageStore store = new LocalImageStore(options(imageRoot));

        assertThat(store.read(key)).contains(expected);
        for (String rejected : new String[] {
                "../catalog.json",
                "..\\catalog.json",
                "%2e%2e%2fcatalog.json",
                "10000000-0000-4000-8000-000000000001.PNG",
                "not-a-uuid.png"
        }) {
            assertThat(store.read(rejected)).isEmpty();
        }
    }

    private static CatalogRuntimeOptions options(Path imageRoot) {
        CatalogRuntimeOptions source = ContractTestOptions.options();
        return new CatalogRuntimeOptions(
                source.databaseHost(),
                source.databaseName(),
                imageRoot,
                source.seedPath(),
                source.startupImportEnabled(),
                source.performanceApiKey(),
                source.performanceWorkFactor(),
                source.serviceVersion(),
                source.deploymentEnvironment(),
                source.revisionName(),
                source.serviceInstanceId(),
                source.otlpEndpoint());
    }
}
