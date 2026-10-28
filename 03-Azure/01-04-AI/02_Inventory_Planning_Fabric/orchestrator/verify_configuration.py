"""Fail before deployment if a specialist still uses the retired Fabric tool."""

import argparse
import os

from azure.ai.projects import AIProjectClient
from azure.identity import AzureCliCredential


def validate_definition(name: str, definition: dict) -> None:
    if definition.get("kind") != "prompt":
        raise ValueError(f"{name} must be a prompt specialist, not a workflow or hosted agent.")
    types = {tool["type"] for tool in definition.get("tools", [])}
    if "fabric_dataagent_preview" in types:
        raise ValueError(f"{name} still uses the retiring Fabric Data Agent tool. Migrate it to Fabric IQ.")
    if "fabric_iq_preview" not in types:
        raise ValueError(f"{name} must have the Fabric IQ tool connected to its published data agent.")


def verify() -> None:
    with AzureCliCredential() as credential, AIProjectClient(
        endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"], credential=credential,
    ) as project:
        for stage in ("DEMAND", "OPTIMISATION", "REPLENISHMENT"):
            name, version = os.environ[f"{stage}_AGENT_NAME"], os.environ[f"{stage}_AGENT_VERSION"]
            agent = project.agents.get_version(agent_name=name, agent_version=version)
            validate_definition(name, agent.definition.as_dict())
            print(f"PASS: {name} version {version} uses Fabric IQ.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    verify()
