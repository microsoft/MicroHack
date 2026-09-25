package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.model.CatalogFigureDto;
import com.microsoft.microhack.catalog.service.CatalogService;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.server.ResponseStatusException;

/** Renders catalog, search, category filter, and detail pages. */
@Controller
public class CatalogController {

    private final CatalogService catalog;

    public CatalogController(CatalogService catalog) {
        this.catalog = catalog;
    }

    @GetMapping("/")
    public String index(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String category,
            Model model) {
        model.addAttribute("figures", catalog.list(search, category));
        model.addAttribute("categories", catalog.categories());
        model.addAttribute("search", search == null ? "" : search);
        model.addAttribute("selectedCategory", category == null ? "" : category);
        return "catalog";
    }

    @GetMapping("/figure/{id}")
    public String detail(@PathVariable String id, Model model) {
        UUID figureId;
        try {
            figureId = UUID.fromString(id);
        } catch (IllegalArgumentException exception) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        if (!id.equals(figureId.toString())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        CatalogFigureDto figure = catalog.find(figureId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        model.addAttribute("figure", figure);
        return "detail";
    }
}
