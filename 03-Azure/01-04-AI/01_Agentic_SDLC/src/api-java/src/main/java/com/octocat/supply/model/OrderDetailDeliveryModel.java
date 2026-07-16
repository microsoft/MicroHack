package com.octocat.supply.model;

public final class OrderDetailDeliveryModel {
    private OrderDetailDeliveryModel() {
    }

    public record OrderDetailDelivery(
        int orderDetailDeliveryId,
        int orderDetailId,
        int deliveryId,
        int quantityDelivered
    ) {
    }

    public record CreateOrderDetailDeliveryRequest(
        Integer orderDetailId,
        Integer deliveryId,
        Integer quantityDelivered
    ) {
    }

    public record UpdateOrderDetailDeliveryRequest(
        Integer orderDetailId,
        Integer deliveryId,
        Integer quantityDelivered
    ) {
    }
}
