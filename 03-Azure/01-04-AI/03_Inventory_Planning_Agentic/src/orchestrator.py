"""Orchestrator that weaves the three agents into one cohesive planner story.

This is the glue the planner-console UI (and the CLI) call. It keeps the sense ->
plan -> approve -> act loop in one place so the UI stays dumb:

    sense(scenario)      -> demand assessment (text)
    plan(assessment)     -> reorder recommendation (structured)
    propose(reorder)     -> purchase order proposal + the items to submit
    approve(items, who)  -> ACT: submit the order, return confirmation

``approve`` is the human-in-the-loop gate: nothing is written until a person calls
it. It executes the ``submit_purchase_order`` tool directly, so the human decision -
not the model - triggers the only side effect in the system.
"""

from __future__ import annotations

import json
from typing import Any

import agents
from agent_runtime import AgentRuntime
from tools import submit_purchase_order


def _extract_json(text: str) -> dict[str, Any]:
    """Best-effort parse of a JSON object from an agent's text response."""
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`")
        text = text[text.find("{") :] if "{" in text else text
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end != -1:
        return json.loads(text[start : end + 1])
    raise ValueError(f"No JSON object found in agent response: {text[:200]}")


class HackOrchestrator:
    """Runs the closed planning loop across the three hosted agents."""

    def __init__(self, runtime: AgentRuntime | None = None) -> None:
        self._runtime = runtime or AgentRuntime()

    def sense(self, scenario: str) -> str:
        """SENSE: run the demand-sensing agent over a scenario. Returns its assessment."""
        result = self._runtime.run(agents.DEMAND_SENSING, scenario)
        return result if isinstance(result, str) else str(result)

    def plan(self, assessment: str) -> dict[str, Any]:
        """PLAN: run the optimisation agent. Returns a structured recommendation."""
        prompt = (
            "Here is the demand assessment. Produce the reorder recommendation JSON.\n\n"
            f"{assessment}"
        )
        result = self._runtime.run(agents.INVENTORY_OPTIMISATION, prompt)
        return _extract_json(result if isinstance(result, str) else str(result))

    def propose(self, recommendation: dict[str, Any]) -> dict[str, Any]:
        """PROPOSE: run the replenishment agent. Returns a PO proposal + submit items."""
        prompt = (
            "Here is the reorder recommendation. Produce the purchase order proposal JSON.\n\n"
            f"{json.dumps(recommendation)}"
        )
        result = self._runtime.run(agents.REPLENISHMENT, prompt)
        return _extract_json(result if isinstance(result, str) else str(result))

    def refine_plan(self, recommendation: dict[str, Any], instruction: str) -> dict[str, Any]:
        """Re-run the optimisation agent to adjust an existing recommendation per a
        natural-language instruction (interactive planning). Returns updated JSON."""
        prompt = (
            "Here is the CURRENT reorder recommendation JSON:\n"
            f"{json.dumps(recommendation)}\n\n"
            f'The planner asks you to adjust it: "{instruction}"\n'
            "Apply that change and return the FULL updated recommendation JSON in the "
            "same schema. Keep every line the planner did not ask you to change."
        )
        result = self._runtime.run(agents.INVENTORY_OPTIMISATION, prompt)
        return _extract_json(result if isinstance(result, str) else str(result))

    def refine_proposal(self, proposal: dict[str, Any], instruction: str) -> dict[str, Any]:
        """Re-run the replenishment agent to adjust an existing PO proposal per a
        natural-language instruction. Still only PROPOSES — never submits. Returns the
        updated proposal JSON (including the ``submitItems`` array)."""
        prompt = (
            "Here is the CURRENT purchase order proposal JSON:\n"
            f"{json.dumps(proposal)}\n\n"
            f'The planner asks you to change it: "{instruction}"\n'
            "Apply that change and return the FULL updated proposal JSON in the same "
            "schema (including the submitItems array). Do not submit anything."
        )
        result = self._runtime.run(agents.REPLENISHMENT, prompt)
        return _extract_json(result if isinstance(result, str) else str(result))


    def approve(self, items: list[dict[str, Any]], approved_by: str = "Planner") -> dict[str, Any]:
        """ACT (human-approved): submit the purchase order and return confirmation."""
        return json.loads(submit_purchase_order(json.dumps(items), approved_by=approved_by))
