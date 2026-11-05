"""The two tools the maintenance copilot can call."""
import json
from datetime import datetime, timezone
from pathlib import Path

from fl import DATA

TICKETS = Path(__file__).resolve().parent / "tickets.jsonl"


def get_machine_status(machine_id: str) -> dict:
    machines = json.loads((DATA / "machines.json").read_text(encoding="utf-8"))["machines"]
    for m in machines:
        if m["id"].lower() == machine_id.strip().lower():
            return m
    return {"error": f"Unknown machine '{machine_id}'", "known_machines": [m["id"] for m in machines]}


def create_maintenance_ticket(machine_id: str, summary: str, priority: str) -> dict:
    if priority not in ("low", "medium", "high"):
        return {"error": "priority must be low, medium or high"}
    if "error" in get_machine_status(machine_id):
        return {"error": f"Unknown machine '{machine_id}'"}
    existing = TICKETS.read_text(encoding="utf-8").splitlines() if TICKETS.exists() else []
    ticket = {
        "ticket_id": f"MT-{1001 + len(existing)}",
        "machine_id": machine_id.upper(),
        "summary": summary,
        "priority": priority,
        "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    with TICKETS.open("a", encoding="utf-8") as f:
        f.write(json.dumps(ticket) + "\n")
    return ticket


TOOL_SCHEMAS = [
    {"type": "function", "function": {
        "name": "get_machine_status",
        "description": "Get the live status and sensor readings of one machine, for example CNC-07 or PRESS-02.",
        "parameters": {"type": "object",
                       "properties": {"machine_id": {"type": "string", "description": "Machine ID such as CNC-07"}},
                       "required": ["machine_id"]}}},
    {"type": "function", "function": {
        "name": "create_maintenance_ticket",
        "description": "Create a maintenance ticket for a machine.",
        "parameters": {"type": "object",
                       "properties": {"machine_id": {"type": "string", "description": "Machine ID such as CNC-07"},
                                      "summary": {"type": "string", "description": "Short description of the problem"},
                                      "priority": {"type": "string", "enum": ["low", "medium", "high"]}},
                       "required": ["machine_id", "summary", "priority"]}}},
]

IMPLEMENTATIONS = {
    "get_machine_status": get_machine_status,
    "create_maintenance_ticket": create_maintenance_ticket,
}
