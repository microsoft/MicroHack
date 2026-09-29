package com.microsoft.microhack.catalog.config;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/** Provides the complete frozen OpenTelemetry resource identity from one source. */
public final class CatalogResourceIdentity {

    private CatalogResourceIdentity() {
    }

    public static Map<String, String> attributes(CatalogRuntimeOptions options) {
        Map<String, String> attributes = new LinkedHashMap<>();
        attributes.put("service.name", CatalogRuntimeOptions.SERVICE_NAME);
        attributes.put("service.namespace", CatalogRuntimeOptions.SERVICE_NAMESPACE);
        attributes.put("service.version", options.serviceVersion());
        attributes.put("deployment.environment", options.deploymentEnvironment());
        attributes.put("service.instance.id", options.serviceInstanceId());
        attributes.put("azure.containerapps.revision.name", options.revisionName());
        return Map.copyOf(attributes);
    }

    public static String asOtelProperty(CatalogRuntimeOptions options) {
        return attributes(options).entrySet().stream()
                .map(entry -> entry.getKey() + "=" + entry.getValue())
                .collect(Collectors.joining(","));
    }
}
