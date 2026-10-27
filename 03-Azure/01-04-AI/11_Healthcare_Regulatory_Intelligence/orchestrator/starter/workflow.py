"""Your version of the agent chain: fill in the three TODOs in build_workflow().

Check your work without calling Azure:
    uv run python orchestrator/check_starter.py
Then run it for real:
    uv run python orchestrator/process_events.py --starter --account <StorageAccountName>

Stuck? The finished version is orchestrator/workflow.py.
"""
from __future__ import annotations

from typing import Dict

from agent_framework import AgentExecutor, Message, WorkflowBuilder  # noqa: F401 (you need these below)
from agent_framework.foundry import FoundryAgent  # noqa: F401
from azure.ai.projects import AIProjectClient

from configuration import Configuration


def resolve_versions(config: Configuration, credential) -> Dict[str, str]:
    """Done for you: use pinned versions when given, otherwise the latest saved version of each agent."""
    resolved = {}
    with AIProjectClient(endpoint=config.endpoint, credential=credential) as project:
        for role, name in config.names.items():
            if config.versions.get(role):
                resolved[role] = config.versions[role]
                continue
            try:
                resolved[role] = str(project.agents.get(name).versions.latest.version)
            except Exception as error:
                raise RuntimeError(f"Agent '{name}' was not found in your Foundry project. "
                                   f"Create and save it first (see the challenge for this agent).") from error
    return resolved


# Done for you: each agent gets the same kind of request you gave it in the playground.
REQUESTS = {
    "CITATION": "",
    "IMPACT": "Assess this change for Caldova. The Document & Citation Agent found:\n\n",
    "BRIEFING": "Prepare the action plan for sign-off for this change. The Obligation & Impact Extractor found:\n\n",
}


def handover(role: str):
    """Done for you: turn the previous agent's answer into the request this agent was built for."""
    return lambda conversation: [Message(role="user", contents=[REQUESTS[role] + conversation[-1].text])]


def build_workflow(config: Configuration, credential, versions: Dict[str, str]):
    """Return the chain citation -> impact -> briefing as one agent.

    config.names     {"CITATION": "citation-agent", "IMPACT": "impact-agent", "BRIEFING": "briefing-agent"}
    config.endpoint  your Foundry project endpoint
    versions         {"CITATION": "1", "IMPACT": "2", "BRIEFING": "1"}, from resolve_versions()
    """

    # TODO 1: build a dictionary `executors` with one entry per role in config.names.
    #   Each value is AgentExecutor(<agent>, context_mode="custom", context_filter=handover(role)),
    #   where <agent> is
    #   FoundryAgent(project_endpoint=..., credential=..., agent_name=..., agent_version=...).
    #   handover(role) gives each agent only the previous agent's answer, phrased as its request.
    executors = None
    if executors is None:
        raise NotImplementedError("TODO 1: create one AgentExecutor per saved agent")

    # TODO 2: create a WorkflowBuilder that starts at the CITATION executor and
    #   returns the output of the BRIEFING executor:
    #   WorkflowBuilder(start_executor=..., output_from=[...])
    builder = None
    if builder is None:
        raise NotImplementedError("TODO 2: create the WorkflowBuilder with a start and an output")

    # TODO 3: connect CITATION -> IMPACT and IMPACT -> BRIEFING with builder.add_edge(source, target).
    raise NotImplementedError("TODO 3: add the two edges")

    return builder.build().as_agent(name="regulatory-intelligence-assistant")
