from __future__ import annotations

import logging
import os
from contextlib import contextmanager
from typing import Iterator

from opentelemetry import trace


logger = logging.getLogger("mcp_hr_server")
tracer = trace.get_tracer("workshop.mcp_hr_server")


def configure_telemetry() -> None:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
    logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)
    logging.getLogger("azure.monitor.opentelemetry").setLevel(logging.WARNING)
    if not os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
        logger.info("Application Insights not configured; using local OpenTelemetry no-op exporter.")
        return
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor()
        logger.info("Application Insights telemetry configured.")
    except Exception as exc:
        logger.warning("Application Insights telemetry configuration failed: %s", exc)


@contextmanager
def tool_span(tool_name: str) -> Iterator[None]:
    with tracer.start_as_current_span("mcp.tool_call") as span:
        span.set_attribute("mcp.tool.name", tool_name)
        try:
            yield
            span.set_attribute("mcp.tool.success", True)
        except Exception as exc:
            span.set_attribute("mcp.tool.success", False)
            span.set_attribute("mcp.tool.error_type", type(exc).__name__)
            raise
