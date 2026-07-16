package com.octocat.supply.repository;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

final class SqlUpdateBuilder {
    private final List<String> sets = new ArrayList<>();
    private final List<Object> args = new ArrayList<>();

    void add(String column, Object value) {
        if (value != null) {
            sets.add(column + " = ?");
            args.add(value);
        }
    }

    boolean isEmpty() {
        return sets.isEmpty();
    }

    UpdateStatement build(String table, String idColumn, int idValue) {
        String sql = "UPDATE " + table + " SET " + String.join(", ", sets) + " WHERE " + idColumn + " = ?";
        List<Object> fullArgs = new ArrayList<>(args);
        fullArgs.add(idValue);
        return new UpdateStatement(sql, fullArgs.toArray());
    }

    record UpdateStatement(String sql, Object[] args) {
        int executeWith(org.springframework.jdbc.core.JdbcTemplate jdbcTemplate) {
            return jdbcTemplate.update(sql, args);
        }
    }

    static boolean executeIfPresent(Consumer<SqlUpdateBuilder> binder, String table, String idColumn, int idValue,
                                    org.springframework.jdbc.core.JdbcTemplate jdbcTemplate) {
        SqlUpdateBuilder builder = new SqlUpdateBuilder();
        binder.accept(builder);
        if (builder.isEmpty()) {
            return false;
        }
        return builder.build(table, idColumn, idValue).executeWith(jdbcTemplate) > 0;
    }
}
