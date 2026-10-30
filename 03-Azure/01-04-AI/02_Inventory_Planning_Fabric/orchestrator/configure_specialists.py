"""Reuse one existing Fabric IQ connection and pin the resulting specialist versions."""

import argparse
from copy import deepcopy
import json
import os
from pathlib import Path
import re
from typing import Any
from urllib.parse import urlsplit

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import FabricIQPreviewToolboxTool, PromptAgentDefinition
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import AzureCliCredential

from verify_configuration import validate_definition


STAGES = ("DEMAND", "OPTIMISATION", "REPLENISHMENT")
TOOLBOX_NAME = "inventory-fabric-iq"


def validate_connection(connection_id: str, target: str, project_id: str) -> None:
    prefix = project_id.rstrip("/") + "/connections/"
    if not connection_id.lower().startswith(prefix.lower()):
        raise ValueError("Fabric IQ connection must belong to the deployment project.")
    url = urlsplit(target)
    guid = r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
    fabric_host = r"(?:api\.fabric\.microsoft\.com|[a-z0-9.-]+\.w\.api\.fabric\.microsoft\.com)"
    if (
        url.scheme != "https" or not re.fullmatch(fabric_host, url.netloc)
        or not re.fullmatch(rf"/v1/mcp/workspaces/{guid}/dataagents/{guid}/agent", url.path)
        or url.query or url.fragment
    ):
        raise ValueError("Connection must target a published Fabric Data Agent MCP endpoint.")


def with_fabric_iq(definition: dict[str, Any], connection_id: str) -> dict[str, Any]:
    if definition.get("kind") != "prompt":
        raise ValueError("Only prompt specialists can be configured.")
    updated = deepcopy(definition)
    updated["tools"] = [
        tool for tool in updated.get("tools", [])
        if tool["type"] not in {"fabric_dataagent_preview", "fabric_iq_preview"}
    ] + [{
        "type": "fabric_iq_preview", "project_connection_id": connection_id,
        "require_approval": "never",
    }]
    validate_definition("specialist", updated)
    return updated


def configure(project: AIProjectClient, connection_name: str, project_id: str,
              sources: dict[str, tuple[str, str]]) -> dict[str, str]:
    if len({name for name, _ in sources.values()}) != len(STAGES):
        raise ValueError("Provide three distinct specialist names.")
    connection = project.connections.get(connection_name, include_credentials=False)
    validate_connection(connection.id, connection.target, project_id)
    pending = []
    for stage in STAGES:
        name, version = sources[stage]
        source = project.agents.get_version(agent_name=name, agent_version=version)
        desired = with_fabric_iq(source.definition.as_dict(), connection.id)
        latest = project.agents.get(agent_name=name).versions.latest
        same = latest.definition.as_dict() == desired
        if latest.version != version and not same:
            raise ValueError(
                f"{name} has newer version {latest.version}. Review and supply that version "
                "instead of overwriting newer work."
            )
        pending.append((stage, name, source, desired, latest, same))
    pins = {}
    for stage, name, source, desired, latest, same in pending:
        agent = latest if same else project.agents.create_version(
            agent_name=name, definition=PromptAgentDefinition(desired),
            description=source.description, metadata=source.metadata,
        )
        pins[f"{stage}_AGENT_NAME"] = name
        pins[f"{stage}_AGENT_VERSION"] = agent.version
    return pins


def resolve_versions(project: AIProjectClient, names: dict[str, str]) -> dict[str, str]:
    pins = {}
    for stage in STAGES:
        name = names[stage]
        agent = project.agents.get(agent_name=name).versions.latest
        if agent.definition.kind != "prompt":
            raise ValueError(f"{name} must be a prompt specialist.")
        pins[f"{stage}_AGENT_NAME"] = name
        pins[f"{stage}_AGENT_VERSION"] = agent.version
    return pins


def ensure_toolbox(project: AIProjectClient, connection_id: str, name: str = TOOLBOX_NAME) -> str:
    """Create a toolbox version only when its Fabric IQ connection differs; return a pinned MCP URL."""
    try:
        latest = project.toolboxes.get(name).versions.latest
        tools = [tool for tool in latest.as_dict().get("tools", [])]
        same = len(tools) == 1 and tools[0].get("type") == "fabric_iq_preview" \
            and tools[0].get("project_connection_id", "").lower() == connection_id.lower()
        version = latest.version if same else None
    except ResourceNotFoundError:
        version = None
    if version is None:
        version = project.toolboxes.create_version(
            name=name, description="Fabric IQ access to the team's published inventory Data Agent",
            tools=[FabricIQPreviewToolboxTool(project_connection_id=connection_id)],
        ).version
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"].rstrip("/")
    return f"{endpoint}/toolboxes/{name}/versions/{version}/mcp?api-version=v1"


def export_specialists(project: AIProjectClient, sources: dict[str, tuple[str, str]]) -> dict[str, dict[str, str]]:
    """Snapshot each pinned specialist so the runtime needs no permission to read agents."""
    exported = {}
    for stage in STAGES:
        name, version = sources[stage]
        definition = project.agents.get_version(agent_name=name, agent_version=version).definition.as_dict()
        if definition.get("kind") != "prompt" or not definition.get("model"):
            raise ValueError(f"{name} must be a saved prompt specialist with a model.")
        exported[stage.lower()] = {
            "model": definition["model"], "instructions": definition.get("instructions") or "",
        }
    return exported


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--connection-name")
    parser.add_argument("--resolve-only", action="store_true")
    parser.add_argument("--export-specialists", action="store_true")
    args = parser.parse_args()
    if not args.resolve_only and not args.export_specialists and not args.connection_name:
        parser.error("--connection-name is required unless --resolve-only or --export-specialists is used")
    with AzureCliCredential() as credential, AIProjectClient(
        endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"], credential=credential,
    ) as project:
        sources = {
            stage: (os.environ[f"{stage}_AGENT_NAME"], os.environ.get(f"{stage}_AGENT_VERSION", ""))
            for stage in STAGES
        }
        if args.export_specialists:
            target = Path(__file__).with_name("specialists.json")
            target.write_text(json.dumps(export_specialists(project, sources), indent=2), encoding="utf-8")
            print(f"Saved the pinned specialist definitions to {target.name}.")
            return
        if args.resolve_only:
            pins = resolve_versions(project, {stage: sources[stage][0] for stage in STAGES})
        else:
            pins = configure(project, args.connection_name, os.environ["AZURE_AI_PROJECT_ID"], sources)
            connection = project.connections.get(args.connection_name, include_credentials=False)
            pins["TOOLBOX_ENDPOINT"] = ensure_toolbox(project, connection.id)
    print(json.dumps(pins))


if __name__ == "__main__":
    main()
