from multiprocessing import context

from agent_framework.foundry import FoundryChatClient, FoundryAgent
from azure.identity.aio import AzureCliCredential
from dotenv import load_dotenv
from agent_framework import Agent, AgentExecutorResponse, WorkflowBuilder, Executor, handler, WorkflowContext

import os
import sys
import re
import logging
from typing import Any


def extract_work_order_id(text: str) -> str | None:
    """Extract work order ID (wo-XXXX-XXXXXXXX) from text."""
    match = re.search(r'wo-\d{4}-[a-f0-9]+', text, re.IGNORECASE)
    return match.group(0) if match else None


# Add the shared src/agents to the Python path for in-place imports
# This path is relative to this file's location: src/agent-workflow/app -> src/agents
AGENTS_PATH = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "agents"))
if AGENTS_PATH not in sys.path:
    sys.path.insert(0, AGENTS_PATH)

# Load .env from the hack root to get COSMOS and AI_FOUNDRY credentials
HACK_ROOT = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", ".."))
ENV_FILE = os.path.join(HACK_ROOT, ".env")
loaded = load_dotenv(ENV_FILE, override=True)
logger = logging.getLogger(__name__)

# Debug: Log env loading status
logger.info(
    f"Loading env from: {ENV_FILE} (exists: {os.path.exists(ENV_FILE)}, loaded: {loaded})")
logger.info(f"COSMOS_ENDPOINT set: {bool(os.getenv('COSMOS_ENDPOINT'))}")
logger.info(f"COSMOS_DATABASE set: {bool(os.getenv('COSMOS_DATABASE'))}")
logger.info(
    f"AI_FOUNDRY_PROJECT_ENDPOINT set: {bool(os.getenv('AI_FOUNDRY_PROJECT_ENDPOINT'))}")


# =============================================================================
# A2A Server Wrappers for the Maintenance Scheduler and Parts Ordering Agents
# =============================================================================

