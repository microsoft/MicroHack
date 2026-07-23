"""Stretch (Challenge 4): orchestrate the three agents as one sequential workflow.

The ``HackOrchestrator`` already chains the agents from Python. This module makes
that chaining explicit and reusable as a single callable "workflow" so a caller
(the UI's future "Run the whole loop" button, a routine, or a test) can drive the
entire sense -> plan -> approve -> act loop from one entry point, pausing only at
the human-approval gate.

This mirrors the Microsoft Agent Framework "sequential" pattern: deterministic
hand-off from one agent to the next, with a human gate before the terminal action.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from orchestrator import HackOrchestrator


@dataclass
class WorkflowResult:
    assessment: str
    recommendation: dict[str, Any]
    proposal: dict[str, Any]
    confirmation: dict[str, Any] | None


def run_planning_workflow(
    scenario: str,
    approve: Callable[[dict[str, Any]], bool],
    approved_by: str = "Planner",
    orchestrator: HackOrchestrator | None = None,
) -> WorkflowResult:
    """Run the full loop. ``approve`` is the human gate: it receives the proposal
    and returns True to submit or False to cancel."""
    orch = orchestrator or HackOrchestrator()

    assessment = orch.sense(scenario)
    recommendation = orch.plan(assessment)
    proposal = orch.propose(recommendation)

    confirmation = None
    if approve(proposal):
        confirmation = orch.approve(proposal.get("submitItems", []), approved_by=approved_by)

    return WorkflowResult(
        assessment=assessment,
        recommendation=recommendation,
        proposal=proposal,
        confirmation=confirmation,
    )
