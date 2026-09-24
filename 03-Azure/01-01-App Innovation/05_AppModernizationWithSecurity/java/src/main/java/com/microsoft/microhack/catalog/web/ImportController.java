package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.model.ImportResult;
import com.microsoft.microhack.catalog.service.CatalogImportService;
import com.microsoft.microhack.catalog.service.CatalogImportValidationException;
import java.io.IOException;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;

/** Renders the import form and accepts strict multipart catalog documents. */
@Controller
public class ImportController {

    private final CatalogImportService importService;

    public ImportController(CatalogImportService importService) {
        this.importService = importService;
    }

    @GetMapping("/import")
    public String page() {
        return "import";
    }

    @PostMapping(
            path = "/import",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseBody
    public ResponseEntity<?> upload(@RequestParam("catalogFile") MultipartFile catalogFile) {
        if (catalogFile.isEmpty()) {
            return rejected("catalog file is required");
        }
        try {
            ImportResult result = importService.importDocument(catalogFile.getInputStream());
            return ResponseEntity.ok(result);
        } catch (CatalogImportValidationException | DataIntegrityViolationException exception) {
            return rejected(exception.getMessage());
        } catch (IOException exception) {
            return rejected("catalog file could not be read");
        }
    }

    private static ResponseEntity<Map<String, String>> rejected(String detail) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "status", "rejected",
                "error", "invalid_catalog",
                "detail", detail == null ? "catalog document was rejected" : detail));
    }
}
