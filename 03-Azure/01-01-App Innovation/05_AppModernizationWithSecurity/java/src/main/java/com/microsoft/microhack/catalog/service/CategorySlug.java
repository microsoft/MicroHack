package com.microsoft.microhack.catalog.service;

import java.text.Normalizer;
import java.util.Locale;

/** Implements the frozen category-slug-v1 normalization algorithm. */
public final class CategorySlug {

    private CategorySlug() {
    }

    /** Normalizes a display name into a lowercase ASCII slug. */
    public static String normalize(String value) {
        if (value == null) {
            return "";
        }
        String decomposed = Normalizer.normalize(value.trim(), Normalizer.Form.NFKD)
                .toLowerCase(Locale.ROOT);
        StringBuilder slug = new StringBuilder();
        boolean separatorPending = false;
        for (int index = 0; index < decomposed.length(); ) {
            int codePoint = decomposed.codePointAt(index);
            index += Character.charCount(codePoint);
            int type = Character.getType(codePoint);
            if (type == Character.NON_SPACING_MARK
                    || type == Character.COMBINING_SPACING_MARK
                    || type == Character.ENCLOSING_MARK
                    || codePoint == '\''
                    || codePoint == '\u2019') {
                continue;
            }
            boolean asciiAlphanumeric = (codePoint >= 'a' && codePoint <= 'z')
                    || (codePoint >= '0' && codePoint <= '9');
            if (asciiAlphanumeric) {
                if (separatorPending && !slug.isEmpty()) {
                    slug.append('-');
                }
                slug.appendCodePoint(codePoint);
                separatorPending = false;
            } else {
                separatorPending = true;
            }
        }
        return slug.toString();
    }
}
