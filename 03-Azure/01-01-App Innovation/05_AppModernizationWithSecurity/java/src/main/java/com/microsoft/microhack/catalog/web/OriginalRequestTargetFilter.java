package com.microsoft.microhack.catalog.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Locale;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Rejects unsafe original request targets before Tomcat can map aliases to valid routes. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class OriginalRequestTargetFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        if (isUnsafe(request.getRequestURI())) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        filterChain.doFilter(request, response);
    }

    static boolean isUnsafe(String requestUri) {
        String normalized = requestUri.toLowerCase(Locale.ROOT);
        if (normalized.indexOf('\\') >= 0
                || normalized.contains("%2f")
                || normalized.contains("%5c")
                || normalized.contains("%25")) {
            return true;
        }
        String decodedDots = normalized
                .replace("%2e", ".")
                .replace("%252e", ".");
        for (String segment : decodedDots.split("/", -1)) {
            if (".".equals(segment) || "..".equals(segment)) {
                return true;
            }
        }
        return false;
    }
}
