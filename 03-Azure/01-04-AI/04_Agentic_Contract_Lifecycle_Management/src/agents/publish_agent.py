"""Publish the CLM specialist agents to Microsoft Foundry Agent Service.

WHY THIS EXISTS
    The specialist agents (`intake_drafting_agent.py`, `clause_risk_agent.py`,
    `obligation_renewal_agent.py`) are built with a `FoundryChatClient`, which
    runs the whole tool-calling loop **in your process** — great for scripts and
    CI, but the agents are never registered server-side, so they do NOT appear in
    the Microsoft Foundry portal's **Agents** list or **Playground**.

    This script publishes the SAME agents (name, instructions, model deployment
    and their grounding / function tools) as **persistent Foundry agent versions**
    via `AIProjectClient.agents.create_version(...)`. Once published they show up
    in portal → **Agents**, and you can open any of them in the **Playground** to
    run prompts and take screenshots.

WHICH AGENTS
    - intake-drafting-agent    (gpt-5.4)      — Foundry IQ grounding + get_contract_status
    - clause-risk-agent        (gpt-5.6-sol)  — Foundry IQ grounding (+ Bing web search if configured)
    - obligation-renewal-agent (gpt-5.4-nano) — get_contract_status + list_upcoming_renewals

    The Challenge 4 **orchestrator** is a *composition* of these specialists
    (it calls them as tools, in-process) — it is not a standalone prompt agent,
    so it is intentionally not published here; run it with `python src/orchestrator.py`.

CAVEAT — function tools are client-side
    `get_contract_status` / `list_upcoming_renewals` are local Python functions.
    They execute only when YOU run a demo script; the portal cannot call your
    machine. They are still published as tool *definitions* (so each agent's
    config faithfully shows them), and in the Playground the model will REQUEST
    the call and let you paste the result — but the grounded, cited answers and
    the refusal guardrail all work fully in the Playground on their own.

Run (use the same Python you run the demos with):
    python src/agents/publish_agent.py                             # publish ALL specialist agents
    python src/agents/publish_agent.py --agent clause-risk-agent   # publish just one
    python src/agents/publish_agent.py --list                      # show published versions
    python src/agents/publish_agent.py --delete                    # remove them (cleanup)
    python src/agents/publish_agent.py --no-function-tool          # knowledge-only (cleanest Playground demo)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))          # src (clm_common, kb_setup)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "agents"))  # sibling agent modules

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import get_project_client  # noqa: E402
from kb_setup import get_bing_connection_id, get_search_connection_id  # noqa: E402

# Single source of truth: reuse the exact name + persona each in-process agent uses.
import intake_drafting_agent as _intake  # noqa: E402
import clause_risk_agent as _clause_risk  # noqa: E402
import obligation_renewal_agent as _renewal  # noqa: E402

# JSON schema for the function tools, mirroring the Python signatures in clm_common/tools.py.
_GET_CONTRACT_STATUS_TOOL = {
    "name": "get_contract_status",
    "description": (
        "Look up a contract's status, renewal date, risk and owner by its ID "
        "(e.g. 'CT-4821'). Use this instead of guessing these facts."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "contract_id": {
                "type": "string",
                "description": "The contract identifier, e.g. 'CT-4821'.",
            }
        },
        "required": ["contract_id"],
        "additionalProperties": False,
    },
    "strict": True,
}

_LIST_UPCOMING_RENEWALS_TOOL = {
    "name": "list_upcoming_renewals",
    "description": (
        "List contracts whose renewal date falls within the next N days, sorted "
        "by renewal date. Use this to find what is coming due."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "within_days": {
                "type": "integer",
                "description": "Look-ahead window in days (e.g. 90).",
            }
        },
        "required": ["within_days"],
        "additionalProperties": False,
    },
    "strict": True,
}


def _knowledge_tool(connection_id: str | None):
    """Build the Foundry IQ MCP tool, or the direct Search compatibility fallback."""
    if settings.foundry_iq_enabled:
        from azure.ai.projects.models import MCPTool
        from clm_common.foundry_iq import mcp_tool_kwargs

        return MCPTool(**mcp_tool_kwargs())

    from azure.ai.projects.models import (
        AISearchIndexResource,
        AzureAISearchTool,
        AzureAISearchToolResource,
    )

    return AzureAISearchTool(
        azure_ai_search=AzureAISearchToolResource(
            indexes=[
                AISearchIndexResource(
                    project_connection_id=connection_id,
                    index_name=settings.search_index,
                    query_type="semantic",
                    top_k=5,
                )
            ]
        )
    )


def _function_tool(schema: dict):
    from azure.ai.projects.models import FunctionTool

    return FunctionTool(**schema)


def _bing_tool(bing_connection_id: str):
    """Grounding with Bing Search — mirrors build_web_search_tool (count=5)."""
    from azure.ai.projects.models import (
        BingGroundingSearchConfiguration,
        BingGroundingSearchToolParameters,
        BingGroundingTool,
    )

    return BingGroundingTool(
        bing_grounding=BingGroundingSearchToolParameters(
            search_configurations=[
                BingGroundingSearchConfiguration(
                    project_connection_id=bing_connection_id,
                    count=5,
                )
            ]
        )
    )


class _Ctx:
    """Resolved connections shared while building the agent definitions."""

    def __init__(self, project):
        self.search_connection_id = (
            None if settings.foundry_iq_enabled else get_search_connection_id(project)
        )
        self.bing_connection_id = None
        if settings.web_search_enabled:
            try:
                self.bing_connection_id = get_bing_connection_id(project)
            except Exception as exc:  # noqa: BLE001 — publish corpus-only if Bing won't resolve
                print(
                    f"• Bing web search is configured but the connection didn't resolve "
                    f"({type(exc).__name__}); publishing clause-risk-agent corpus-only."
                )


class _Spec:
    """One publishable agent: its portal name, model, persona and tool builder."""

    def __init__(self, key, module, model, description, build_tools):
        self.key = key
        self.name = module.AGENT_NAME
        self.instructions = module.INSTRUCTIONS
        self.model = model
        self.description = description
        self._build_tools = build_tools

    def tools(self, ctx: "_Ctx", *, include_function_tool: bool):
        return self._build_tools(ctx, include_function_tool)


def _intake_tools(ctx: _Ctx, include_function_tool: bool):
    tools = [_knowledge_tool(ctx.search_connection_id)]
    if include_function_tool:
        tools.append(_function_tool(_GET_CONTRACT_STATUS_TOOL))
    return tools


def _clause_risk_tools(ctx: _Ctx, include_function_tool: bool):
    tools = [_knowledge_tool(ctx.search_connection_id)]
    if ctx.bing_connection_id:
        tools.append(_bing_tool(ctx.bing_connection_id))
    return tools


def _renewal_tools(ctx: _Ctx, include_function_tool: bool):
    if not include_function_tool:
        return []
    return [
        _function_tool(_GET_CONTRACT_STATUS_TOOL),
        _function_tool(_LIST_UPCOMING_RENEWALS_TOOL),
    ]


SPECS = [
    _Spec(
        "intake-drafting-agent",
        _intake,
        settings.model_drafting,
        "Challenge 2 — grounded, cited, tool-enabled, guard-railed drafting agent (gpt-5.4).",
        _intake_tools,
    ),
    _Spec(
        "clause-risk-agent",
        _clause_risk,
        settings.model_clause_risk,
        "Challenge 4 — clause extraction & risk scoring vs the enterprise standard (gpt-5.6-sol).",
        _clause_risk_tools,
    ),
    _Spec(
        "obligation-renewal-agent",
        _renewal,
        settings.model_renewal,
        "Challenge 5 — scans upcoming renewals & obligations (gpt-5.4-nano).",
        _renewal_tools,
    ),
]


def _selected(only: str | None) -> list[_Spec]:
    if only is None:
        return SPECS
    picked = [s for s in SPECS if s.key == only]
    if not picked:
        known = ", ".join(s.key for s in SPECS)
        raise SystemExit(f"Unknown --agent '{only}'. Choose one of: {known}")
    return picked


def publish(*, only: str | None = None, include_function_tool: bool = True) -> None:
    from azure.ai.projects.models import PromptAgentDefinition

    specs = _selected(only)
    with get_project_client() as project:
        ctx = _Ctx(project)
        for spec in specs:
            tools = spec.tools(ctx, include_function_tool=include_function_tool)
            definition = PromptAgentDefinition(
                model=spec.model,
                instructions=spec.instructions,
                tools=tools or None,
            )
            version = project.agents.create_version(
                agent_name=spec.name,
                definition=definition,
                description=spec.description,
            )
            v = getattr(version, "version", "?")
            print(f"✓ Published '{spec.name}' (version {v}) on '{spec.model}'.")

    portal = settings.require_project().split("/api/projects/")[0]
    print("\nOpen them in the portal → Agents → <name> → Playground:")
    print(f"    {portal}  →  your project  →  Agents")
    if include_function_tool:
        print("  Note: get_contract_status / list_upcoming_renewals run client-side; in the")
        print("        Playground the model requests the call and you paste the result. Grounded")
        print("        Q&A / drafting / risk analysis / refusal all work as-is.")


def list_versions(*, only: str | None = None) -> None:
    with get_project_client() as project:
        for spec in _selected(only):
            try:
                details = project.agents.get(spec.name)
            except Exception as exc:  # noqa: BLE001 — friendly "not published yet" message
                print(f"• '{spec.name}' is not published yet ({type(exc).__name__}).")
                continue
            print(f"✓ '{spec.name}':", getattr(details, "description", "") or "(no description)")
            for v in project.agents.list_versions(spec.name):
                print("   - version", getattr(v, "version", "?"))


def delete(*, only: str | None = None) -> None:
    with get_project_client() as project:
        for spec in _selected(only):
            try:
                project.agents.delete(spec.name)
                print(f"✓ Deleted '{spec.name}'.")
            except Exception as exc:  # noqa: BLE001 — ignore "not found", keep going
                print(f"• '{spec.name}' not deleted ({type(exc).__name__}) — probably not published.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--list", action="store_true", help="show published versions of the agents")
    group.add_argument("--delete", action="store_true", help="delete the published agents (cleanup)")
    parser.add_argument(
        "--agent",
        choices=[s.key for s in SPECS],
        default=None,
        help="act on just this agent instead of all of them",
    )
    parser.add_argument(
        "--no-function-tool",
        action="store_true",
        help="publish with knowledge grounding only (cleanest Playground demo)",
    )
    args = parser.parse_args()

    if args.list:
        list_versions(only=args.agent)
    elif args.delete:
        delete(only=args.agent)
    else:
        publish(only=args.agent, include_function_tool=not args.no_function_tool)


if __name__ == "__main__":
    main()
