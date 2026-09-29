package com.microsoft.microhack.catalog.repository;

import com.microsoft.microhack.catalog.domain.Category;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/** Persists and queries catalog categories. */
public interface CategoryRepository extends JpaRepository<Category, Long> {

    Optional<Category> findByName(String name);

    Optional<Category> findBySlug(String slug);

    List<Category> findAllByOrderByNameAsc();
}
