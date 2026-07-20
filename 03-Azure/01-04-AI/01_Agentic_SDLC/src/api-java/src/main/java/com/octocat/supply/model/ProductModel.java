package com.octocat.supply.model;

public final class ProductModel {
    private ProductModel() {
    }

    public record Product(
        int productId,
        int supplierId,
        String name,
        String description,
        double price,
        String sku,
        String unit,
        String imgName,
        double discount
    ) {
    }

    public record CreateProductRequest(
        Integer supplierId,
        String name,
        String description,
        Double price,
        String sku,
        String unit,
        String imgName,
        Double discount
    ) {
    }

    public record UpdateProductRequest(
        Integer supplierId,
        String name,
        String description,
        Double price,
        String sku,
        String unit,
        String imgName,
        Double discount
    ) {
    }
}
