package com.microsoft.microhack.catalog.service;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.core.StreamReadFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.microhack.catalog.model.CatalogImportItem;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/** Parses and validates complete catalog documents without publishing partial prefixes. */
@Component
public class CatalogDocumentParser {

    private static final Pattern CANONICAL_UUID = Pattern.compile(
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");
    private final ObjectMapper objectMapper;
    private final Validator validator;

    public CatalogDocumentParser(ObjectMapper objectMapper, Validator validator) {
        this.objectMapper = objectMapper.copy()
                .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION.mappedFeature());
        this.validator = validator;
    }

    /** Returns only after every record and cross-record identity has been validated. */
    public List<ValidatedCatalogItem> parse(InputStream input) {
        List<CatalogImportItem> records = readDocument(input);
        if (records.isEmpty()) {
            throw new CatalogImportValidationException("catalog document must contain at least one record");
        }
        Map<String, String> namesToSlugs = new HashMap<>();
        Map<String, String> slugsToNames = new HashMap<>();
        Set<UUID> productIds = new HashSet<>();
        List<ValidatedCatalogItem> validated = new ArrayList<>(records.size());
        for (CatalogImportItem record : records) {
            ValidatedCatalogItem item = validate(record, namesToSlugs, slugsToNames);
            if (!productIds.add(item.productId())) {
                throw new CatalogImportValidationException(
                        "productId values must be unique within one document");
            }
            validated.add(item);
        }
        return List.copyOf(validated);
    }

    private List<CatalogImportItem> readDocument(InputStream input) {
        try (JsonParser parser = objectMapper.getFactory().createParser(input)) {
            if (parser.nextToken() != JsonToken.START_ARRAY) {
                throw new CatalogImportValidationException(
                        "catalog document root must be one JSON array");
            }
            List<CatalogImportItem> records = new ArrayList<>();
            while (parser.nextToken() != JsonToken.END_ARRAY) {
                if (parser.currentToken() != JsonToken.START_OBJECT) {
                    throw new CatalogImportValidationException(
                            "every catalog array member must be an object");
                }
                records.add(readItem(parser));
            }
            if (parser.nextToken() != null) {
                throw new CatalogImportValidationException(
                        "catalog document must contain exactly one JSON root");
            }
            return records;
        } catch (IOException exception) {
            throw new CatalogImportValidationException("catalog document is not valid JSON", exception);
        } catch (CatalogImportValidationException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new CatalogImportValidationException("catalog document is invalid", exception);
        }
    }

    private CatalogImportItem readItem(JsonParser parser) throws IOException {
        Map<String, String> fields = new HashMap<>();
        while (parser.nextToken() != JsonToken.END_OBJECT) {
            if (parser.currentToken() != JsonToken.FIELD_NAME) {
                throw new CatalogImportValidationException("catalog object contains an invalid token");
            }
            String field = parser.currentName();
            if (!isAllowedField(field)) {
                throw new CatalogImportValidationException("catalog object contains unknown field " + field);
            }
            if (parser.nextToken() != JsonToken.VALUE_STRING) {
                throw new CatalogImportValidationException(
                        "catalog field " + field + " must be a JSON string");
            }
            fields.put(field, parser.getText());
        }
        return new CatalogImportItem(
                required(fields, "productId"),
                required(fields, "name"),
                required(fields, "description"),
                required(fields, "category"),
                required(fields, "filename"),
                required(fields, "imagePrompt"));
    }

    private static boolean isAllowedField(String field) {
        return switch (field) {
            case "productId", "name", "description", "category", "filename", "imagePrompt" -> true;
            default -> false;
        };
    }

    private static String required(Map<String, String> fields, String field) {
        String value = fields.get(field);
        if (value == null) {
            throw new CatalogImportValidationException(
                    "catalog object is missing required field " + field);
        }
        return value;
    }

    private ValidatedCatalogItem validate(
            CatalogImportItem record,
            Map<String, String> namesToSlugs,
            Map<String, String> slugsToNames) {
        validateText(record.name(), "name", 3, 80, null);
        validateText(record.description(), "description", 20, 1200, null);
        validateText(record.category(), "category", 2, 60, null);
        validateText(record.imagePrompt(), "imagePrompt", 30, null, 260);
        Set<ConstraintViolation<CatalogImportItem>> violations = validator.validate(record);
        if (!violations.isEmpty()) {
            throw new CatalogImportValidationException(
                    "catalog record violates " + violations.iterator().next().getPropertyPath());
        }
        if (!CANONICAL_UUID.matcher(record.productId()).matches()) {
            throw new CatalogImportValidationException(
                    "productId must be a canonical lowercase UUID");
        }
        UUID productId;
        try {
            productId = UUID.fromString(record.productId());
        } catch (IllegalArgumentException exception) {
            throw new CatalogImportValidationException("productId is not an RFC 4122 UUID", exception);
        }
        if (!record.productId().equals(productId.toString())) {
            throw new CatalogImportValidationException(
                    "productId must be a canonical lowercase UUID");
        }
        String expectedFilename = record.productId() + ".png";
        if (!expectedFilename.equals(record.filename())) {
            throw new CatalogImportValidationException(
                    "filename must equal productId plus .png");
        }
        String slug = CategorySlug.normalize(record.category());
        if (slug.isEmpty() || slug.length() > 64) {
            throw new CatalogImportValidationException(
                    "category must normalize to a non-empty slug of at most 64 characters");
        }
        String existingSlug = namesToSlugs.putIfAbsent(record.category(), slug);
        String existingName = slugsToNames.putIfAbsent(slug, record.category());
        if ((existingSlug != null && !existingSlug.equals(slug))
                || (existingName != null && !existingName.equals(record.category()))) {
            throw new CatalogImportValidationException(
                    "category display names and slugs must be unique");
        }
        return new ValidatedCatalogItem(
                productId,
                record.name(),
                record.description(),
                record.category(),
                slug,
                record.filename());
    }

    private static void validateText(
            String value,
            String field,
            int minimumCodePoints,
            Integer maximumUtf16Units,
            Integer maximumCodePoints) {
        if (value == null || value.isEmpty() || value.codePoints().allMatch(
                CatalogDocumentParser::isContractWhitespace)) {
            throw new CatalogImportValidationException(field + " must not be blank");
        }
        int codePoints = value.codePointCount(0, value.length());
        if (codePoints < minimumCodePoints) {
            throw new CatalogImportValidationException(
                    field + " must contain at least " + minimumCodePoints + " Unicode code points");
        }
        if (maximumUtf16Units != null && value.length() > maximumUtf16Units) {
            throw new CatalogImportValidationException(
                    field + " must contain at most " + maximumUtf16Units + " UTF-16 code units");
        }
        if (maximumCodePoints != null && codePoints > maximumCodePoints) {
            throw new CatalogImportValidationException(
                    field + " must contain at most " + maximumCodePoints + " Unicode code points");
        }
    }

    private static boolean isContractWhitespace(int codePoint) {
        return Character.isWhitespace(codePoint)
                || Character.isSpaceChar(codePoint)
                || codePoint == 0x0085;
    }
}
