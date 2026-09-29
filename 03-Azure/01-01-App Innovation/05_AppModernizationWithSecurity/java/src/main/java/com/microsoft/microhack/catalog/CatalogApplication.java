package com.microsoft.microhack.catalog;

import com.microsoft.microhack.catalog.config.CatalogRuntimeOptions;
import com.microsoft.microhack.catalog.config.CatalogResourceIdentity;
import io.opentelemetry.sdk.autoconfigure.AutoConfiguredOpenTelemetrySdk;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender;
import java.net.InetAddress;
import java.net.UnknownHostException;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

/** Starts the intentionally monolithic catalog application. */
@SpringBootApplication
public class CatalogApplication {

    public static void main(String[] args) {
        SpringApplication.run(CatalogApplication.class, args);
    }

    /** Loads and validates the complete frozen runtime configuration. */
    @Bean
    CatalogRuntimeOptions catalogRuntimeOptions(Environment environment) {
        return CatalogRuntimeOptions.from(environment, instanceId());
    }

    /** Initializes the OpenTelemetry SDK using standard OTEL environment variables. */
    @Bean(destroyMethod = "close")
    OpenTelemetrySdk openTelemetry(CatalogRuntimeOptions options) {
        System.setProperty("otel.exporter.otlp.endpoint", options.otlpEndpoint());
        System.setProperty(
                "otel.resource.attributes",
                CatalogResourceIdentity.asOtelProperty(options));
        OpenTelemetrySdk sdk = AutoConfiguredOpenTelemetrySdk.builder()
                .build()
                .getOpenTelemetrySdk();
        OpenTelemetryAppender.install(sdk);
        return sdk;
    }

    private static String instanceId() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException exception) {
            throw new IllegalStateException("service.instance.id could not be determined", exception);
        }
    }
}
