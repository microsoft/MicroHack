package com.octocat.supply.model;

public final class OrderDetailModel {
    private OrderDetailModel() {
    }

    public record OrderDetail(
        int orderDetailId,
        int orderId,
        int productId,
        int quantity
    ) {
    }

    public record CreateOrderDetailRequest(
        Integer orderId,
        Integer productId,
        Integer quantity
    ) {
    }

    public record UpdateOrderDetailRequest(
        Integer orderId,
        Integer productId,
        Integer quantity
    ) {
    }
}
