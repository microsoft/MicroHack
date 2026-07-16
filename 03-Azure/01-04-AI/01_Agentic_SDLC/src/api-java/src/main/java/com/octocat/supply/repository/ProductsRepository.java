package com.octocat.supply.repository;

import com.octocat.supply.model.ProductModel.CreateProductRequest;
import com.octocat.supply.model.ProductModel.Product;
import com.octocat.supply.model.ProductModel.UpdateProductRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class ProductsRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Product> mapper = (rs, rowNum) -> new Product(
        rs.getInt("product_id"),
        rs.getInt("supplier_id"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getDouble("price"),
        rs.getString("sku"),
        rs.getString("unit"),
        rs.getString("img_name"),
        rs.getDouble("discount")
    );

    public ProductsRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Product> findAll() {
        return jdbcTemplate.query("SELECT * FROM products ORDER BY product_id", mapper);
    }

    public Optional<Product> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM products WHERE product_id = ?", mapper, id).stream().findFirst();
    }

    public Product create(CreateProductRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO products (supplier_id, name, description, price, sku, unit, img_name, discount)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            request.supplierId(),
            request.name(),
            request.description(),
            request.price(),
            request.sku(),
            request.unit(),
            request.imgName(),
            request.discount() == null ? 0d : request.discount()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateProductRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("supplier_id", request.supplierId());
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("price", request.price());
                b.add("sku", request.sku());
                b.add("unit", request.unit());
                b.add("img_name", request.imgName());
                b.add("discount", request.discount());
            },
            "products",
            "product_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM products WHERE product_id = ?", id) > 0;
    }
}
