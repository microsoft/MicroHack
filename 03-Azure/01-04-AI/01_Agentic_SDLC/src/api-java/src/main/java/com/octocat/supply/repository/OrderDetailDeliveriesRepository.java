package com.octocat.supply.repository;

import com.octocat.supply.model.OrderDetailDeliveryModel.CreateOrderDetailDeliveryRequest;
import com.octocat.supply.model.OrderDetailDeliveryModel.OrderDetailDelivery;
import com.octocat.supply.model.OrderDetailDeliveryModel.UpdateOrderDetailDeliveryRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class OrderDetailDeliveriesRepository {
    private final JdbcTemplate jdbcTemplate;

    private final RowMapper<OrderDetailDelivery> mapper = (rs, rowNum) -> new OrderDetailDelivery(
        rs.getInt("order_detail_delivery_id"),
        rs.getInt("order_detail_id"),
        rs.getInt("delivery_id"),
        rs.getInt("quantity_delivered")
    );

    public OrderDetailDeliveriesRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<OrderDetailDelivery> findAll() {
        return jdbcTemplate.query("SELECT * FROM order_detail_deliveries ORDER BY order_detail_delivery_id", mapper);
    }

    public Optional<OrderDetailDelivery> findById(int id) {
        return jdbcTemplate.query(
            "SELECT * FROM order_detail_deliveries WHERE order_detail_delivery_id = ?",
            mapper,
            id
        ).stream().findFirst();
    }

    public OrderDetailDelivery create(CreateOrderDetailDeliveryRequest request) {
        jdbcTemplate.update(
            """
                INSERT INTO order_detail_deliveries (order_detail_id, delivery_id, quantity_delivered)
                VALUES (?, ?, ?)
                """,
            request.orderDetailId(),
            request.deliveryId(),
            request.quantityDelivered()
        );
        Integer id = jdbcTemplate.queryForObject("SELECT last_insert_rowid()", Integer.class);
        return findById(id).orElseThrow();
    }

    public boolean update(int id, UpdateOrderDetailDeliveryRequest request) {
        return SqlUpdateBuilder.executeIfPresent(
            b -> {
                b.add("order_detail_id", request.orderDetailId());
                b.add("delivery_id", request.deliveryId());
                b.add("quantity_delivered", request.quantityDelivered());
            },
            "order_detail_deliveries",
            "order_detail_delivery_id",
            id,
            jdbcTemplate
        );
    }

    public boolean delete(int id) {
        return jdbcTemplate.update("DELETE FROM order_detail_deliveries WHERE order_detail_delivery_id = ?", id) > 0;
    }
}
