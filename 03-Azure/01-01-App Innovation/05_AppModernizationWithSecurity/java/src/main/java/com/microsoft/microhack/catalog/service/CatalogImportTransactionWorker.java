package com.microsoft.microhack.catalog.service;

import com.microsoft.microhack.catalog.domain.Category;
import com.microsoft.microhack.catalog.domain.Figure;
import com.microsoft.microhack.catalog.model.ImportResult;
import com.microsoft.microhack.catalog.repository.CategoryRepository;
import com.microsoft.microhack.catalog.repository.FigureRepository;
import java.io.InputStream;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Validates and publishes a complete catalog document in one transaction. */
@Service
public class CatalogImportTransactionWorker implements CatalogImportTransaction {

    private final CatalogDocumentParser parser;
    private final FigureRepository figures;
    private final CategoryRepository categories;

    public CatalogImportTransactionWorker(
            CatalogDocumentParser parser,
            FigureRepository figures,
            CategoryRepository categories) {
        this.parser = parser;
        this.figures = figures;
        this.categories = categories;
    }

    /** Commits all new figures and categories atomically after complete validation. */
    @Override
    @Transactional
    public ImportResult execute(InputStream input) {
        List<ValidatedCatalogItem> items = parser.parse(input);
        int inserted = 0;
        int skipped = 0;
        Map<String, Category> categoryCache = new HashMap<>();
        for (ValidatedCatalogItem item : items) {
            if (figures.existsById(item.productId())) {
                skipped++;
                continue;
            }
            Category category = resolveCategory(item, categoryCache);
            OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
            figures.save(new Figure(
                    item.productId(),
                    item.name(),
                    item.description(),
                    category,
                    item.filename(),
                    now));
            inserted++;
        }
        figures.flush();
        return new ImportResult(inserted, skipped, items.size());
    }

    private Category resolveCategory(
            ValidatedCatalogItem item,
            Map<String, Category> categoryCache) {
        Category cached = categoryCache.get(item.category());
        if (cached != null) {
            return cached;
        }
        Category byName = categories.findByName(item.category()).orElse(null);
        Category bySlug = categories.findBySlug(item.categorySlug()).orElse(null);
        if (byName != null && !byName.getSlug().equals(item.categorySlug())) {
            throw new CatalogImportValidationException("category name conflicts with its slug");
        }
        if (bySlug != null && !bySlug.getName().equals(item.category())) {
            throw new CatalogImportValidationException("category slug conflicts with its display name");
        }
        Category resolved = byName != null
                ? byName
                : bySlug != null
                        ? bySlug
                        : categories.save(new Category(item.category(), item.categorySlug()));
        categoryCache.put(item.category(), resolved);
        return resolved;
    }
}
