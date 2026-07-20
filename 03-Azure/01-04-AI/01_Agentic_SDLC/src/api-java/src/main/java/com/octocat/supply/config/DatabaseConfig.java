package com.octocat.supply.config;

import org.sqlite.SQLiteConfig;
import org.sqlite.SQLiteDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Configuration
public class DatabaseConfig {
    @Bean
    public DataSource dataSource(@Value("${app.db-file}") String dbFile) throws Exception {
        String resolvedDbFile = dbFile;
        if (!":memory:".equals(dbFile)) {
            Path dbPath = Paths.get(dbFile).toAbsolutePath().normalize();
            Path parent = dbPath.getParent();
            if (parent != null) {
                Files.createDirectories(parent);
            }
            resolvedDbFile = dbPath.toString();
        }

        SQLiteConfig config = new SQLiteConfig();
        config.enforceForeignKeys(true);
        config.setBusyTimeout(30000);
        config.setJournalMode(SQLiteConfig.JournalMode.WAL);

        SQLiteDataSource dataSource = new SQLiteDataSource(config);
        dataSource.setUrl("jdbc:sqlite:" + resolvedDbFile);
        return dataSource;
    }
}