def create_maintenance_scheduler_a2a_app():
    """Create an A2A Starlette application for the Maintenance Scheduler Agent."""
    from starlette.applications import Starlette
    from a2a.server.request_handlers import DefaultRequestHandler
    from a2a.server.agent_execution import AgentExecutor, RequestContext
    from a2a.server.events.event_queue import EventQueue
    from a2a.server.tasks.task_updater import TaskUpdater
    from a2a.server.tasks import InMemoryTaskStore
    from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
    from a2a.types import AgentCard, AgentCapabilities, AgentSkill, Message, AgentInterface, Part

    # Get the base URL from environment or use default
    # The URL should point to where this agent's RPC endpoint is accessible
    # Must use https:// to match what the .NET workflow uses via Aspire
    default_url = os.getenv("MAINTENANCE_SCHEDULER_AGENT_SELF_URL",
                            "https://localhost:8000/maintenance-scheduler/")

    agent_card = AgentCard(
        name="MaintenanceSchedulerAgent",
        description="Predictive maintenance scheduling agent that analyzes work orders, historical maintenance data, and available windows to recommend optimal maintenance schedules.",
        version="1.0.0",
        supported_interfaces=[AgentInterface(
            protocol_binding="JSONRPC",
            protocol_version="1.0",
            url=default_url,
        )],
        capabilities=AgentCapabilities(
            streaming=True, push_notifications=False),
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        skills=[
            AgentSkill(
                id="schedule_maintenance",
                name="Schedule Maintenance",
                description="Predict optimal maintenance schedule for a work order",
                tags=["maintenance", "scheduling", "predictive"],
            )
        ],
    )

    class MaintenanceSchedulerExecutor(AgentExecutor):
        """A2A executor that wraps the MaintenanceSchedulerAgent from src/agents."""

        async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
            from a2a.helpers import new_text_message
            from a2a.types.a2a_pb2 import Task, TaskStatus, TaskState, Role

            user_message = context.message
            task_id = context.task_id
            context_id = context.context_id

            if not user_message or not task_id or not context_id:
                return

            # Create and enqueue task
            await event_queue.enqueue_event(
                Task(
                    id=task_id,
                    context_id=context_id,
                    status=TaskStatus(state=TaskState.TASK_STATE_SUBMITTED),
                    history=[user_message],
                )
            )

            updater = TaskUpdater(
                event_queue=event_queue,
                task_id=task_id,
                context_id=context_id,
            )

            query = context.get_user_input()

            try:
                from maintenance_scheduler_agent import MaintenanceSchedulerAgent
                from services.cosmos_db_service import CosmosDbService
            except (ImportError, OSError) as import_err:
                logger.exception("Failed to import agents from src/agents")
                response_text = f"Error: Failed to import required modules: {str(import_err)}"
                await updater.add_artifact(
                    parts=[Part(text=response_text)],
                    name='response',
                    last_chunk=True,
                )
                await updater.complete()
                return

            try:
                # Extract the message text from user_message
                logger.info(
                    f"MaintenanceSchedulerExecutor received message: {query}")

                # Initialize services
                cosmos_endpoint = os.getenv("COSMOS_ENDPOINT")
                cosmos_key = os.getenv("COSMOS_KEY")
                database_name = os.getenv(
                    "COSMOS_DATABASE_NAME") or os.getenv("COSMOS_DATABASE")
                project_endpoint = os.getenv("AI_FOUNDRY_PROJECT_ENDPOINT") or os.getenv(
                    "AZURE_AI_PROJECT_ENDPOINT")
                deployment_name = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")

                if not all([cosmos_endpoint, cosmos_key, database_name, project_endpoint]):
                    response_text = "Error: Missing required environment variables for MaintenanceSchedulerAgent"
                else:
                    cosmos_service = CosmosDbService(
                        cosmos_endpoint, cosmos_key, database_name)
                    agent = MaintenanceSchedulerAgent(
                        project_endpoint, deployment_name, cosmos_service)

                    # Parse work order ID from input (default matches src/agents/maintenance_scheduler_agent.py)
                    work_order_id = extract_work_order_id(
                        query) if query else None
                    if not work_order_id:
                        work_order_id = "wo-2024-468"  # fallback default
                    logger.info(f"Looking up work order: '{work_order_id}'")

                    # Get work order and run prediction
                    work_order = await cosmos_service.get_work_order(work_order_id)
                    logger.info(
                        f"Found work order: {work_order.id} for machine: {work_order.machine_id}")
                    history = await cosmos_service.get_maintenance_history(work_order.machine_id)
                    windows = await cosmos_service.get_available_maintenance_windows(14)

                    schedule = await agent.predict_schedule(work_order, history, windows)

                    response_text = (
                        f"Maintenance Schedule Created:\n"
                        f"- Schedule ID: {schedule.id}\n"
                        f"- Machine: {schedule.machine_id}\n"
                        f"- Scheduled Date: {schedule.scheduled_date}\n"
                        f"- Risk Score: {schedule.risk_score}/100\n"
                        f"- Failure Probability: {schedule.predicted_failure_probability * 100:.1f}%\n"
                        f"- Recommended Action: {schedule.recommended_action}\n"
                        f"- Reasoning: {schedule.reasoning}"
                    )

                    await cosmos_service.save_maintenance_schedule(schedule)

            except Exception as e:
                logger.exception("MaintenanceSchedulerAgent error")
                response_text = f"Error processing maintenance schedule request: {str(e)}"

            await updater.add_artifact(
                parts=[Part(text=response_text)],
                name='response',
                last_chunk=True,
            )
            await updater.complete()

        async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
            pass

    executor = MaintenanceSchedulerExecutor()
    task_store = InMemoryTaskStore()
    request_handler = DefaultRequestHandler(
        agent_executor=executor,
        task_store=task_store,
        agent_card=agent_card
    )

    # Create routes for JSONRPC and agent card
    routes = []
    routes.extend(create_agent_card_routes(agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, '/'))

    # Create and return Starlette app
    app = Starlette(routes=routes)
    return app


