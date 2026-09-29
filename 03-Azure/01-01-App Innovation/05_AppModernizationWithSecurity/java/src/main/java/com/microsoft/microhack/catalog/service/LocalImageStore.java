package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

/** Resolves canonical one-segment image keys inside the configured local image root. */
@Service
public class LocalImageStore {

    private static final Pattern CANONICAL_KEY = Pattern.compile(
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.png$");
    private final Path root;

    public LocalImageStore(CatalogRuntimeOptions options) {
        root = options.imagesPath().toAbsolutePath().normalize();
    }

    /** Returns image bytes only for canonical keys that resolve beneath the root. */
    public Optional<byte[]> read(String key) throws IOException {
        if (!isCanonicalImageKey(key)) {
            return Optional.empty();
        }
        Path candidate = root.resolve(key).normalize();
        if (!candidate.getParent().equals(root) || !Files.isRegularFile(candidate)) {
            return Optional.empty();
        }
        return Optional.of(Files.readAllBytes(candidate));
    }

    public static boolean isCanonicalImageKey(String key) {
        return key != null && CANONICAL_KEY.matcher(key).matches();
    }
}
