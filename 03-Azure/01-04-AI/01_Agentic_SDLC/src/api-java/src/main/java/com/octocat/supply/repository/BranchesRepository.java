package com.octocat.supply.repository;

import com.octocat.supply.model.BranchModel.Branch;
import com.octocat.supply.model.BranchModel.CreateBranchRequest;
import com.octocat.supply.model.BranchModel.UpdateBranchRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class BranchesRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Branch> mapper = (rs, rowNum) -> new Branch(
        rs.getInt("branch_id"),
        rs.getInt("headquarters_id"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getString("address"),
        rs.getString("contact_person"),
        rs.getString("email"),
        rs.getString("phone")
    );

    public BranchesRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Branch> findAll() {
        return jdbcTemplate.query("SELECT * FROM branches ORDER BY branch_id", mapper);
    }

    public Optional<Branch> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM branches WHERE branch_id = ?", mapper, id).stream().findFirst();
    }

    public Branch create(CreateBranchRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO branches (headquarters_id, name, description, address, contact_person, email, phone)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            request.headquartersId(),
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

    public boolean update(int id, UpdateBranchRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("headquarters_id", request.headquartersId());
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("address", request.address());
                b.add("contact_person", request.contactPerson());
                b.add("email", request.email());
                b.add("phone", request.phone());
            },
            "branches",
            "branch_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM branches WHERE branch_id = ?", id) > 0;
    }
}
