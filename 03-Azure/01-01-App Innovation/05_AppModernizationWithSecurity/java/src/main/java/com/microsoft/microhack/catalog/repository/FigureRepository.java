package com.microsoft.microhack.catalog.repository;

import com.microsoft.microhack.catalog.domain.Figure;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Persists figures and exposes the frozen ordered catalog query. */
public interface FigureRepository extends JpaRepository<Figure, UUID> {

    List<Figure> findAllByOrderByIdAsc();

    @Query("""
            SELECT f FROM Figure f
            WHERE lower(f.name) LIKE concat('%', lower(:search), '%') ESCAPE '!'
            ORDER BY f.id ASC
            """)
    List<Figure> findByNameLiteral(
            @Param("search") String escapedSearch);

    @Query("""
            SELECT f FROM Figure f
            WHERE f.category.slug = :category
               OR lower(f.category.name) = lower(:category)
            ORDER BY f.id ASC
            """)
    List<Figure> findByCategory(@Param("category") String category);

    @Query("""
            SELECT f FROM Figure f
            WHERE lower(f.name) LIKE concat('%', lower(:search), '%') ESCAPE '!'
              AND (f.category.slug = :category
                   OR lower(f.category.name) = lower(:category))
            ORDER BY f.id ASC
            """)
    List<Figure> findBySearchAndCategory(
            @Param("search") String escapedSearch,
            @Param("category") String category);
}
