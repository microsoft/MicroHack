#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


EXPECTED_TOOLS = {
    "search_employees",
    "get_employee_profile",
    "recommend_learning_path",
    "submit_pto_request",
    "update_employee_skills",
}
DEFAULT_LOCAL_MCP_URL = "http://localhost:8080/mcp"


@dataclass
class HttpResponse:
    status: int
    body: str
    headers: dict[str, str]


class SmokeFailure(Exception):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Smoke test the HR MCP direct /mcp endpoint.")
    parser.add_argument("--url", help="HR MCP endpoint URL. Accepts either the base URL or the /mcp URL.")
    parser.add_argument("--local", action="store_true", help=f"Use {DEFAULT_LOCAL_MCP_URL} when --url is omitted.")
    parser.add_argument("--token", help="Bearer token for authenticated /mcp calls. The token is never printed.")
    parser.add_argument(
        "--allow-no-auth",
        action="store_true",
        help="Allow /mcp calls without Authorization and skip the unauthenticated rejection check.",
    )
    parser.add_argument(
        "--dev-bypass",
        action="store_true",
        help="Alias for --allow-no-auth for local DEV_BYPASS_AUTH=true testing.",
    )
    parser.add_argument("--timeout", type=float, default=20.0, help="HTTP timeout in seconds. Default: 20.")
    return parser.parse_args()


def run_value_command(command: list[str]) -> str | None:
    try:
        completed = subprocess.run(command, check=False, capture_output=True, text=True)
    except FileNotFoundError:
        return None
    if completed.returncode != 0:
        return None
    value = completed.stdout.strip()
    return value or None


def azd_value(name: str) -> str | None:
    return run_value_command(["azd", "env", "get-value", name])


def first_value(*values: str | None) -> str | None:
    for value in values:
        if value and value.strip():
            return value.strip()
    return None


def resolve_mcp_url(args: argparse.Namespace) -> str:
    url = args.url
    if not url and args.local:
        url = DEFAULT_LOCAL_MCP_URL
    if not url:
        url = first_value(os.getenv("HR_MCP_DIRECT_MCP_URL"), azd_value("HR_MCP_DIRECT_MCP_URL"))
    if not url:
        raise SmokeFailure(
            "No MCP URL found. Pass --url, use --local for localhost, set HR_MCP_DIRECT_MCP_URL, "
            "or select an azd environment containing HR_MCP_DIRECT_MCP_URL."
        )
    parsed = urllib.parse.urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        raise SmokeFailure(f"Invalid URL: {url!r}")
    if parsed.path.rstrip("/").endswith("/mcp"):
        return url.rstrip("/")
    return urllib.parse.urljoin(url.rstrip("/") + "/", "mcp")


def derive_base_url(mcp_url: str) -> str | None:
    parsed = urllib.parse.urlparse(mcp_url)
    path = parsed.path.rstrip("/")
    if not path.endswith("/mcp"):
        return None
    base_path = path[: -len("/mcp")] or ""
    return urllib.parse.urlunparse(parsed._replace(path=base_path or "/", params="", query="", fragment="")).rstrip("/")


def http_request(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: float,
) -> HttpResponse:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            text = response.read().decode("utf-8", errors="replace")
            return HttpResponse(response.status, text, dict(response.headers.items()))
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        return HttpResponse(exc.code, text, dict(exc.headers.items()))
    except urllib.error.URLError as exc:
        raise SmokeFailure(f"{method} {url} failed: {exc.reason}") from exc
    except TimeoutError as exc:
        raise SmokeFailure(f"{method} {url} timed out after {timeout} seconds.") from exc


def parse_json(response: HttpResponse, label: str) -> Any:
    try:
        return json.loads(response.body)
    except json.JSONDecodeError as exc:
        snippet = response.body[:240].replace("\n", " ")
        raise SmokeFailure(f"{label} returned non-JSON response: {snippet}") from exc


def expect_http_200(response: HttpResponse, label: str) -> Any:
    if response.status != 200:
        snippet = response.body[:240].replace("\n", " ")
        raise SmokeFailure(f"{label} returned HTTP {response.status}, expected 200. Body: {snippet}")
    return parse_json(response, label)


def acquire_token(args: argparse.Namespace) -> str | None:
    token = first_value(args.token, os.getenv("HR_MCP_ACCESS_TOKEN"))
    if token:
        return token

    scope = first_value(os.getenv("HR_MCP_SCOPE"), azd_value("HR_MCP_SCOPE"))
    tenant_id = first_value(os.getenv("HR_MCP_TENANT_ID"), azd_value("HR_MCP_TENANT_ID"))
    if not scope:
        return None

    command = ["az", "account", "get-access-token", "--scope", scope, "--query", "accessToken", "-o", "tsv"]
    if tenant_id:
        command[3:3] = ["--tenant", tenant_id]
    return run_value_command(command)


def assert_no_error_rpc(payload: Any, label: str) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise SmokeFailure(f"{label} returned a non-object JSON-RPC payload.")
    if "error" in payload:
        raise SmokeFailure(f"{label} returned JSON-RPC error: {payload['error']}")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise SmokeFailure(f"{label} returned no JSON-RPC result object.")
    return result


