package com.octocat.supply.model;

public final class OrderModel {
    private OrderModel() {
    }

    public record Order(
        int orderId,
        int branchId,
        String orderDate,
        String name,
        String description,
        String status
    ) {
    }

    public record CreateOrderRequest(
        Integer branchId,
        String orderDate,
        String name,
        String description,
        String status
    ) {
    }

    public record UpdateOrderRequest(
        Integer branchId,
        String orderDate,
        String name,
        String description,
        String status
    ) {
    }
}
