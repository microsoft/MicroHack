package com.microsoft.microhack.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import com.microsoft.microhack.catalog.service.CatalogDocumentParser;
import com.microsoft.microhack.catalog.service.CatalogImportValidationException;
import com.microsoft.microhack.catalog.service.CategorySlug;
import jakarta.validation.Validation;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Verifies shared normalization and canonical identity vectors without reinterpretation. */
class ConformanceVectorTest {

    private static final String CONTRACTS_MARKER = "workshop/contracts";

    private final JsonMapper mapper = JsonMapper.builder().build();
    private final CatalogDocumentParser parser = new CatalogDocumentParser(
            mapper,
            Validation.buildDefaultValidatorFactory().getValidator());

    @Test
    @DisplayName("Contract.Conformance.NormalizationVectors")
    void categorySlugMatchesSharedVectors() throws Exception {
        JsonNode vectors = mapper.readTree(Files.readString(contract("normalization-vectors.json")));
        for (JsonNode vector : vectors.get("vectors")) {
            assertThat(CategorySlug.normalize(vector.get("input").asText()))
                    .isEqualTo(vector.get("expected").asText());
        }
        for (JsonNode vector : vectors.get("invalidVectors")) {
            assertThat(CategorySlug.normalize(vector.get("input").asText())).isEmpty();
        }
    }

    @Test
    @DisplayName("Contract.Conformance.TextValidationVectors")
    void textValidationMatchesSharedVectors() throws Exception {
        JsonNode vectors = mapper.readTree(Files.readString(contract("text-validation-vectors.json")));
        for (JsonNode vector : vectors.get("vectors")) {
            String value = vector.get("fragment").asText().repeat(vector.get("repeat").asInt());
            Map<String, String> item = validItemFields(
                    "11111111-1111-4111-8111-111111111111");
            item.put(vector.get("field").asText(), value);
            String payload = mapper.writeValueAsString(new Object[] {item});

            if (vector.get("valid").asBoolean()) {
                assertThat(parser.parse(stream(payload)))
                        .as(vector.get("reason").asText())
                        .hasSize(1);
            } else {
                assertThatThrownBy(() -> parser.parse(stream(payload)))
                        .as(vector.get("reason").asText())
                        .isInstanceOf(CatalogImportValidationException.class);
            }
        }
        for (String field : new String[] {"name", "description", "category", "imagePrompt"}) {
            Map<String, String> item = validItemFields(
                    "11111111-1111-4111-8111-111111111111");
            item.put(field, "\u00a0".repeat(field.equals("description") ? 20 : 30));
            String payload = mapper.writeValueAsString(new Object[] {item});
            assertThatThrownBy(() -> parser.parse(stream(payload)))
                    .as("%s rejects NBSP-only text", field)
                    .isInstanceOf(CatalogImportValidationException.class);
        }
    }

    @Test
    void identityMatchesSharedVectors() throws Exception {
        JsonNode vectors = mapper.readTree(Files.readString(contract("identity-vectors.json")));
        for (JsonNode vector : vectors.get("vectors")) {
            String payload = mapper.writeValueAsString(new Object[] {new java.util.LinkedHashMap<>(
                    java.util.Map.of(
                            "productId", vector.get("productId").asText(),
                            "name", "Contract Figure",
                            "description",
                                    "A representative figure used to validate shared identity behavior.",
                            "category", "Contract Figures",
                            "filename", vector.get("filename").asText(),
                            "imagePrompt",
                                    "Photorealistic construction-toy figure on a clean studio background."))});
            if (vector.get("valid").asBoolean()) {
                assertThat(parser.parse(stream(payload))).hasSize(1);
            } else {
                assertThatThrownBy(() -> parser.parse(stream(payload)))
                        .isInstanceOf(CatalogImportValidationException.class);
            }
        }
    }

    @Test
    void completeDocumentRejectsValidPrefix() throws Exception {
        for (String fixture : new String[] {
            "catalog.invalid.json",
            "catalog.invalid-empty-slug.json"
        }) {
            try (var input = Files.newInputStream(repositoryRoot()
                    .resolve("tests/acceptance/fixtures")
                    .resolve(fixture))) {
                assertThatThrownBy(() -> parser.parse(input))
                        .as(fixture)
                        .isInstanceOf(CatalogImportValidationException.class);
            }
        }
    }

    @Test
    void completeDocumentRejectsEveryStructuralViolation() {
        String valid = validItem("11111111-1111-4111-8111-111111111111");
        for (String invalid : new String[] {
                "null",
                "[null]",
                "[" + valid.replace("\"name\":\"Strict Figure\"", "\"name\":7") + "]",
                "[" + valid + "," + valid + "]",
                "[" + valid + "] []",
                "[" + valid + ",null]"
        }) {
            assertThatThrownBy(() -> parser.parse(stream(invalid)))
                    .as(invalid)
                    .isInstanceOf(CatalogImportValidationException.class);
        }
    }

    private static String validItem(String productId) {
        return """
                {
                  "productId":"%s",
                  "name":"Strict Figure",
                  "description":"A complete strict document validation figure for the catalog.",
                  "category":"Strict Figures",
                  "filename":"%s.png",
                  "imagePrompt":"Photorealistic construction-toy figure on a clean studio background."
                }
                """.formatted(productId, productId);
    }

    private static Map<String, String> validItemFields(String productId) {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("productId", productId);
        fields.put("name", "Strict Figure");
        fields.put("description", "A complete strict document validation figure for the catalog.");
        fields.put("category", "Strict Figures");
        fields.put("filename", productId + ".png");
        fields.put(
                "imagePrompt",
                "Photorealistic construction-toy figure on a clean studio background.");
        return fields;
    }

    private static ByteArrayInputStream stream(String value) {
        return new ByteArrayInputStream(value.getBytes(StandardCharsets.UTF_8));
    }

    private static Path contract(String filename) {
        return repositoryRoot().resolve(CONTRACTS_MARKER).resolve(filename);
    }

    /**
     * Locates the repository root that owns the shared contracts by walking upward from the
     * working directory until a directory containing {@code workshop/contracts} is found.
     *
     * <p>A corresponding test lives in {@code walkthrough/ch01-A/java/app}, three directories
     * deeper than the legacy tree. A fixed relative parent therefore resolved
     * correctly from one tree and silently to the wrong directory from the other; searching for
     * the marker makes the same source correct from both. Failure is loud by design, because a
     * silent wrong answer is what hid the original defect.
     */
    static Path repositoryRoot() {
        Path start = Path.of("").toAbsolutePath().normalize();
        for (Path candidate = start; candidate != null; candidate = candidate.getParent()) {
            if (Files.isDirectory(candidate.resolve(CONTRACTS_MARKER))) {
                return candidate;
            }
        }
        throw new IllegalStateException("Repository root was not found: no ancestor of " + start
                + " contains a '" + CONTRACTS_MARKER + "' directory.");
    }
}
