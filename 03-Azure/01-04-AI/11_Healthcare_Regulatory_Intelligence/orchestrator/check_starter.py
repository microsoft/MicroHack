"""Check your starter/workflow.py without calling Azure.

    uv run python orchestrator/check_starter.py             # checks starter/workflow.py
    uv run python orchestrator/check_starter.py --solution  # checks the finished workflow.py
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import socket
import sys
from pathlib import Path
from typing import List
from unittest.mock import patch

ORCHESTRATOR = Path(__file__).resolve().parent
sys.path.insert(0, str(ORCHESTRATOR))

from configuration import Configuration  # noqa: E402

ENDPOINT = "https://check.services.ai.azure.com/api/projects/check"


class _NoAzure:
    """A credential that fails if anything tries to sign in."""

    def get_token(self, *args, **kwargs):
        raise AssertionError("The workflow must not call Azure while it is being built.")

    def close(self):
        pass


def load(path: Path):
    spec = importlib.util.spec_from_file_location(f"check_{path.parent.name}_workflow", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(module) -> List[str]:
    """Return a list of problems; an empty list means the chain is correct."""
    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT}, clear=False):
        config = Configuration.from_environment()
    names = config.names
    try:
        with patch.object(socket.socket, "connect", side_effect=AssertionError("Unexpected network access")):
            assistant = module.build_workflow(config, _NoAzure(), {"CITATION": "1", "IMPACT": "2", "BRIEFING": "3"})
    except NotImplementedError as error:
        return [str(error)]
    except Exception as error:
        return [f"build_workflow failed: {type(error).__name__}: {error}"]
    workflow = getattr(assistant, "workflow", None)
    if workflow is None:
        return ["build_workflow must return builder.build().as_agent(...)"]
    problems = []
    if workflow.get_start_executor().id != names["CITATION"]:
        problems.append(f"The workflow should start at {names['CITATION']}, not {workflow.get_start_executor().id}.")
    outputs = [executor.id for executor in workflow.get_output_executors()]
    if outputs != [names["BRIEFING"]]:
        problems.append(f"Only {names['BRIEFING']} should produce the output; found {outputs}.")
    edges = {(edge.source_id, edge.target_id) for group in workflow.edge_groups for edge in group.edges
             if not edge.source_id.startswith("internal:")}
    expected = {(names["CITATION"], names["IMPACT"]), (names["IMPACT"], names["BRIEFING"])}
    if edges != expected:
        problems.append(f"Expected the edges {sorted(expected)}; found {sorted(edges)}.")
    from agent_framework import Message

    by_id = {executor.id: executor for executor in workflow.get_executors_list()}
    sample = [Message(role="user", contents=["change event"]), Message(role="assistant", contents=["previous answer"])]
    for role, name in names.items():
        executor = by_id.get(name)
        context_filter = getattr(executor, "_context_filter", None)
        if executor is None:
            continue
        if getattr(executor, "_context_mode", None) != "custom" or context_filter is None:
            problems.append(f"{name} should use context_mode='custom', context_filter=handover('{role}') "
                            "so it receives the previous answer as a request.")
            continue
        handed = context_filter(sample)
        expected = getattr(module, "REQUESTS", {}).get(role, "") + "previous answer"
        if len(handed) != 1 or handed[0].text != expected:
            problems.append(f"{name} should use context_filter=handover('{role}'), the filter for its own role.")
    return problems


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--solution", action="store_true", help="Check the finished workflow.py instead")
    args = parser.parse_args(argv)
    path = ORCHESTRATOR / ("workflow.py" if args.solution else "starter/workflow.py")
    problems = check(load(path))
    if problems:
        print(f"NOT YET: {path.relative_to(ORCHESTRATOR.parent).as_posix()}")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"PASS: {path.relative_to(ORCHESTRATOR.parent).as_posix()} chains citation -> impact -> briefing correctly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
