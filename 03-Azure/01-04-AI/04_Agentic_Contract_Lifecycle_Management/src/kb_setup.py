"""Challenge 2 — Foundry IQ knowledge grounding setup.

Foundry IQ wraps the clm-corpus Azure AI Search index in a reusable knowledge
source and knowledge base. Its MCP tool performs query planning, parallel
retrieval, semantic reranking, and citation-aware grounding.

Existing environments that don't define FOUNDRY_IQ_KNOWLEDGE_BASE retain the
direct Azure AI Search tool as a compatibility fallback.

Run standalone to verify your connection + index:
    python src/kb_setup.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # src (clm_common)

from clm_common.config import settings  # noqa: E402


def _to_jsonable(value):
    """Recursively convert an SDK/model object into JSON-native primitives.

    Walks ``value`` into plain ``dict`` / ``list`` / scalar values so that a later
    ``json.dumps`` can never raise. Nested Azure SDK models are converted via
    ``as_dict()`` (re-walked in case that method is only shallow), pydantic models
    via ``model_dump()``, and any other mapping-like object via ``items()``; a
    non-serializable leaf falls back to ``str`` as a last resort so serialization
    always succeeds.
    """
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, dict):
        return {str(k): _to_jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_to_jsonable(v) for v in value]
    # azure.core / azure.ai.projects models expose as_dict(); it is not always
    # fully recursive across SDK versions, so re-walk whatever it returns.
    as_dict = getattr(value, "as_dict", None)
    if callable(as_dict):
        try:
            return _to_jsonable(as_dict())
        except Exception:  # noqa: BLE001 — try the next strategy instead of failing
            pass
    model_dump = getattr(value, "model_dump", None)  # pydantic v2 tool models
    if callable(model_dump):
        try:
            return _to_jsonable(model_dump(mode="python"))
        except Exception:  # noqa: BLE001
            pass
    items = getattr(value, "items", None)  # generic mapping-like objects
    if callable(items):
        try:
            return {str(k): _to_jsonable(v) for k, v in value.items()}
        except Exception:  # noqa: BLE001
            pass
    return str(value)


def _normalize_foundry_tool(tool):
    """Return a Foundry tool as a plain, **fully** JSON-serializable dict.

    The Foundry tool factories (``get_azure_ai_search_tool`` /
    ``get_bing_grounding_tool``) return ``azure.ai.projects.models`` objects
    (``AzureAISearchTool`` wrapping an ``AzureAISearchToolResource``,
    ``BingGroundingTool``, …). Those are dict-*like* SDK models but NOT ``dict``
    subclasses, so ``json.dumps`` raises e.g. ``Object of type
    AzureAISearchToolResource is not JSON serializable``. The Agent Framework
    serializes an agent's tools in **two** places: the request payload sent to the
    model, AND the OpenTelemetry span attributes emitted for Challenge 3 tracing
    (``gen_ai.tool.definitions``). On agent-framework-core ≤ 1.11.x the tracing
    ``json.dumps`` is unguarded, so a raw tool object aborts ``agent.run()`` with
    that exact ``TypeError``.

    ``_to_jsonable`` deep-converts the tool into nested plain ``dict``/``list``
    values (keeping the ``type`` discriminator the Agent needs), so it serializes
    cleanly on every code path and framework version — even when a given SDK
    model's ``as_dict()`` is only shallow, or a future tool type lacks it.
    """
    if tool is None:
        return None
    return _to_jsonable(tool)


def get_search_connection_id(project) -> str:
    """Return the connection id of the project's default Azure AI Search resource."""
    from azure.ai.projects.models import ConnectionType

    conn = project.connections.get_default(ConnectionType.AZURE_AI_SEARCH)
    return conn.id


