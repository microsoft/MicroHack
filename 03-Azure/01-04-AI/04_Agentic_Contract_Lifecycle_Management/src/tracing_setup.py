"""Challenge 3 — Tracing / observability setup.

Turns on the **Microsoft Agent Framework's** built-in OpenTelemetry
instrumentation and ships spans to Application Insights, so you can inspect
prompt / retrieval / tool spans in the Foundry portal (Tracing + Agent
Monitoring Dashboard). Traces span every agent in the GPT fleet — one pane of
glass across the orchestrator and specialists.

IMPORTANT: content-recording flag must be set BEFORE the agent framework is
imported anywhere, so import this module (or call enable_tracing()) at the very
top of your entry point.

Usage:
    import tracing_setup            # sets the env flag on import
    tracing_setup.enable_tracing()  # wires the exporter (call once at startup)
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# Record prompt/tool payloads on spans. Agent Framework reads ENABLE_SENSITIVE_DATA;
# the Azure GenAI variable is kept for the underlying Azure OpenAI instrumentation.
os.environ.setdefault("ENABLE_SENSITIVE_DATA", "true")
os.environ.setdefault("AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED", "true")

sys.path.insert(0, str(Path(__file__).resolve().parent))  # src (clm_common)

from clm_common.config import settings  # noqa: E402

_ENABLED = False


def enable_tracing(project=None) -> None:
    """Configure Azure Monitor + turn on Agent Framework instrumentation. Safe to call once.

    :param project: optional AIProjectClient — used to fetch the App Insights
        connection string from the project if it isn't already in the env.
    """
    global _ENABLED
    if _ENABLED:
        return

    conn = settings.appinsights_connection_string
    if not conn and project is not None:
        conn = project.telemetry.get_application_insights_connection_string()

    if not conn:
        print("⚠️  No Application Insights connection string. Set "
              "APPLICATIONINSIGHTS_CONNECTION_STRING in .env (Challenge 1 sets this).")
        return

    from azure.monitor.opentelemetry import configure_azure_monitor
    from agent_framework.observability import enable_instrumentation

    # 1) Register Azure Monitor exporters on the global OTel providers.
    configure_azure_monitor(connection_string=conn)
    # 2) Emit Agent Framework's invoke_agent / chat / execute_tool spans on them.
    enable_instrumentation(enable_sensitive_data=True)
    _ENABLED = True
    print("✓ Tracing enabled → Application Insights (content recording ON).")


if __name__ == "__main__":
    from clm_common.foundry import get_project_client

    with get_project_client() as project:
        enable_tracing(project)
        print("Run an agent now, then view spans in the Foundry portal — New Foundry: "
              "Build → your agent/model → Monitor; classic: project → Tracing.")
