package com.octocat.supply.repository;

import com.octocat.supply.model.SupplierModel.CreateSupplierRequest;
import com.octocat.supply.model.SupplierModel.Supplier;
import com.octocat.supply.model.SupplierModel.UpdateSupplierRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class SuppliersRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Supplier> mapper = (rs, rowNum) -> new Supplier(
        rs.getInt("supplier_id"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getString("contact_person"),
        rs.getString("email"),
        rs.getString("phone"),
        rs.getInt("active") == 1,
        rs.getInt("verified") == 1
    );

    public SuppliersRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Supplier> findAll() {
        return jdbcTemplate.query("SELECT * FROM suppliers ORDER BY supplier_id", mapper);
    }

    public Optional<Supplier> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM suppliers WHERE supplier_id = ?", mapper, id).stream().findFirst();
    }

    public Supplier create(CreateSupplierRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO suppliers (name, description, contact_person, email, phone, active, verified)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            request.name(),
            request.description(),
            request.contactPerson(),
            request.email(),
            request.phone(),
            request.active() == null || request.active() ? 1 : 0,
            request.verified() != null && request.verified() ? 1 : 0
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateSupplierRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("contact_person", request.contactPerson());
                b.add("email", request.email());
                b.add("phone", request.phone());
                b.add("active", request.active() == null ? null : (request.active() ? 1 : 0));
                b.add("verified", request.verified() == null ? null : (request.verified() ? 1 : 0));
            },
            "suppliers",
            "supplier_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM suppliers WHERE supplier_id = ?", id) > 0;
    }
}
