package com.octocat.supply.repository;

import com.octocat.supply.model.OrderModel.CreateOrderRequest;
import com.octocat.supply.model.OrderModel.Order;
import com.octocat.supply.model.OrderModel.UpdateOrderRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class OrdersRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<Order> mapper = (rs, rowNum) -> new Order(
        rs.getInt("order_id"),
        rs.getInt("branch_id"),
        rs.getString("order_date"),
        rs.getString("name"),
        rs.getString("description"),
        rs.getString("status")
    );

    public OrdersRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Order> findAll() {
        return jdbcTemplate.query("SELECT * FROM orders ORDER BY order_id", mapper);
    }

    public Optional<Order> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM orders WHERE order_id = ?", mapper, id).stream().findFirst();
    }

    public Order create(CreateOrderRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO orders (branch_id, order_date, name, description, status)
                VALUES (?, ?, ?, ?, ?)
                """,
            request.branchId(),
            request.orderDate(),
            request.name(),
            request.description(),
            request.status() == null ? "pending" : request.status()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateOrderRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("branch_id", request.branchId());
                b.add("order_date", request.orderDate());
                b.add("name", request.name());
                b.add("description", request.description());
                b.add("status", request.status());
            },
            "orders",
            "order_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM orders WHERE order_id = ?", id) > 0;
    }
}
