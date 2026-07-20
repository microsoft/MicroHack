package com.octocat.supply.model;

public final class DeliveryModel {
    private DeliveryModel() {
    }

    public record Delivery(
        int deliveryId,
        int orderId,
        String deliveryDate,
        String name,
        String description,
        String status
    ) {
    }

    public record CreateDeliveryRequest(
        Integer orderId,
        String deliveryDate,
        String name,
        String description,
        String status
    ) {
    }

    public record UpdateDeliveryRequest(
        Integer orderId,
        String deliveryDate,
        String name,
        String description,
        String status
    ) {
    }

    public record UpdateDeliveryStatusRequest(
        String status,
        String deliveryPartner
    ) {
    }
}