def build_knowledge_tool(*, connection_id: str | None = None, project=None):
    """Build the Foundry IQ MCP tool, or the legacy direct Search fallback.

    Pass ``connection_id`` to skip resolution (cheap, no network — handy when
    rebuilding the tool per call), or ``project`` to resolve it from an existing
    AIProjectClient. With neither, a short-lived project client is opened to look
    up the default Azure AI Search connection.

    Returns a Foundry tool object ready to drop into an ``Agent``'s ``tools=[...]``.
    """
    if settings.foundry_iq_enabled:
        from azure.ai.projects.models import MCPTool
        from clm_common.foundry_iq import mcp_tool_kwargs

        return _normalize_foundry_tool(MCPTool(**mcp_tool_kwargs()))

    from agent_framework.foundry import FoundryChatClient
    if connection_id is None:
        if project is not None:
            connection_id = get_search_connection_id(project)
        else:
            from clm_common.foundry import get_project_client

            with get_project_client() as own_project:
                connection_id = get_search_connection_id(own_project)

    return _normalize_foundry_tool(
        FoundryChatClient.get_azure_ai_search_tool(
            index_connection_id=connection_id,
            index_name=settings.search_index,
            query_type="semantic",
            top_k=5,
        )
    )


def get_bing_connection_id(project) -> str:
    """Return the connection id of the Grounding-with-Bing-Search connection.

    Resolved by NAME (``AZURE_BING_CONNECTION_NAME``) because Foundry has no
    dedicated Bing connection *type* — a Grounding with Bing Search resource
    surfaces as a generic project connection. Raises if the name is unset.
    """
    if not settings.bing_connection_name:
        raise RuntimeError(
            "AZURE_BING_CONNECTION_NAME is not set. Provision a 'Grounding with Bing "
            "Search' resource, add it as a project connection, then set the env var "
            "(or set AZURE_BING_CONNECTION_ID directly)."
        )
    return project.connections.get(name=settings.bing_connection_name).id


def build_web_search_tool(*, connection_id: str | None = None, project=None):
    """Build the Foundry web-grounding tool (Grounding with Bing Search), or None.

    This is the SINGLE place web grounding is constructed for the whole repo. When
    you get Web IQ access, swap ONLY this function's body to return the Web IQ tool
    and every agent picks it up unchanged — no agent or config edits needed.

    Returns ``None`` when no Bing connection is configured (``web_search_enabled``
    is False), so agents stay runnable with zero web setup. Pass ``connection_id``
    to skip resolution, or ``project`` to resolve from an existing AIProjectClient;
    with neither, a short-lived project client resolves the connection by name.
    """
    if not settings.web_search_enabled:
        return None

    from agent_framework.foundry import FoundryChatClient

    connection_id = connection_id or settings.bing_connection_id
    if connection_id is None:
        if project is not None:
            connection_id = get_bing_connection_id(project)
        else:
            from clm_common.foundry import get_project_client

            with get_project_client() as own_project:
                connection_id = get_bing_connection_id(own_project)

    # Grounding with Bing Search (preview) — works on any Foundry model (incl.
    # non-OpenAI models) and exposes finer Bing params than the GA
    # get_web_search_tool (which is Azure-OpenAI-only).
    return _normalize_foundry_tool(
        FoundryChatClient.get_bing_grounding_tool(
            connection_id=connection_id,
            count=5,
        )
    )


def main() -> None:
    from clm_common.foundry import get_project_client

    with get_project_client() as project:
        conn_id = None
        if not settings.foundry_iq_enabled:
            conn_id = get_search_connection_id(project)
            print("✓ Default Azure AI Search connection:", conn_id)
        print("✓ Index:", settings.search_index)
        build_knowledge_tool(connection_id=conn_id)
        if settings.foundry_iq_enabled:
            print("✓ Foundry IQ knowledge base:", settings.foundry_iq_knowledge_base)
            print("✓ Built Foundry IQ MCP tool (knowledge_base_retrieve).")
        else:
            print("✓ Built direct Azure AI Search fallback (semantic, top_k=5).")
        if settings.web_search_enabled:
            build_web_search_tool(project=project)
            print("✓ Built Foundry web-grounding tool (Grounding with Bing Search).")
        else:
            print("• Web search off (set AZURE_BING_CONNECTION_NAME to enable).")


if __name__ == "__main__":
    main()
