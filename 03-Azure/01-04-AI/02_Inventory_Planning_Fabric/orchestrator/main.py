"""Responses hosting adapter with approval state in the scoped AgentSession."""

from collections.abc import AsyncIterator, Mapping
from contextlib import AsyncExitStack
from decimal import Decimal, InvalidOperation
import json
import logging
import os
import re
from pathlib import Path
from typing import Any
import uuid

from agent_framework import (
    AgentResponse, AgentResponseUpdate, AgentSession, Content, Message, ResponseStream,
)
from agent_framework_foundry_hosting import HostedResponseRequest, ResponsesHostServer
from azure.ai.agentserver.core import get_request_context
from azure.ai.projects.aio import AIProjectClient
from azure.identity.aio import AzureCliCredential, DefaultAzureCredential
from openai import AsyncOpenAI

from orders import Order, Proposal, Status
from planning import CallSpecialist, ProposalRejected, plan
from toolbox import ToolboxClient


logger = logging.getLogger(__name__)
STATE_KEY = "inventory_order_v1"


class InventoryAssistant:
    id = "inventory-planning-assistant"
    name = "Inventory Planning Assistant"
    description = "Sense demand, plan replenishment and request explicit human approval."

    def __init__(self, call: CallSpecialist):
        self.call = call

    def create_session(self, *, session_id: str | None = None) -> AgentSession:
        return AgentSession(session_id=session_id)

    def get_session(self, service_session_id: str, *, session_id: str | None = None) -> AgentSession:
        return AgentSession(session_id=session_id, service_session_id=service_session_id)

    async def respond(self, messages: str | list[Message], session: AgentSession) -> AgentResponse:
        if isinstance(messages, str):
            text = messages.strip()
        else:
            user_messages = [message for message in messages if message.role == "user"]
            if len(user_messages) != 1:
                raise ValueError("Each turn must contain exactly one user message.")
            text = user_messages[0].text.strip()
        if not text or len(text) > 12000:
            raise ValueError("Provide a non-empty request of at most 12000 characters.")
        saved = session.state.get(STATE_KEY)
        if saved is None:
            if text.split()[0].upper() in {"YES", "NO", "MODIFY", "STATUS", "NEW"}:
                answer = "No proposal exists in this conversation. Start with a planning request."
            else:
                order = Order(proposal=await plan(text, self.call))
                session.state[STATE_KEY] = order.model_dump(mode="json")
                answer = order.render()
        else:
            order = Order.model_validate(saved)
            if text.upper() == "STATUS":
                answer = order.render()
            elif text.upper() == "NEW":
                if order.status == Status.AWAITING_APPROVAL:
                    answer = "Cancel or approve the current proposal before starting another.\n\n" + order.render()
                else:
                    del session.state[STATE_KEY]
                    answer = "Ready for a new planning request. No ERP action has been taken."
            else:
                answer = order.apply(text)
                session.state[STATE_KEY] = order.model_dump(mode="json")
                logger.info("Proposal state %s, revision %s", order.status, order.revision)
        return AgentResponse(messages=[Message("assistant", [answer])], response_id=uuid.uuid4().hex)

    def run(
        self, messages: str | list[Message] | None = None, *, stream: bool = False,
        session: AgentSession | None = None,
        function_invocation_kwargs: Mapping[str, Any] | None = None,
        client_kwargs: Mapping[str, Any] | None = None, **kwargs: Any,
    ):
        if session is None:
            raise ValueError("A persistent hosted conversation session is required.")
        if messages is None:
            raise ValueError("A user message is required.")
        if not stream:
            return self.respond(messages, session)

        async def updates() -> AsyncIterator[AgentResponseUpdate]:
            response = await self.respond(messages, session)
            yield AgentResponseUpdate(
                contents=[Content.from_text(response.text)], role="assistant",
                response_id=response.response_id, message_id=uuid.uuid4().hex,
            )

        return ResponseStream(updates(), finalizer=AgentResponse.from_updates)


DATA_TOOL = {
    "type": "function", "name": "query_inventory_data_agent",
    "description": (
        "Ask the governed Zava inventory Fabric Data Agent a natural-language question about "
        "stock, safety stock, demand, external signals or product costs. Returns its answer."
    ),
    "parameters": {
        "type": "object", "properties": {"userQuestion": {"type": "string"}},
        "required": ["userQuestion"], "additionalProperties": False,
    },
    "strict": True,
}
MAX_TOOL_ROUNDS = 6
SPECIALISTS_FILE = Path(__file__).with_name("specialists.json")
STAGES = ("demand", "optimisation", "replenishment")


