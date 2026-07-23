"""Runtime that creates and drives native Foundry agents (azure-ai-projects 2.x).

Each agent is created as a versioned :class:`PromptAgentDefinition` exposed over the
Responses protocol, so it shows up **natively** in the Microsoft Foundry portal (no
"update your agents" migration prompt) and its runs are **traced server-side** once an
Application Insights resource is connected to the project. The agents' function tools
are declared as JSON schemas (derived from the Python callables) and executed here in
your process during development.

This module keeps things deliberately small:

* ``AgentSpec``     - a declarative description of one agent (name, instructions, tools).
* ``AgentRuntime``  - creates the agent versions and runs a single-turn request via the
                      Responses API, resolving any function-tool calls the model makes.

Human-in-the-loop: the runtime NEVER auto-executes ``submit_purchase_order``. If an
agent asks for it, the runtime pauses and returns a ``ToolApprovalRequest`` so the UI
(or CLI) can ask a human. On approval the caller runs the tool and continues.
"""

from __future__ import annotations

import inspect
import json
import re
from dataclasses import dataclass, field
from typing import Any, Callable

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    AgentEndpointConfig,
    FixedRatioVersionSelectionRule,
    FunctionTool,
    PromptAgentDefinition,
    ProtocolConfiguration,
    ResponsesProtocolConfiguration,
    VersionSelector,
)
from azure.identity import DefaultAzureCredential
from openai.types.responses.response_input_param import FunctionCallOutput

import config

# Tools that must never be executed without an explicit human approval.
APPROVAL_REQUIRED = {"submit_purchase_order"}


@dataclass
class AgentSpec:
    """Declarative definition of one hosted agent."""

    name: str
    instructions: str
    functions: set[Callable[..., str]] = field(default_factory=set)


@dataclass
class ToolApprovalRequest:
    """Returned when an agent wants to run an approval-gated tool."""

    tool_name: str
    arguments: dict[str, Any]


def _function_tool(fn: Callable[..., str]) -> FunctionTool:
    """Build a Foundry ``FunctionTool`` schema from a typed, documented Python callable.

    The tool name is the function name, the description is the docstring's first line,
    and every parameter becomes a string property (required unless it has a default).
    Parameter descriptions are lifted from the ``:param name:`` docstring lines. The
    function itself is executed in-process by the runtime when the model calls it.
    """
    doc = inspect.getdoc(fn) or ""
    param_docs = {
        m.group(1): m.group(2).strip()
        for m in re.finditer(r":param (\w+):\s*(.+)", doc)
    }
    properties: dict[str, Any] = {}
    required: list[str] = []
    for name, param in inspect.signature(fn).parameters.items():
        properties[name] = {"type": "string"}
        if name in param_docs:
            properties[name]["description"] = param_docs[name]
        if param.default is inspect.Parameter.empty:
            required.append(name)
    return FunctionTool(
        name=fn.__name__,
        description=doc.split("\n", 1)[0] if doc else fn.__name__,
        parameters={
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        },
        strict=False,
    )


class AgentRuntime:
    """Creates the new-format Foundry agents once and runs single-turn requests.

    Uses the Microsoft Foundry agents API (``azure-ai-projects`` 2.x): each agent is a
    versioned :class:`PromptAgentDefinition` exposed over the Responses protocol. That
    makes them **native** Foundry agents — they appear in the portal without any
    "update your agents" migration prompt, and their runs are **traced server-side**
    once Application Insights is connected. Function tools are declared as schemas and
    executed here in your process during development.
    """

    def __init__(self) -> None:
        self._client = AIProjectClient(
            endpoint=config.require_endpoint(),
            credential=DefaultAzureCredential(),
        )
        self._ready: set[str] = set()
        self._functions: dict[str, dict[str, Callable[..., str]]] = {}

    # ---- Agent lifecycle -------------------------------------------------

    def ensure(self, spec: AgentSpec) -> str:
        """Create a new agent version and route the endpoint to it (idempotent).

        Returns the agent name, which is how the Responses client addresses it.
        """
        if spec.name in self._ready:
            return spec.name

        self._functions[spec.name] = {fn.__name__: fn for fn in spec.functions}
        tools = [_function_tool(fn) for fn in spec.functions]

        version = self._client.agents.create_version(
            agent_name=spec.name,
            definition=PromptAgentDefinition(
                model=config.MODEL_DEPLOYMENT_NAME,
                instructions=spec.instructions,
                tools=tools,
            ),
        )
        self._client.agents.update_details(
            agent_name=spec.name,
            agent_endpoint=AgentEndpointConfig(
                version_selector=VersionSelector(
                    version_selection_rules=[
                        FixedRatioVersionSelectionRule(
                            agent_version=version.version, traffic_percentage=100
                        )
                    ]
                ),
                protocol_configuration=ProtocolConfiguration(
                    responses=ResponsesProtocolConfiguration()
                ),
            ),
        )
        self._ready.add(spec.name)
        return spec.name

    # ---- Running a request ----------------------------------------------

    def run(self, spec: AgentSpec, prompt: str) -> str | ToolApprovalRequest:
        """Run a single-turn request. Returns the agent's text, or an approval request.

        Resolves function-tool calls in a loop: each read-only tool is executed and its
        result fed back to the model. If the model asks for an approval-gated tool
        (``submit_purchase_order``), the runtime does **not** execute it — it returns a
        :class:`ToolApprovalRequest` so a human makes the call.
        """
        self.ensure(spec)
        functions = self._functions[spec.name]

        with self._client.get_openai_client(agent_name=spec.name) as openai_client:
            response = self._respond(openai_client, input=prompt)

            while True:
                calls = [
                    item
                    for item in response.output
                    if getattr(item, "type", None) == "function_call"
                ]
                if not calls:
                    break

                outputs: list[FunctionCallOutput] = []
                for call in calls:
                    try:
                        args = json.loads(call.arguments or "{}")
                    except json.JSONDecodeError:
                        args = {}

                    if call.name in APPROVAL_REQUIRED:
                        # Pause: a human must approve this action before we act.
                        return ToolApprovalRequest(tool_name=call.name, arguments=args)

                    fn = functions.get(call.name)
                    result = (
                        fn(**args)
                        if fn
                        else json.dumps({"error": f"unknown tool '{call.name}'"})
                    )
                    outputs.append(
                        FunctionCallOutput(
                            type="function_call_output",
                            call_id=call.call_id,
                            output=result if isinstance(result, str) else json.dumps(result),
                        )
                    )

                response = self._respond(
                    openai_client, input=outputs, previous_response_id=response.id
                )

            return response.output_text

    # ---- Helpers ---------------------------------------------------------

    def _respond(self, openai_client: Any, **kwargs: Any) -> Any:
        """Call the Responses API, applying reasoning effort when configured.

        gpt-5 reasoning models (the default gpt-5.4-mini included) run faster with a
        low reasoning budget. We pass ``reasoning`` when set, but fall back to a plain
        call if the model/SDK rejects it — so the hack works on any model.
        """
        effort = config.effective_reasoning_effort()
        if effort:
            try:
                return openai_client.responses.create(
                    reasoning={"effort": effort}, **kwargs
                )
            except Exception:  # noqa: BLE001 - model/SDK rejected the reasoning param
                pass
        return openai_client.responses.create(**kwargs)