def create_parts_ordering_a2a_app():
    """Create an A2A Starlette application for the Parts Ordering Agent."""
    from starlette.applications import Starlette
    from a2a.server.request_handlers import DefaultRequestHandler
    from a2a.server.agent_execution import AgentExecutor, RequestContext
    from a2a.server.events.event_queue import EventQueue
    from a2a.server.tasks.task_updater import TaskUpdater
    from a2a.server.tasks import InMemoryTaskStore
    from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
    from a2a.types import AgentCard, AgentCapabilities, AgentSkill, Message, AgentInterface, Part

    # Get the base URL from environment or use default
    # Must use https:// to match what the .NET workflow uses via Aspire
    default_url = os.getenv("PARTS_ORDERING_AGENT_SELF_URL",
                            "https://localhost:8000/parts-ordering/")

    agent_card = AgentCard(
        name="PartsOrderingAgent",
        description="Parts ordering agent that analyzes inventory status and generates optimized parts orders from suppliers.",
        version="1.0.0",
        supported_interfaces=[AgentInterface(
            protocol_binding="JSONRPC",
            protocol_version="1.0",
            url=default_url,
        )],
        capabilities=AgentCapabilities(
            streaming=True, push_notifications=False),
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        skills=[
            AgentSkill(
                id="order_parts",
                name="Order Parts",
                description="Generate optimized parts order for a work order",
                tags=["parts", "ordering", "inventory", "suppliers"],
            )
        ],
    )

    class PartsOrderingExecutor(AgentExecutor):
        """A2A executor that wraps the PartsOrderingAgent from src/agents."""

        async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
            from a2a.helpers import new_text_message
            from a2a.types.a2a_pb2 import Task, TaskStatus, TaskState, Role

            user_message = context.message
            task_id = context.task_id
            context_id = context.context_id

            if not user_message or not task_id or not context_id:
                return

            # Create and enqueue task
            await event_queue.enqueue_event(
                Task(
                    id=task_id,
                    context_id=context_id,
                    status=TaskStatus(state=TaskState.TASK_STATE_SUBMITTED),
                    history=[user_message],
                )
            )

            updater = TaskUpdater(
                event_queue=event_queue,
                task_id=task_id,
                context_id=context_id,
            )

            query = context.get_user_input()

            try:
                from parts_ordering_agent import PartsOrderingAgent
                from services.cosmos_db_service import CosmosDbService
            except (ImportError, OSError) as import_err:
                logger.exception("Failed to import agents from src/agents")
                response_text = f"Error: Failed to import required modules: {str(import_err)}"
                await updater.add_artifact(
                    parts=[Part(text=response_text)],
                    name='response',
                    last_chunk=True,
                )
                await updater.complete()
                return

            try:
                # Initialize services
                cosmos_endpoint = os.getenv("COSMOS_ENDPOINT")
                cosmos_key = os.getenv("COSMOS_KEY")
                database_name = os.getenv(
                    "COSMOS_DATABASE_NAME") or os.getenv("COSMOS_DATABASE")
                project_endpoint = os.getenv("AI_FOUNDRY_PROJECT_ENDPOINT") or os.getenv(
                    "AZURE_AI_PROJECT_ENDPOINT")
                deployment_name = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")

                if not all([cosmos_endpoint, cosmos_key, database_name, project_endpoint]):
                    response_text = "Error: Missing required environment variables for PartsOrderingAgent"
                else:
                    cosmos_service = CosmosDbService(
                        cosmos_endpoint, cosmos_key, database_name)
                    agent = PartsOrderingAgent(
                        project_endpoint, deployment_name, cosmos_service)

                    # Parse work order ID from input (default matches src/agents/parts_ordering_agent.py)
                    work_order_id = extract_work_order_id(
                        query) if query else None
                    if not work_order_id:
                        work_order_id = "wo-2024-468"  # fallback default

                    # Get work order and generate order
                    work_order = await cosmos_service.get_work_order(work_order_id)
                    part_numbers = [
                        p.part_number for p in work_order.required_parts]
                    inventory = await cosmos_service.get_inventory_items(part_numbers)

                    parts_needing_order = [
                        p for p in work_order.required_parts if not p.is_available]

                    if not parts_needing_order:
                        response_text = "All required parts are available in stock. No parts order needed."
                        await cosmos_service.update_work_order_status(work_order.id, "Ready")
                    else:
                        needed_part_numbers = [
                            p.part_number for p in parts_needing_order]
                        suppliers = await cosmos_service.get_suppliers_for_parts(needed_part_numbers)

                        if not suppliers:
                            response_text = "Error: No suppliers found for required parts."
                        else:
                            order = await agent.generate_order(work_order, inventory, suppliers)

                            response_text = (
                                f"Parts Order Generated:\n"
                                f"- Order ID: {order.id}\n"
                                f"- Work Order: {order.work_order_id}\n"
                                f"- Supplier: {order.supplier_name}\n"
                                f"- Expected Delivery: {order.expected_delivery_date}\n"
                                f"- Total Cost: ${order.total_cost:.2f}\n"
                                f"- Items: {len(order.order_items)} part(s)"
                            )

                            await cosmos_service.save_parts_order(order)
                            await cosmos_service.update_work_order_status(work_order.id, "PartsOrdered")

            except Exception as e:
                logger.exception("PartsOrderingAgent error")
                response_text = f"Error processing parts order request: {str(e)}"

            await updater.add_artifact(
                parts=[Part(text=response_text)],
                name='response',
                last_chunk=True,
            )
            await updater.complete()

        async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
            pass

    executor = PartsOrderingExecutor()
    task_store = InMemoryTaskStore()
    request_handler = DefaultRequestHandler(
        agent_executor=executor,
        task_store=task_store,
        agent_card=agent_card
    )

    # Create routes for JSONRPC and agent card
    routes = []
    routes.extend(create_agent_card_routes(agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, '/'))

    # Create and return Starlette app
    app = Starlette(routes=routes)
    return app


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}. "
            "This workflow expects Anomaly/Fault agents to be hosted in Foundry Agent Service and referenced by ID."
        )
    return value


