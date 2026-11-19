"""Query the published Fabric Data Agent through a Foundry toolbox using MCP tasks."""

import asyncio
from collections.abc import Awaitable, Callable, Mapping
import json
import re
from typing import Any

import requests


Token = Callable[[], Awaitable[str]]
TERMINAL = {"completed", "failed", "cancelled"}


class ToolboxError(RuntimeError):
    pass


class ToolboxClient:
    def __init__(
        self, url: str, token: Token, headers: Mapping[str, str] | None = None,
        *, poll_seconds: float = 3.0, timeout_seconds: float = 150.0,
    ):
        if not url.startswith("https://"):
            raise ValueError("The toolbox endpoint must use HTTPS.")
        self.url = url
        self.token = token
        self.headers = dict(headers or {})
        self.poll_seconds = poll_seconds
        self.timeout_seconds = timeout_seconds
        self._id = 0
        self._session: str | None = None
        self._tool: str | None = None

    def _post(self, bearer: str, body: dict[str, Any]) -> dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {bearer}", "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Foundry-Features": "Toolboxes=V1Preview", **self.headers,
        }
        if self._session:
            headers["mcp-session-id"] = self._session
        response = requests.post(self.url, headers=headers, json=body, timeout=60)
        self._session = self._session or response.headers.get("mcp-session-id")
        text = response.text
        try:
            payload = self._parse(text, body["id"])
        except ValueError:
            raise ToolboxError(f"Toolbox returned HTTP {response.status_code} without JSON.") from None
        if not response.ok and "error" not in payload:
            raise ToolboxError(f"Toolbox returned HTTP {response.status_code}.")
        return payload

    @staticmethod
    def _parse(text: str, request_id: int) -> dict[str, Any]:
        if not text.lstrip().startswith(("data:", "event:", "id:", "retry:", ":")):
            payload = json.loads(text)
        else:
            payload = None
            for event in re.split(r"\r?\n\r?\n", text):
                data = "\n".join(line[5:].lstrip() for line in event.splitlines() if line.startswith("data:"))
                try:
                    candidate = json.loads(data)
                except ValueError:
                    continue
                if isinstance(candidate, dict) and candidate.get("id") == request_id:
                    payload = candidate
                    break
        if not isinstance(payload, dict):
            raise ValueError("No JSON-RPC response found.")
        return payload

    async def _rpc(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        self._id += 1
        payload = await asyncio.to_thread(
            self._post, await self.token(),
            {"jsonrpc": "2.0", "id": self._id, "method": method, "params": params},
        )
        if "error" in payload:
            message = payload["error"].get("message", "unknown error")
            raise ToolboxError(f"Toolbox {method} failed: {message}")
        return payload["result"]

    async def _tool_name(self) -> str:
        if self._tool is not None:
            return self._tool
        await self._rpc("initialize", {
            "protocolVersion": "2025-11-25", "capabilities": {},
            "clientInfo": {"name": "inventory-planning-assistant", "version": "1"},
        })
        tools = (await self._rpc("tools/list", {}))["tools"]
        if len(tools) != 1:
            raise ToolboxError("The toolbox must expose exactly one Fabric Data Agent tool.")
        self._tool = str(tools[0]["name"])
        return self._tool

    async def ask(self, question: str) -> str:
        if not question.strip():
            raise ValueError("A data question is required.")
        created = await self._rpc("tools/call", {
            "name": await self._tool_name(), "arguments": {"userQuestion": question},
            "task": {"ttl": int(self.timeout_seconds * 1000)},
        })
        task = created.get("task")
        if not task:
            return self._text(created)
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.timeout_seconds
        status = task
        while status["status"] not in TERMINAL:
            if status["status"] == "input_required":
                raise ToolboxError("The Fabric Data Agent task needs input that this assistant cannot provide.")
            if loop.time() > deadline:
                raise ToolboxError("The Fabric Data Agent task timed out.")
            await asyncio.sleep(max(self.poll_seconds, min(status.get("pollInterval", 0) / 1000, 10)))
            status = await self._rpc("tasks/get", {"taskId": task["taskId"]})
        if status["status"] != "completed":
            raise ToolboxError(f"The Fabric Data Agent task {status['status']}.")
        return self._text(await self._rpc("tasks/result", {"taskId": task["taskId"]}))

    @staticmethod
    def _text(result: dict[str, Any]) -> str:
        text = "\n".join(part["text"] for part in result.get("content", []) if part.get("type") == "text")
        if result.get("isError"):
            raise ToolboxError(f"The Fabric Data Agent returned an error: {text}")
        if not text.strip():
            raise ToolboxError("The Fabric Data Agent returned no text.")
        return text
