"""Challenge 2 (optional) — publish the Intake & Drafting agent to Foundry Agent Service.

WHY THIS EXISTS
    `intake_drafting_agent.py` builds the agent with a `FoundryChatClient`, which runs
    the whole tool-calling loop **in your process** — great for scripts and CI, but the
    agent is never registered server-side, so it does NOT appear in the Microsoft Foundry
    portal's **Agents** list or **Playground**.

    This script publishes the SAME agent (name, instructions, gpt-5.4 deployment and the
    Foundry IQ / Azure AI Search grounding tool) as a **persistent Foundry agent version**
    via `AIProjectClient.agents.create_version(...)`. Once published it shows up in
    portal → **Agents**, and you can open it in the **Playground** to run the Challenge 2
    sample prompts and take the Task 4 screenshots.

CAVEAT — the function tool is client-side
    `get_contract_status` is a local Python function. It executes only when YOU run the
    demo script; the portal cannot call your machine. It is still published as a tool
    *definition* (so the agent's config faithfully shows it), and in the Playground the
    model will REQUEST the call and let you paste the result — but the grounded, cited
    drafting / Q&A / refusal behaviours all work fully in the Playground on their own.

Run (use the same Python you run the demo with):
    python src/agents/publish_agent.py            # create / update the portal agent
    python src/agents/publish_agent.py --list     # show published versions
    python src/agents/publish_agent.py --delete   # remove it (cleanup)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))          # src (clm_common, kb_setup)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "agents"))  # sibling agent modules

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import get_project_client  # noqa: E402
from kb_setup import get_search_connection_id  # noqa: E402

# Single source of truth: reuse the exact name + persona the in-process agent uses.
from intake_drafting_agent import AGENT_NAME, INSTRUCTIONS  # noqa: E402

# JSON schema for the function tool, mirroring get_contract_status(contract_id: str).
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


def _build_definition(connection_id: str, *, include_function_tool: bool):
    """Build the PromptAgentDefinition that mirrors the in-process Intake & Drafting agent."""
    from azure.ai.projects.models import (
        AISearchIndexResource,
        AzureAISearchTool,
        AzureAISearchToolResource,
        FunctionTool,
        PromptAgentDefinition,
    )

    # Foundry IQ grounding over the clm-corpus index (same params as build_knowledge_tool).
    knowledge = AzureAISearchTool(
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

    tools = [knowledge]
    if include_function_tool:
        tools.append(FunctionTool(**_GET_CONTRACT_STATUS_TOOL))

    return PromptAgentDefinition(
        model=settings.model_drafting,  # gpt-5.4
        instructions=INSTRUCTIONS,
        tools=tools,
    )


def publish(*, include_function_tool: bool = True) -> None:
    with get_project_client() as project:
        connection_id = get_search_connection_id(project)
        definition = _build_definition(connection_id, include_function_tool=include_function_tool)
        version = project.agents.create_version(
            agent_name=AGENT_NAME,
            definition=definition,
            description="Challenge 2 — grounded, cited, tool-enabled, guard-railed drafting agent (gpt-5.4).",
        )

    portal = settings.require_project().split("/api/projects/")[0]
    print(f"✓ Published '{AGENT_NAME}' (version {getattr(version, 'version', '?')}) on '{settings.model_drafting}'.")
    print("  Foundry IQ grounding over index:", settings.search_index)
    print("  Open it in the portal → Agents →", AGENT_NAME, "→ Playground, e.g.:")
    print(f"    {portal}  →  your project  →  Agents")
    if include_function_tool:
        print("  Note: get_contract_status runs client-side; in the Playground the model will")
        print("        request it and let you paste the result. Grounded Q&A / drafting / refusal work as-is.")


def list_versions() -> None:
    with get_project_client() as project:
        try:
            details = project.agents.get(AGENT_NAME)
        except Exception as exc:  # noqa: BLE001 — friendly "not published yet" message
            print(f"• '{AGENT_NAME}' is not published yet ({type(exc).__name__}). Run without flags to create it.")
            return
        print(f"✓ Agent '{AGENT_NAME}':", getattr(details, "description", "") or "(no description)")
        for v in project.agents.list_versions(AGENT_NAME):
            print("   - version", getattr(v, "version", "?"))


def delete() -> None:
    with get_project_client() as project:
        project.agents.delete(AGENT_NAME)
    print(f"✓ Deleted '{AGENT_NAME}' from Foundry Agent Service.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--list", action="store_true", help="show published versions of the agent")
    group.add_argument("--delete", action="store_true", help="delete the published agent (cleanup)")
    parser.add_argument(
        "--no-function-tool",
        action="store_true",
        help="publish with knowledge grounding only (cleanest Playground demo)",
    )
    args = parser.parse_args()

    if args.list:
        list_versions()
    elif args.delete:
        delete()
    else:
        publish(include_function_tool=not args.no_function_tool)


if __name__ == "__main__":
    main()