def load_specialists(path: Path = SPECIALISTS_FILE) -> dict[str, dict[str, str]]:
    """Load the pinned specialist definitions that the deploy helper saved with the package."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise RuntimeError(
            "specialists.json is missing or invalid. Rerun the deploy helper to save the pinned specialists."
        ) from None
    for stage in STAGES:
        entry = data.get(stage) if isinstance(data, dict) else None
        if not isinstance(entry, dict) or not isinstance(entry.get("model"), str) or not entry["model"] \
                or not isinstance(entry.get("instructions"), str):
            raise RuntimeError(f"specialists.json has no valid {stage} specialist. Rerun the deploy helper.")
    return {stage: data[stage] for stage in STAGES}


class HostedInventoryAssistant(InventoryAssistant):
    """Runs each participant-authored specialist's pinned instructions and model.

    Fabric access goes through a Foundry toolbox so the platform resolves the end
    user from the forwarded opaque call ID, rather than from a nested agent call.
    """

    def __init__(self):
        self.resources = AsyncExitStack()
        super().__init__(self.call_specialist)
        self.client: AsyncOpenAI | None = None
        self.toolbox: ToolboxClient | None = None
        self.specialists: dict[str, Any] = {}
        self.fabric_answers: list[str] = []

    async def __aenter__(self):
        await self.resources.__aenter__()
        try:
            context = get_request_context()
            if os.environ.get("INVENTORY_LOCAL_DEVELOPMENT") == "1":
                credential = AzureCliCredential()
            else:
                if not context.call_id or not context.user_id:
                    raise RuntimeError("Hosted requests require trusted Foundry caller context.")
                credential = DefaultAzureCredential(exclude_interactive_browser_credential=True)
            specialists = load_specialists()
            await self.resources.enter_async_context(credential)
            project = await self.resources.enter_async_context(
                AIProjectClient(endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"], credential=credential)
            )
            for stage in STAGES:
                self.specialists[stage] = specialists[stage]
            self.client = await self.resources.enter_async_context(
                project.get_openai_client(max_retries=0)
            )

            async def token() -> str:
                return (await credential.get_token("https://ai.azure.com/.default")).token

            self.toolbox = ToolboxClient(
                os.environ["TOOLBOX_ENDPOINT"], token, context.platform_headers(),
            )
            return self
        except BaseException:
            await self.resources.aclose()
            raise

    async def __aexit__(self, *exc):
        return await self.resources.__aexit__(*exc)

    async def call_specialist(self, stage: str, prompt: str) -> str:
        assert self.client is not None and self.toolbox is not None
        definition = self.specialists[stage]
        settings = {
            "model": definition["model"], "instructions": definition.get("instructions") or "",
            "tools": [DATA_TOOL], "parallel_tool_calls": False,
        }
        answers = self.fabric_answers
        response = await self.client.responses.create(input=prompt, **settings)
        for round_number in range(MAX_TOOL_ROUNDS + 1):
            calls = [item for item in response.output if item.type == "function_call"]
            if not calls:
                break
            if round_number == MAX_TOOL_ROUNDS:
                raise RuntimeError(f"The {stage} specialist exceeded its data-query limit.")
            outputs = []
            for call in calls:
                if call.name != DATA_TOOL["name"]:
                    raise RuntimeError(f"The {stage} specialist requested an unknown tool.")
                try:
                    question = json.loads(call.arguments)["userQuestion"]
                except (ValueError, KeyError, TypeError):
                    question = None
                if not isinstance(question, str) or not question.strip():
                    raise RuntimeError(f"The {stage} specialist sent an invalid data question.")
                answer = await self.toolbox.ask(question)
                answers.append(answer)
                logger.info("Fabric Data Agent answered %s with %d characters", stage, len(answer))
                outputs.append({
                    "type": "function_call_output", "call_id": call.call_id, "output": answer,
                })
            response = await self.client.responses.create(
                input=outputs, previous_response_id=response.id, **settings,
            )
        if response.status != "completed":
            logger.error("The %s specialist did not complete: %s", stage, response.model_dump_json())
            raise RuntimeError(f"The {stage} specialist did not complete (status: {response.status}).")
        text = response.output_text
        if stage == "replenishment":
            require_fabric_costs(text, answers)
        return text


NUMBER = re.compile(r"\d[\d,]*(?:\.\d+)?")


def require_fabric_costs(proposal_json: str, answers: list[str]) -> None:
    """Reject any unit cost that does not appear in a Fabric Data Agent answer."""
    try:
        proposal = Proposal.model_validate_json(proposal_json)
    except ValueError:
        return
    found: set[Decimal] = set()
    for answer in answers:
        for raw in NUMBER.findall(answer):
            try:
                found.add(Decimal(raw.replace(",", "")))
            except InvalidOperation:
                continue
    for line in proposal.lines:
        if line.unit_cost not in found:
            raise ProposalRejected(
                f"unit cost {line.unit_cost} for {line.sku} was not returned by the Fabric Data Agent"
            )


def require_storage(request: HostedResponseRequest, options: dict[str, Any]) -> Mapping[str, Any]:
    if request.request.get("store") is False:
        raise ValueError("Inventory approvals require store=true and a persistent conversation.")
    return options


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    ResponsesHostServer(
        agent=HostedInventoryAssistant, history_source="agent", prepare_options=require_storage,
    ).run()


if __name__ == "__main__":
    main()
