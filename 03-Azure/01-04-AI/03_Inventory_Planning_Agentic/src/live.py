"""Event-driven "living demo" layer — Challenge 6 (stretch).

The manual console (Challenges 1–5) has a human click **Sense → Plan → Approve → Act**.
This module makes the loop **reactive**: a background watcher tails the Cosmos ``signals``
**change feed**, and whenever an *independent write* lands — from the console's Inject
control, an MCP client (see ``mcp_server.py``), or any other system — it **auto-runs**
``sense → plan → propose`` and streams the progress to the console over **SSE**.

Crucially, the automation stops at the **human-approval gate**: it produces the purchase
order proposal but never submits. A person still approves at Step 4. The reactivity is
new; the human-in-the-loop lesson is untouched.

No new Azure infrastructure: the change feed is intrinsic to Cosmos, and everything here
runs inside the existing FastAPI process.
"""

from __future__ import annotations

import asyncio
import threading
import time
from collections import deque
from typing import Any, Callable


class EventBus:
    """Fan-out of JSON events to every connected SSE client.

    ``publish`` is called from worker threads (the watcher / auto-runner), so it hops
    back onto the asyncio loop with ``call_soon_threadsafe`` before touching the
    per-subscriber queues.
    """

    def __init__(self) -> None:
        self._subscribers: set[asyncio.Queue] = set()
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def subscribe(self) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue()
        self._subscribers.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue) -> None:
        self._subscribers.discard(q)

    def publish(self, event: dict[str, Any]) -> None:
        loop = self._loop
        if loop is None:
            return
        for q in list(self._subscribers):
            loop.call_soon_threadsafe(q.put_nowait, event)


# One process-wide bus, plus the latest auto-generated proposal so the UI (or a retry)
# can approve exactly what the reactive loop proposed.
bus = EventBus()
latest_proposal: dict[str, Any] = {"submitItems": None}


def _auto_run(signal: dict[str, Any], orchestrator_factory: Callable[[], Any]) -> None:
    """Run sense → plan → propose for one signal, publishing progress. Stops at the gate."""
    headline = signal.get("headline") or signal.get("type") or "New market signal"
    bus.publish({"type": "signal", "signal": signal})
    try:
        orch = orchestrator_factory()

        bus.publish({"type": "step", "step": 1, "state": "running"})
        assessment = orch.sense(headline)
        bus.publish({"type": "step", "step": 1, "state": "done", "assessment": assessment})

        bus.publish({"type": "step", "step": 2, "state": "running"})
        recommendation = orch.plan(assessment)
        bus.publish({"type": "step", "step": 2, "state": "done", "recommendation": recommendation})

        bus.publish({"type": "step", "step": 3, "state": "running"})
        proposal = orch.propose(recommendation)
        latest_proposal["submitItems"] = proposal.get("submitItems", [])
        bus.publish({"type": "step", "step": 3, "state": "done", "proposal": proposal})

        # The human gate: automation goes no further.
        bus.publish({"type": "awaiting_approval", "submitItems": latest_proposal["submitItems"]})
    except Exception as exc:  # noqa: BLE001 - surface any setup/agent error to the UI
        bus.publish({"type": "error", "message": str(exc)})


def start_watcher(store: Any, orchestrator_factory: Callable[[], Any]) -> None:
    """Tail the ``signals`` change feed and auto-run each new write — with a queue.

    A **producer** thread tails the change feed (pull model, primed from *now* so the
    seed never triggers) and enqueues each new signal. A single **consumer** thread
    drains the queue one signal at a time, so a burst of signals shows up as a visible
    backlog (``queue`` events) that drains as each run completes. Cosmos' change feed
    is a pull model: poll with the continuation token from the ``etag`` header.
    """
    pending: deque = deque()
    lock = threading.Lock()
    has_work = threading.Event()

    def _publish_queue() -> None:
        with lock:
            headlines = [d.get("headline") or d.get("type") or "signal" for d in pending]
        bus.publish({"type": "queue", "depth": len(headlines), "pending": headlines})

    def produce() -> None:
        try:
            container = store.signals_container()
            list(container.query_items_change_feed(start_time="Now"))
            continuation = container.client_connection.last_response_headers.get("etag")
            bus.publish({"type": "watcher", "state": "listening"})
        except Exception as exc:  # noqa: BLE001
            bus.publish({"type": "error", "message": f"watcher failed to start: {exc}"})
            return

        while True:
            try:
                changes = list(container.query_items_change_feed(continuation=continuation))
                continuation = container.client_connection.last_response_headers.get("etag")
                if changes:
                    with lock:
                        pending.extend(changes)
                    _publish_queue()
                    has_work.set()
                time.sleep(3)
            except Exception as exc:  # noqa: BLE001
                bus.publish({"type": "error", "message": f"watcher: {exc}"})
                time.sleep(5)

    def consume() -> None:
        while True:
            with lock:
                doc = pending.popleft() if pending else None
            if doc is None:
                has_work.wait(timeout=1)
                has_work.clear()
                continue
            _publish_queue()          # depth after dequeue (this one is now running)
            _auto_run(doc, orchestrator_factory)

    threading.Thread(target=produce, name="signals-producer", daemon=True).start()
    threading.Thread(target=consume, name="signals-consumer", daemon=True).start()

