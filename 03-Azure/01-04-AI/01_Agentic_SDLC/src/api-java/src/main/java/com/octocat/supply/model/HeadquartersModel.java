package com.octocat.supply.model;

public final class HeadquartersModel {
    private HeadquartersModel() {
    }

    public record Headquarters(
        int headquartersId,
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }

    public record CreateHeadquartersRequest(
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }

    public record UpdateHeadquartersRequest(
        String name,
        String description,
        String address,
        String contactPerson,
        String email,
        String phone
    ) {
    }

    public record HeadquartersMetrics(
        int score,
        double average,
        String display
    ) {
    }
}
