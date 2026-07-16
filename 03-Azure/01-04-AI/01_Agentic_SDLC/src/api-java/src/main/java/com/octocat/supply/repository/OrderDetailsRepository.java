package com.octocat.supply.repository;

import com.octocat.supply.model.OrderDetailModel.CreateOrderDetailRequest;
import com.octocat.supply.model.OrderDetailModel.OrderDetail;
import com.octocat.supply.model.OrderDetailModel.UpdateOrderDetailRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class OrderDetailsRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<OrderDetail> mapper = (rs, rowNum) -> new OrderDetail(
        rs.getInt("order_detail_id"),
        rs.getInt("order_id"),
        rs.getInt("product_id"),
        rs.getInt("quantity")
    );

    public OrderDetailsRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<OrderDetail> findAll() {
        return jdbcTemplate.query("SELECT * FROM order_details ORDER BY order_detail_id", mapper);
    }

    public Optional<OrderDetail> findById(int id) {
        return jdbcTemplate.query("SELECT * FROM order_details WHERE order_detail_id = ?", mapper, id).stream().findFirst();
    }

    public OrderDetail create(CreateOrderDetailRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO order_details (order_id, product_id, quantity)
                VALUES (?, ?, ?)
                """,
            request.orderId(),
            request.productId(),
            request.quantity()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateOrderDetailRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("order_id", request.orderId());
                b.add("product_id", request.productId());
                b.add("quantity", request.quantity());
            },
            "order_details",
            "order_detail_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM order_details WHERE order_detail_id = ?", id) > 0;
    }
}
