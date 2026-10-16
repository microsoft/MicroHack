package com.microsoft.microhack.catalog.web;

import com.microsoft.microhack.catalog.service.CatalogTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.filter.OncePerRequestFilter;

/** Emits standard HTTP server span attributes and one structured completion log. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class RequestTelemetryFilter extends OncePerRequestFilter {

    private static final Logger LOGGER = LoggerFactory.getLogger(RequestTelemetryFilter.class);
    private final CatalogTelemetry telemetry;

    public RequestTelemetryFilter(CatalogTelemetry telemetry) {
        this.telemetry = telemetry;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        long started = System.nanoTime();
        Span span = telemetry.startHttpServerSpan();
        span.setAttribute("http.request.method", request.getMethod());
        span.setAttribute("server.address", request.getServerName());
        try (var scope = span.makeCurrent()) {
            filterChain.doFilter(request, response);
        } catch (IOException | ServletException | RuntimeException exception) {
            span.setStatus(StatusCode.ERROR);
            span.recordException(exception);
            CatalogTelemetry.exception(LOGGER, exception);
            if (!response.isCommitted()) {
                response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            }
            throw exception;
        } finally {
            int status = response.getStatus();
            String route = matchedRoute(request);
            if (route != null) {
                span.setAttribute("http.route", route);
            }
            span.setAttribute("http.response.status_code", status);
            telemetry.recordHttp(
                    (System.nanoTime() - started) / 1_000_000_000.0,
                    request.getMethod(),
                    route,
                    status);
            Map<String, Object> fields = new java.util.LinkedHashMap<>();
            fields.put("http.request.method", request.getMethod());
            if (route != null) {
                fields.put("http.route", route);
            }
            fields.put("http.response.status_code", status);
            CatalogTelemetry.log(LOGGER, "http.server.request", fields);
            span.end();
        }
    }

    private static String matchedRoute(HttpServletRequest request) {
        Object pattern = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
        return pattern == null ? null : pattern.toString();
    }
}