def rpc_call(mcp_url: str, method: str, params: dict[str, Any], request_id: int, token: str | None, timeout: float) -> dict[str, Any]:
    response = http_request(
        "POST",
        mcp_url,
        payload={"jsonrpc": "2.0", "id": request_id, "method": method, "params": params},
        token=token,
        timeout=timeout,
    )
    return expect_http_200(response, method)


def decode_tool_text(result: dict[str, Any], label: str) -> dict[str, Any]:
    content = result.get("content")
    if not isinstance(content, list) or not content:
        raise SmokeFailure(f"{label} returned no MCP content.")
    first = content[0]
    if not isinstance(first, dict) or first.get("type") != "text" or not isinstance(first.get("text"), str):
        raise SmokeFailure(f"{label} returned malformed MCP text content.")
    try:
        payload = json.loads(first["text"])
    except json.JSONDecodeError as exc:
        raise SmokeFailure(f"{label} returned text content that is not JSON.") from exc
    if result.get("isError") is True or payload.get("ok") is False:
        raise SmokeFailure(f"{label} returned tool error payload: {payload}")
    return payload


def check_health(mcp_url: str, timeout: float) -> None:
    base_url = derive_base_url(mcp_url)
    if not base_url:
        print("Skipping /health check because a base URL could not be derived.")
        return
    response = http_request("GET", urllib.parse.urljoin(base_url + "/", "health"), timeout=timeout)
    payload = expect_http_200(response, "/health")
    if payload.get("status") != "ok":
        raise SmokeFailure(f"/health returned unexpected status payload: {payload}")
    if payload.get("tools") != len(EXPECTED_TOOLS):
        raise SmokeFailure(f"/health reported tools={payload.get('tools')}, expected {len(EXPECTED_TOOLS)}.")
    print("OK /health")


def check_unauthenticated_rejected(mcp_url: str, timeout: float) -> None:
    response = http_request(
        "POST",
        mcp_url,
        payload={"jsonrpc": "2.0", "id": "unauth", "method": "initialize", "params": {}},
        timeout=timeout,
    )
    if response.status not in {401, 403}:
        raise SmokeFailure(
            f"Unauthenticated /mcp returned HTTP {response.status}; expected 401 or 403 for deployed/auth mode."
        )
    print("OK unauthenticated /mcp rejected")


def run_smoke(args: argparse.Namespace) -> None:
    mcp_url = resolve_mcp_url(args)
    no_auth_allowed = args.allow_no_auth or args.dev_bypass

    print(f"Testing HR MCP endpoint: {mcp_url}")
    check_health(mcp_url, args.timeout)

    if no_auth_allowed:
        token = None
        print("Auth check skipped because no-auth/dev-bypass mode is enabled.")
    else:
        check_unauthenticated_rejected(mcp_url, args.timeout)
        token = acquire_token(args)
        if not token:
            raise SmokeFailure(
                "No bearer token available. Pass --token, set HR_MCP_ACCESS_TOKEN, or run az login with "
                "HR_MCP_SCOPE and HR_MCP_TENANT_ID available from env/azd."
            )

    initialize = assert_no_error_rpc(rpc_call(mcp_url, "initialize", {}, 1, token, args.timeout), "initialize")
    if "protocolVersion" not in initialize or initialize.get("serverInfo", {}).get("name") != "contoso-hr-mcp":
        raise SmokeFailure(f"initialize returned unexpected payload: {initialize}")
    print("OK initialize")

    listed = assert_no_error_rpc(rpc_call(mcp_url, "tools/list", {}, 2, token, args.timeout), "tools/list")
    tools = listed.get("tools")
    if not isinstance(tools, list):
        raise SmokeFailure("tools/list did not return a tools array.")
    tool_names = {tool.get("name") for tool in tools if isinstance(tool, dict)}
    if tool_names != EXPECTED_TOOLS:
        raise SmokeFailure(f"tools/list returned {sorted(tool_names)}, expected {sorted(EXPECTED_TOOLS)}.")
    print("OK tools/list")

    read_result = assert_no_error_rpc(
        rpc_call(
            mcp_url,
            "tools/call",
            {"name": "get_employee_profile", "arguments": {"employee_id": "E1001"}},
            3,
            token,
            args.timeout,
        ),
        "read tools/call",
    )
    read_payload = decode_tool_text(read_result, "read tools/call")
    if read_payload.get("employee_id") != "E1001" or "pto" not in read_payload:
        raise SmokeFailure(f"read tools/call returned unexpected employee profile: {read_payload}")
    print("OK read tools/call")

    write_result = assert_no_error_rpc(
        rpc_call(
            mcp_url,
            "tools/call",
            {
                "name": "update_employee_skills",
                "arguments": {
                    "employee_id": "E1001",
                    "skills": ["smoke-test-validation"],
                    "evidence_note": "Direct MCP smoke test validation evidence.",
                },
            },
            4,
            token,
            args.timeout,
        ),
        "write tools/call",
    )
    write_payload = decode_tool_text(write_result, "write tools/call")
    update = write_payload.get("skill_update", {})
    if update.get("employee_id") != "E1001" or "smoke-test-validation" not in write_payload.get("current_skills", []):
        raise SmokeFailure(f"write tools/call returned unexpected skill update: {write_payload}")
    print("OK write tools/call")


def main() -> int:
    args = parse_args()
    try:
        run_smoke(args)
    except SmokeFailure as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print("HR MCP direct smoke test passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
