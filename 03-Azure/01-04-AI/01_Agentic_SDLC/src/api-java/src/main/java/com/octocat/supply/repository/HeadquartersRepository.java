package com.octocat.supply.repository;

import com.octocat.supply.model.HeadquartersModel.CreateHeadquartersRequest;
import com.octocat.supply.model.HeadquartersModel.Headquarters;
import com.octocat.supply.model.HeadquartersModel.HeadquartersMetrics;
import com.octocat.supply.model.HeadquartersModel.UpdateHeadquartersRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public class HeadquartersRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Headquarters> mapper = (rs, rowNum) -> new Headquarters(
        rs.getInt("headquarters_id"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getString("address"),
        rs.getString("contact_person"),
        rs.getString("email"),
        rs.getString("phone")
    );

    public HeadquartersRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Headquarters> findAll() {
        return jdbcTemplate.query("SELECT * FROM headquarters ORDER BY headquarters_id", mapper);
    }

    public Optional<Headquarters> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM headquarters WHERE headquarters_id = ?", mapper, id).stream().findFirst();
    }

    public Headquarters create(CreateHeadquartersRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO headquarters (name, description, address, contact_person, email, phone)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
            request.name(),
            request.description(),
            request.address(),
            request.contactPerson(),
            request.email(),
            request.phone()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateHeadquartersRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("address", request.address());
                b.add("contact_person", request.contactPerson());
                b.add("email", request.email());
                b.add("phone", request.phone());
            },
            "headquarters",
            "headquarters_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM headquarters WHERE headquarters_id = ?", id) > 0;
    }

    public HeadquartersMetrics metrics(int id) {
        Map<String, Object> row = jdbcTemplate.queryForMap(
            """
                SELECT COUNT(*) AS branch_count,
                       COUNT(DISTINCT o.order_id) AS order_count
                FROM branches b
                LEFT JOIN orders o ON o.branch_id = b.branch_id
                WHERE b.headquarters_id = ?
                """,
            id
        );
        int branchCount = ((Number) row.get("branch_count")).intValue();
        int orderCount = ((Number) row.get("order_count")).intValue();
        int score = branchCount * 100 + orderCount * 10;
        double average = branchCount == 0 ? 0.0 : (double) orderCount / branchCount;
        String display = "H-" + id + "-" + score;
        return new HeadquartersMetrics(score, average, display);
    }

    public String label(int id) {
        return "HQ-" + id;
    }
}
