package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.service.LocalImageStore;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/** Serves exact PNG bytes while rejecting malformed and traversal image paths. */
@Controller
public class ImageController {

    private final LocalImageStore imageStore;

    public ImageController(LocalImageStore imageStore) {
        this.imageStore = imageStore;
    }

    @GetMapping("/images/**")
    public ResponseEntity<byte[]> image(HttpServletRequest request) throws IOException {
        String uri = request.getRequestURI();
        int marker = uri.indexOf("/images/");
        if (marker < 0) {
            return ResponseEntity.notFound().build();
        }
        String rawKey = uri.substring(marker + "/images/".length());
        if (!StandardCharsets.US_ASCII.newEncoder().canEncode(rawKey)
                || !LocalImageStore.isCanonicalImageKey(rawKey)) {
            return ResponseEntity.notFound().build();
        }
        return imageStore.read(rawKey)
                .map(bytes -> ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_PNG_VALUE)
                        .cacheControl(CacheControl.noStore())
                        .body(bytes))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }
}
