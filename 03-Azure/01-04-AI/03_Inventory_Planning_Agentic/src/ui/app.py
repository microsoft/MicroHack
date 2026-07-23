"""Planner Console - a minimal FastAPI + static-HTML UI for the planning loop.

Deliberately tiny: one file, a handful of JSON endpoints, and one static page. No
build step, no framework bloat. It weaves the three hosted agents into one story a
planner can click through: sense -> plan -> approve -> act.

Run it:  uvicorn ui.app:app --reload --port 8000   (from the src/ folder)
In a Codespace the port is forwarded automatically.

The page always loads. Endpoints that need the agents create the orchestrator
lazily and return a friendly error until your Foundry project + agents are ready -
so Challenge 0 can open an empty console before any agent exists.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Any

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# Allow "import orchestrator" etc. when launched as ui.app from the src/ folder.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from inventory_store import get_store  # noqa: E402
from tools import list_low_stock  # noqa: E402

app = FastAPI(title="Agentic Inventory - Planner Console")
_STATIC = Path(__file__).parent / "static"

# The orchestrator is created on first use so the page loads without Azure config.
_orchestrator: Any = None
_orchestrator_error: str | None = None


def get_orchestrator() -> Any:
    global _orchestrator, _orchestrator_error
    if _orchestrator is None:
        from orchestrator import HackOrchestrator

        _orchestrator = HackOrchestrator()
        _orchestrator_error = None
    return _orchestrator


def _guarded(fn) -> Any:
    """Run an orchestrator call, converting setup problems into friendly JSON."""
    try:
        return fn()
    except Exception as exc:  # noqa: BLE001 - surface any setup error to the UI
        return JSONResponse(status_code=503, content={"error": str(exc)})


class SenseRequest(BaseModel):
    scenario: str


class PlanRequest(BaseModel):
    assessment: str


class ProposeRequest(BaseModel):
    recommendation: dict[str, Any]


class ApproveRequest(BaseModel):
    items: list[dict[str, Any]]
    approvedBy: str = "Planner"


class RunLoopRequest(BaseModel):
    scenario: str


class SignalRequest(BaseModel):
    """An external market signal injected into the governed store (Challenge 5)."""

    headline: str
    type: str = "weather"
    category: str | None = None
    region: str | None = None


class RefinePlanRequest(BaseModel):
    recommendation: dict[str, Any]
    instruction: str


class RefineProposeRequest(BaseModel):
    proposal: dict[str, Any]
    instruction: str


@app.get("/")
def index() -> FileResponse:
    return FileResponse(_STATIC / "index.html")


@app.get("/api/state")
def state() -> Any:
    """Snapshot for the console panels, read from the governed Cosmos store.

    Guarded like the agent endpoints: returns a friendly 503 until COSMOS_ENDPOINT
    is set and you have run az login (the store seeds itself on first read).
    """
    import json

    def _snapshot() -> dict[str, Any]:
        store = get_store()
        return {
            "lowStock": json.loads(list_low_stock()),
            "orders": store.orders,
            "products": len(store.products),
            "locations": len(store.stores),
        }

    return _guarded(_snapshot)


@app.post("/api/sense")
def sense(req: SenseRequest) -> Any:
    return _guarded(lambda: {"assessment": get_orchestrator().sense(req.scenario)})


@app.post("/api/plan")
def plan(req: PlanRequest) -> Any:
    return _guarded(lambda: {"recommendation": get_orchestrator().plan(req.assessment)})


@app.post("/api/plan/refine")
def plan_refine(req: RefinePlanRequest) -> Any:
    """Interactive planning: re-run the optimisation agent to adjust the recommendation."""
    return _guarded(
        lambda: {"recommendation": get_orchestrator().refine_plan(req.recommendation, req.instruction)}
    )


@app.post("/api/propose")
def propose(req: ProposeRequest) -> Any:
    return _guarded(lambda: {"proposal": get_orchestrator().propose(req.recommendation)})


@app.post("/api/propose/refine")
def propose_refine(req: RefineProposeRequest) -> Any:
    """Natural-language PO edit before approval: re-run the replenishment agent. Still
    only proposes — the human gate is unchanged."""
    return _guarded(
        lambda: {"proposal": get_orchestrator().refine_proposal(req.proposal, req.instruction)}
    )


@app.post("/api/approve")
def approve(req: ApproveRequest) -> Any:
    return _guarded(
        lambda: {"result": get_orchestrator().approve(req.items, approved_by=req.approvedBy)}
    )


@app.post("/api/run-loop")
def run_loop(req: RunLoopRequest) -> Any:
    """Challenge 4: run sense -> plan -> propose in one call (stops before acting).

    Uses the sequential workflow with a False approval gate, so it produces the PO
    proposal but never submits — the human still approves at Step 4 via /api/approve.
    """

    def _run() -> dict[str, Any]:
        from workflow import run_planning_workflow

        result = run_planning_workflow(
            req.scenario, approve=lambda _proposal: False, orchestrator=get_orchestrator()
        )
        return {
            "assessment": result.assessment,
            "recommendation": result.recommendation,
            "proposal": result.proposal,
        }

    return _guarded(_run)


# ---------------------------------------------------------------------------
# Event-driven "living demo" (Challenge 5, stretch). A background watcher tails the
# Cosmos `signals` change feed; any independent insert (from the Inject control below,
# an MCP client, or any other system) auto-runs sense -> plan -> propose and streams
# progress to the console over SSE — stopping at the human-approval gate.
# ---------------------------------------------------------------------------


@app.on_event("startup")
async def _start_live_layer() -> None:
    from live import bus

    bus.bind_loop(asyncio.get_running_loop())

    import config

    if not config.COSMOS_ENDPOINT:
        return  # no governed store configured yet — manual console still works
    try:
        from inventory_store import get_store
        from live import start_watcher

        start_watcher(get_store(), get_orchestrator)
    except Exception as exc:  # noqa: BLE001 - watcher is optional; never block startup
        print(f"[live] change-feed watcher not started: {exc}")


@app.post("/api/signal")
def inject_signal(req: SignalRequest) -> Any:
    """Write a new market signal to Cosmos. The write itself is the trigger: the
    change-feed watcher notices it and runs the loop — this endpoint never calls an
    agent, so the reactive path is identical no matter who does the insert."""

    def _inject() -> dict[str, Any]:
        from inventory_store import get_store

        return {"signal": get_store().append_signal(req.model_dump(exclude_none=True))}

    return _guarded(_inject)


@app.get("/api/events")
async def events() -> StreamingResponse:
    """Server-Sent Events stream: the console subscribes here to watch the reactive
    loop run live (signal received, each step, and the awaiting-approval gate)."""
    from live import bus

    queue = bus.subscribe()

    async def stream() -> Any:
        try:
            yield 'data: {"type":"connected"}\n\n'
            while True:
                event = await queue.get()
                yield f"data: {json.dumps(event)}\n\n"
        finally:
            bus.unsubscribe(queue)

    return StreamingResponse(stream(), media_type="text/event-stream")


app.mount("/static", StaticFiles(directory=_STATIC), name="static")
