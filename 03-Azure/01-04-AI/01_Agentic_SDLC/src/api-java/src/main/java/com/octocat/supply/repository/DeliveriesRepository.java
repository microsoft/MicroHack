package com.octocat.supply.repository;

import com.octocat.supply.model.DeliveryModel.CreateDeliveryRequest;
import com.octocat.supply.model.DeliveryModel.Delivery;
import com.octocat.supply.model.DeliveryModel.UpdateDeliveryRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class DeliveriesRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Delivery> mapper = (rs, rowNum) -> new Delivery(
        rs.getInt("delivery_id"),
        rs.getInt("order_id"),
        rs.getString("delivery_date"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getString("status")
    );

    public DeliveriesRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Delivery> findAll() {
        return jdbcTemplate.query("SELECT * FROM deliveries ORDER BY delivery_id", mapper);
    }

    public Optional<Delivery> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM deliveries WHERE delivery_id = ?", mapper, id).stream().findFirst();
    }

    public Delivery create(CreateDeliveryRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO deliveries (order_id, delivery_date, name, description, status)
                VALUES (?, ?, ?, ?, ?)
                """,
            request.orderId(),
            request.deliveryDate(),
            request.name(),
            request.description(),
            request.status() == null ? "pending" : request.status()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateDeliveryRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("order_id", request.orderId());
                b.add("delivery_date", request.deliveryDate());
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("status", request.status());
            },
            "deliveries",
            "delivery_id",
            id,
            jdbcTemplate
        );
    }

    public boolean updateStatus(int id, String status) {
        return jdbcTemplate.update("UPDATE deliveries SET status = ? WHERE delivery_id = ?", status, id) > 0;
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM deliveries WHERE delivery_id = ?", id) > 0;
    }
}