async def get_a2a_agent(server_url: str) -> Agent:
    """Create and return an A2A Agent connected to the specified server URL."""
    try:
        from agent_framework.a2a import A2AAgent
        import importlib

        a2a = importlib.import_module("agent_framework_a2a")
    except ModuleNotFoundError as e:
        raise RuntimeError(
            "A2A support requires the 'agent-framework-a2a' package. "
            "If you're using uv, run `uv sync` in this directory."
        ) from e

    resolver_cls = getattr(a2a, "A2ACardResolver", None)
    if resolver_cls is not None:
        import httpx

        async with httpx.AsyncClient(timeout=60.0) as http_client:
            resolver = resolver_cls(
                httpx_client=http_client, base_url=server_url)
            agent_card = await resolver.get_agent_card(relative_card_path=".well-known/agent-card.json")

        return A2AAgent(
            name=agent_card.name,
            description=getattr(agent_card, "description", ""),
            agent_card=agent_card,
            url=server_url,
        )

    # Fallback: older/newer A2A packages may not ship a card resolver.
    # Try the most common constructor shapes.
    for kwargs in (
        {"url": server_url},
        {"name": "RepairPlannerAgent", "description": "A2A agent", "url": server_url},
    ):
        try:
            return A2AAgent(**kwargs)
        except TypeError:
            continue

    raise RuntimeError(
        "Unable to construct A2A agent from 'agent-framework-a2a'. "
        "Please ensure the package version matches the workflow sample."
    )


