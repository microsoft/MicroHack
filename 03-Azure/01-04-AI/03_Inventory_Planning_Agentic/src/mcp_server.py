"""MCP server that lets an *external* system drop a market signal into the governed
store — Challenge 5 (stretch).

This is the "real-life" edge of the event-driven story: an MCP client (GitHub Copilot,
Claude, another agent, a WebIQ-style watcher, …) calls the ``inject_signal`` tool, which
writes to the same Cosmos ``signals`` container the console writes to. That independent
insert is picked up by the change-feed watcher in the planner console, which auto-runs
sense → plan → propose and stops at the human-approval gate. No agent is called here —
the tool only writes the signal; the reactive loop does the rest.

Run it (stdio transport, from the ``src/`` folder):

    uv run python mcp_server.py

Then point an MCP client at that command. The app must be running and Cosmos configured
(``COSMOS_ENDPOINT`` in ``.env`` + ``az login``) for the write — and the reaction — to work.
"""

from __future__ import annotations

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("zava-signals")


@mcp.tool()
def inject_signal(
    headline: str,
    category: str = "outdoor_power_tools",
    region: str = "Pacific Northwest",
) -> str:
    """Inject a market signal into Zava's governed Cosmos store.

    Writing the signal is the trigger: the planner console's change-feed watcher
    notices the new document and automatically runs the inventory-planning loop
    (sense → plan → propose), pausing at the human-approval gate.

    :param headline: The market signal, e.g. "Heatwave intensifies in the Pacific Northwest".
    :param category: Affected product category (e.g. ``outdoor_power_tools``, ``paint_and_supplies``).
    :param region: Affected region (e.g. ``Pacific Northwest``, ``West``, ``National``).
    """
    from inventory_store import get_store

    doc = get_store().append_signal(
        {"headline": headline, "category": category, "region": region, "type": "market"}
    )
    return f"Injected signal {doc['signalId']} — the planner loop will react automatically."


if __name__ == "__main__":
    mcp.run()
