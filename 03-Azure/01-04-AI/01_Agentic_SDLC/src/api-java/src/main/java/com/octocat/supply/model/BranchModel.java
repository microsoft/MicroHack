package com.octocat.supply.model;

public final class BranchModel {
    private BranchModel() {
    }

    public record Branch(
        int branchId,
        int headquartersId,
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }

    public record CreateBranchRequest(
        Integer headquartersId,
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }

    public record UpdateBranchRequest(
        Integer headquartersId,
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }
}
