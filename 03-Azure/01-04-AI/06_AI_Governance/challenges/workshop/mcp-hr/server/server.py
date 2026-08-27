from __future__ import annotations

import json
import os
from typing import Any, Callable

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from auth import validate_bearer_token
from hr_data import HRStore
from telemetry import configure_telemetry, logger, tool_span


SERVER_NAME = "contoso-hr-mcp"
PROTOCOL_VERSION = "2025-06-18"

app = FastAPI(title="Contoso HR MCP Server", version="0.1.0")
store = HRStore()
configure_telemetry()


class JSONRPCRequest(BaseModel):
    jsonrpc: str = "2.0"
    id: str | int | None = None
    method: str
    params: dict[str, Any] = Field(default_factory=dict)


def jsonrpc_result(request_id: str | int | None, result: Any) -> dict[str, Any]:
    if request_id is None:
        return {}
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def jsonrpc_error(request_id: str | int | None, code: int, message: str, data: Any | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}
    if data is not None:
        payload["error"]["data"] = data
    return payload


def tool_result(payload: dict[str, Any]) -> dict[str, Any]:
    return {"content": [{"type": "text", "text": json.dumps(payload, indent=2, sort_keys=True)}], "isError": not payload.get("ok", True)}


def tool_schema(name: str, description: str, properties: dict[str, Any], required: list[str], read_only: bool) -> dict[str, Any]:
    return {
        "name": name,
        "description": description,
        "inputSchema": {"type": "object", "properties": properties, "required": required},
        "annotations": {"readOnlyHint": read_only},
    }


TOOLS: dict[str, Callable[..., dict[str, Any]]] = {
    "search_employees": store.search_employees,
    "get_employee_profile": store.get_employee_profile,
    "recommend_learning_path": store.recommend_learning_path,
    "submit_pto_request": store.submit_pto_request,
    "update_employee_skills": store.update_employee_skills,
}


TOOL_DEFINITIONS = [
    tool_schema(
        "search_employees",
        "Search employees by name, role, skills, department, location, or goals.",
        {
            "query": {"type": "string", "description": "Search terms such as name, role, skill, or goal."},
            "department": {"type": "string", "description": "Optional exact department filter."},
            "location": {"type": "string", "description": "Optional exact location filter."},
        },
        ["query"],
        True,
    ),
    tool_schema(
        "get_employee_profile",
        "Get a detailed employee profile including current PTO and skill evidence.",
        {"employee_id": {"type": "string", "description": "Employee id, for example E1001."}},
        ["employee_id"],
        True,
    ),
    tool_schema(
        "recommend_learning_path",
        "Recommend a dynamic learning path for an employee and target role.",
        {
            "employee_id": {"type": "string", "description": "Employee id, for example E1001."},
            "target_role": {"type": "string", "description": "Target role such as Engineering Manager."},
        },
        ["employee_id", "target_role"],
        True,
    ),
    tool_schema(
        "submit_pto_request",
        "Submit a PTO request and update in-memory state when auto-approved.",
        {
            "employee_id": {"type": "string", "description": "Employee id, for example E1001."},
            "start_date": {"type": "string", "description": "ISO date YYYY-MM-DD."},
            "end_date": {"type": "string", "description": "ISO date YYYY-MM-DD."},
            "reason": {"type": "string", "description": "Reason for PTO."},
        },
        ["employee_id", "start_date", "end_date", "reason"],
        False,
    ),
    tool_schema(
        "update_employee_skills",
        "Add employee skills with evidence and persist the update in memory.",
        {
            "employee_id": {"type": "string", "description": "Employee id, for example E1001."},
            "skills": {"type": "array", "items": {"type": "string"}, "description": "Skills to add."},
            "evidence_note": {"type": "string", "description": "Evidence for the skill update."},
        },
        ["employee_id", "skills", "evidence_note"],
        False,
    ),
]


@app.get("/health")
async def health() -> dict[str, Any]:
    return {"status": "ok", "service": SERVER_NAME, "tools": len(TOOL_DEFINITIONS)}


@app.get("/")
async def root() -> dict[str, Any]:
    return await health()


@app.post("/mcp")
async def mcp_endpoint(request: Request, _claims: dict[str, Any] = Depends(validate_bearer_token)) -> JSONResponse:
    try:
        body = await request.json()
    except json.JSONDecodeError:
        return JSONResponse(jsonrpc_error(None, -32700, "Parse error"))

    if isinstance(body, list):
        responses = [await handle_message(item) for item in body]
        return JSONResponse([response for response in responses if response])
    return JSONResponse(await handle_message(body))


async def handle_message(raw: dict[str, Any]) -> dict[str, Any]:
    try:
        message = JSONRPCRequest.model_validate(raw)
    except Exception as exc:
        return jsonrpc_error(raw.get("id") if isinstance(raw, dict) else None, -32600, "Invalid Request", str(exc))

    if message.method == "initialize":
        return jsonrpc_result(
            message.id,
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}, "prompts": {}, "resources": {}},
                "serverInfo": {"name": SERVER_NAME, "version": "0.1.0"},
            },
        )
    if message.method == "notifications/initialized":
        return jsonrpc_result(message.id, {})
    if message.method == "tools/list":
        return jsonrpc_result(message.id, {"tools": TOOL_DEFINITIONS})
    if message.method == "prompts/list":
        return jsonrpc_result(message.id, {"prompts": []})
    if message.method == "resources/list":
        return jsonrpc_result(message.id, {"resources": []})
    if message.method == "logging/setLevel":
        level = str(message.params.get("level", "info")).upper()
        logger.setLevel(level if level in {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"} else "INFO")
        return jsonrpc_result(message.id, {})
    if message.method == "tools/call":
        return jsonrpc_result(message.id, tool_result(call_tool(message.params)))
    return jsonrpc_error(message.id, -32601, "Method not found")


def call_tool(params: dict[str, Any]) -> dict[str, Any]:
    name = params.get("name")
    arguments = params.get("arguments") or {}
    if name not in TOOLS:
        return {"ok": False, "error": "UNKNOWN_TOOL", "message": f"Tool {name!r} is not available.", "next_steps": ["Call `tools/list` to discover available tools."]}
    with tool_span(str(name)):
        try:
            return TOOLS[str(name)](**arguments)
        except TypeError as exc:
            return {"ok": False, "error": "VALIDATION_ERROR", "message": str(exc), "next_steps": [f"Retry `{name}` with arguments matching its inputSchema."]}
        except Exception as exc:
            logger.exception("Tool call failed for %s", name)
            return {"ok": False, "error": "INTERNAL_ERROR", "message": type(exc).__name__, "next_steps": ["Retry later or contact the MCP server operator."]}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("server:app", host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