def extract_text_from_message(msg: Any) -> str:
    """Helper to extract text from various message types used in the workflow."""
    text = ""
    # Priority 1: Check for AgentExecutorResponse used by framework workflows
    if hasattr(msg, 'agent_run_response') and hasattr(msg.agent_run_response, 'text'):
        text = msg.agent_run_response.text
    # Priority 2: Direct text attribute
    elif getattr(msg, 'text', None):
        text = msg.text
    # Priority 3: Nested response (e.g. wrapper)
    elif getattr(msg, 'response', None) and getattr(msg.response, 'text', None):
        text = msg.response.text
    # Priority 4: Event parameters
    elif getattr(msg, 'params', None):
        params = msg.params
        if isinstance(params, dict):
            text = params.get('text', '') or str(params)
        elif hasattr(params, 'text'):
            text = params.text
        else:
            text = str(params)
    # Priority 5: Fallback string representation
    else:
        text = str(msg)
    return text

# --- Workflow Executors ---


class RequestProcessor(Executor):
    @handler
    async def process(self, data: dict, ctx: WorkflowContext[str]) -> None:
        machine_id = data.get("machine_id")
        telemetry = data.get("telemetry")
        # Format the initial prompt for the Anomaly Agent
        prompt = f'Classify the following anomalies for machine {machine_id}: {telemetry}'
        await ctx.send_message(prompt)


def diagnosis_condition(message: Any) -> bool:
    logger.info(
        f"Evaluating diagnosis condition on message type: {message}")
    # Defensive guard. If a non AgentExecutorResponse appears, let the edge pass to avoid dead ends.
    if not isinstance(message, AgentExecutorResponse):
        return True
    """Determine if Fault Diagnosis is needed based on Anomaly Agent output."""
    print(f"Received message for diagnosis condition: {message}")
    logger.info(
        f"Evaluating diagnosis condition on message type: {type(message)}")

    text = message.agent_response.text
    print(f"Extracted diagnosis text: {text}")
    logger.info(f"Diagnosis text extracted: {text[:200]}...")

    keywords = ["critical", "warning", "high", "alert"]
    should_run = any(keyword in text.lower() for keyword in keywords)
    logger.info(f"Diagnosis condition result: {should_run}")
    return should_run

# --- Main Workflow Function ---


async def run_factory_workflow(machine_id: str, telemetry: list):
    """
    Creates and runs the Factory Analysis Workflow.

    AnomalyDetectionAgent + FaultDiagnosisAgent are hosted in Foundry Agent Service.
    We reference them by name using FoundryAgent.
    """

    project_endpoint = _require_env("AZURE_AI_PROJECT_ENDPOINT")
    deployment_name = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")
    repair_planner_url = os.getenv("REPAIR_PLANNER_AGENT_URL")

    credential = AzureCliCredential()
    try:
        # Reference hosted Foundry agents by name
        anomaly_agent = FoundryAgent(
            project_endpoint=project_endpoint,
            name="AnomalyClassificationAgent",
            agent_name="AnomalyClassificationAgent",
            credential=credential,
            default_options={
                "model": deployment_name,
                "extra_body": {"model": deployment_name},
            }
        )

        fault_agent = FoundryAgent(
            project_endpoint=project_endpoint,
            name="FaultDiagnosisAgent",
            agent_name="FaultDiagnosisAgent",
            credential=credential,
            default_options={
                "model": deployment_name,
                "extra_body": {"model": deployment_name},
            }
        )

        # Build the workflow
        logger.info("Building workflow with Foundry agents...")

        # Init with RequestProcessor as the starting executor
        request_processor = RequestProcessor(id="init")

        # Build workflow starting with the Anomaly Agent
        builder = WorkflowBuilder(start_executor=request_processor)
        builder.add_edge(request_processor, anomaly_agent)
        builder.add_edge(anomaly_agent, fault_agent,
                         condition=diagnosis_condition)

        if repair_planner_url:
            repair_planner_agent = await get_a2a_agent(server_url=repair_planner_url)
            builder.add_edge(fault_agent, repair_planner_agent)

        workflow = builder.build()
        result = await workflow.run({"machine_id": machine_id, "telemetry": telemetry})
        return result.get_outputs()
    finally:
        await credential.close()
