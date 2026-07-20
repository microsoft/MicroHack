package com.octocat.supply.model;

public final class SupplierModel {
    private SupplierModel() {
    }

    public record Supplier(
        int supplierId,
        String name,
        String description,
        String contactPerson,
        String email,
        String phone,
        boolean active,
        boolean verified
    ) {
    }

    public record CreateSupplierRequest(
        String name,
        String description,
        String contactPerson,
        String email,
        String phone,
        Boolean active,
        Boolean verified
    ) {
    }

    public record UpdateSupplierRequest(
        String name,
        String description,
        String contactPerson,
        String email,
        String phone,
        Boolean active,
        Boolean verified
    ) {
    }
}
