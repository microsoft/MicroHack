package com.octocat.supply.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Value("${app.cors-origins:}")
    private String configuredOrigins;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        var registration = registry.addMapping("/**")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
            .allowedHeaders("*")
            .allowCredentials(true);

        if (configuredOrigins != null && !configuredOrigins.isBlank()) {
            registration.allowedOrigins(Arrays.stream(configuredOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toArray(String[]::new));
            return;
        }

        List<String> defaultPatterns = new ArrayList<>();
        defaultPatterns.add("http://localhost:*");
        defaultPatterns.add("http://127.0.0.1:*");
        defaultPatterns.add("https://*.app.github.dev");
        defaultPatterns.add("https://*.azurecontainerapps.io");
        registration.allowedOriginPatterns(defaultPatterns.toArray(String[]::new));
    }
}
