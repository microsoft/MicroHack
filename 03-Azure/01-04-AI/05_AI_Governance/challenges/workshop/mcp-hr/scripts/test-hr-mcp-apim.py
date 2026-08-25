#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
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
DEFAULT_SUBSCRIPTION_NAME = "MCP-HR-Tools-DEV-SUB-01"


@dataclass
class HttpResponse:
    status: int
    body: str
    headers: dict[str, str]


class SmokeFailure(Exception):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Smoke test the HR MCP APIM /mcp publication and access contract.")
    parser.add_argument("--url", help="APIM HR MCP endpoint URL. Accepts either the API base URL or the /mcp URL.")
    parser.add_argument("--token", help="Bearer token for APIM /mcp calls. The token is never printed.")
    parser.add_argument("--subscription-key", help="APIM subscription key. The key is never printed.")
    parser.add_argument("--timeout", type=float, default=20.0, help="HTTP timeout in seconds. Default: 20.")
    parser.add_argument("--skip-rate-limit", action="store_true", help="Skip the APIM tools/call rate-limit check.")
    parser.add_argument("--skip-log-query", action="store_true", help="Skip the optional Azure Monitor log query check.")
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
    url = first_value(args.url, os.getenv("HR_MCP_APIM_MCP_URL"), azd_value("HR_MCP_APIM_MCP_URL"))
    if not url:
        raise SmokeFailure(
            "No APIM MCP URL found. Pass --url, set HR_MCP_APIM_MCP_URL, or select an azd environment "
            "containing HR_MCP_APIM_MCP_URL."
        )
    parsed = urllib.parse.urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        raise SmokeFailure(f"Invalid APIM MCP URL: {url!r}")
    if parsed.path.rstrip("/").endswith("/mcp"):
        return url.rstrip("/")
    return urllib.parse.urljoin(url.rstrip("/") + "/", "mcp")


def redact_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return urllib.parse.urlunparse(parsed._replace(query="", fragment=""))


def acquire_token(args: argparse.Namespace) -> str:
    token = first_value(args.token, os.getenv("HR_MCP_ACCESS_TOKEN"))
    if token:
        return token

    scope = first_value(os.getenv("HR_MCP_SCOPE"), azd_value("HR_MCP_SCOPE"))
    tenant_id = first_value(os.getenv("HR_MCP_TENANT_ID"), azd_value("HR_MCP_TENANT_ID"))
    if not scope:
        raise SmokeFailure(
            "No bearer token or HR_MCP_SCOPE available. Pass --token, set HR_MCP_ACCESS_TOKEN, "
            "or make HR_MCP_SCOPE available in env/azd and run az login."
        )

    command = ["az", "account", "get-access-token", "--scope", scope, "--query", "accessToken", "-o", "tsv"]
    if tenant_id:
        command[3:3] = ["--tenant", tenant_id]
    token = run_value_command(command)
    if not token:
        raise SmokeFailure(
            "Azure CLI token acquisition failed. Run az login, verify HR_MCP_SCOPE/HR_MCP_TENANT_ID, "
            "or pass --token/set HR_MCP_ACCESS_TOKEN."
        )
    return token


def resolve_subscription_key(args: argparse.Namespace) -> str:
    key = first_value(args.subscription_key, os.getenv("HR_MCP_APIM_SUBSCRIPTION_KEY"))
    if key:
        return key

    apim_name = first_value(os.getenv("HR_MCP_APIM_NAME"), azd_value("HR_MCP_APIM_NAME"))
    apim_rg = first_value(
        os.getenv("HR_MCP_APIM_RESOURCE_GROUP"),
        azd_value("HR_MCP_APIM_RESOURCE_GROUP"),
        os.getenv("AZURE_RESOURCE_GROUP"),
        azd_value("AZURE_RESOURCE_GROUP"),
    )
    subscription_name = first_value(
        os.getenv("HR_MCP_APIM_SUBSCRIPTION_NAME"),
        azd_value("HR_MCP_APIM_SUBSCRIPTION_NAME"),
        DEFAULT_SUBSCRIPTION_NAME,
    )
    if not apim_name or not apim_rg or not subscription_name:
        raise SmokeFailure(
            "No APIM subscription key available. Pass --subscription-key, set HR_MCP_APIM_SUBSCRIPTION_KEY, "
            "or provide HR_MCP_APIM_NAME, HR_MCP_APIM_RESOURCE_GROUP, and HR_MCP_APIM_SUBSCRIPTION_NAME "
            "so Azure CLI can retrieve it."
        )

    key = run_value_command(
        [
            "az",
            "apim",
            "subscription",
            "show",
            "--resource-group",
            apim_rg,
            "--service-name",
            apim_name,
            "--sid",
            subscription_name,
            "--query",
            "primaryKey",
            "-o",
            "tsv",
        ]
    )
    if key:
        return key

    subscription_id = first_value(os.getenv("AZURE_SUBSCRIPTION_ID"), azd_value("AZURE_SUBSCRIPTION_ID"), run_value_command(["az", "account", "show", "--query", "id", "-o", "tsv"]))
    if subscription_id:
        encoded_subscription_id = urllib.parse.quote(subscription_id, safe="")
        encoded_rg = urllib.parse.quote(apim_rg, safe="")
        encoded_apim = urllib.parse.quote(apim_name, safe="")
        encoded_sid = urllib.parse.quote(subscription_name, safe="")
        url = (
            "https://management.azure.com/subscriptions/"
            f"{encoded_subscription_id}/resourceGroups/{encoded_rg}"
            f"/providers/Microsoft.ApiManagement/service/{encoded_apim}/subscriptions/{encoded_sid}/listSecrets"
            "?api-version=2024-06-01-preview"
        )
        key = run_value_command(["az", "rest", "--method", "post", "--url", url, "--query", "primaryKey", "-o", "tsv"])
        if key:
            return key

    raise SmokeFailure(
        "Could not retrieve the APIM subscription key with Azure CLI. Pass --subscription-key or set "
        "HR_MCP_APIM_SUBSCRIPTION_KEY. Retrieval command: az apim subscription show --resource-group "
        "<resource-group> --service-name <apim-name> --sid <subscription-name> --query primaryKey -o tsv"
    )


def http_request(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    token: str | None = None,
    subscription_key: str | None = None,
    timeout: float,
) -> HttpResponse:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if subscription_key:
        headers["Ocp-Apim-Subscription-Key"] = subscription_key
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            text = response.read().decode("utf-8", errors="replace")
            return HttpResponse(response.status, text, dict(response.headers.items()))
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        return HttpResponse(exc.code, text, dict(exc.headers.items()))
    except urllib.error.URLError as exc:
        raise SmokeFailure(f"{method} {redact_url(url)} failed: {exc.reason}") from exc
    except TimeoutError as exc:
        raise SmokeFailure(f"{method} {redact_url(url)} timed out after {timeout} seconds.") from exc


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


def assert_no_error_rpc(payload: Any, label: str) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise SmokeFailure(f"{label} returned a non-object JSON-RPC payload.")
    if "error" in payload:
        raise SmokeFailure(f"{label} returned JSON-RPC error: {payload['error']}")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise SmokeFailure(f"{label} returned no JSON-RPC result object.")
    return result


def rpc_response(
    mcp_url: str,
    method: str,
    params: dict[str, Any],
    request_id: int | str,
    token: str | None,
    subscription_key: str | None,
    timeout: float,
) -> HttpResponse:
    return http_request(
        "POST",
        mcp_url,
        payload={"jsonrpc": "2.0", "id": request_id, "method": method, "params": params},
        token=token,
        subscription_key=subscription_key,
        timeout=timeout,
    )


def rpc_call(
    mcp_url: str,
    method: str,
    params: dict[str, Any],
    request_id: int | str,
    token: str,
    subscription_key: str,
    timeout: float,
) -> dict[str, Any]:
    return expect_http_200(rpc_response(mcp_url, method, params, request_id, token, subscription_key, timeout), method)


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


def expect_rejected(response: HttpResponse, label: str) -> None:
    if response.status not in {401, 403}:
        snippet = response.body[:240].replace("\n", " ")
        raise SmokeFailure(f"{label} returned HTTP {response.status}; expected 401 or 403. Body: {snippet}")
    print(f"OK {label} rejected")


def check_negative_credentials(mcp_url: str, token: str, subscription_key: str, timeout: float) -> None:
    expect_rejected(
        rpc_response(mcp_url, "initialize", {}, "missing-bearer", None, subscription_key, timeout),
        "missing bearer token",
    )
    expect_rejected(
        rpc_response(mcp_url, "initialize", {}, "missing-subscription-key", token, None, timeout),
        "missing APIM subscription key",
    )


def check_initialize_and_tools(mcp_url: str, token: str, subscription_key: str, timeout: float) -> None:
    initialize = assert_no_error_rpc(rpc_call(mcp_url, "initialize", {}, 1, token, subscription_key, timeout), "initialize")
    if "protocolVersion" not in initialize or initialize.get("serverInfo", {}).get("name") != "contoso-hr-mcp":
        raise SmokeFailure(f"initialize returned unexpected payload: {initialize}")
    print("OK initialize")

    listed = assert_no_error_rpc(rpc_call(mcp_url, "tools/list", {}, 2, token, subscription_key, timeout), "tools/list")
    tools = listed.get("tools")
    if not isinstance(tools, list):
        raise SmokeFailure("tools/list did not return a tools array.")
    tool_names = {tool.get("name") for tool in tools if isinstance(tool, dict)}
    if tool_names != EXPECTED_TOOLS:
        raise SmokeFailure(f"tools/list returned {sorted(tool_names)}, expected {sorted(EXPECTED_TOOLS)}.")
    print("OK tools/list with exactly the expected tools")


def check_read_write_tools(mcp_url: str, token: str, subscription_key: str, timeout: float) -> None:
    read_result = assert_no_error_rpc(
        rpc_call(
            mcp_url,
            "tools/call",
            {"name": "get_employee_profile", "arguments": {"employee_id": "E1001"}},
            3,
            token,
            subscription_key,
            timeout,
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
                    "skills": ["apim-smoke-test-validation"],
                    "evidence_note": "APIM MCP smoke test validation evidence.",
                },
            },
            4,
            token,
            subscription_key,
            timeout,
        ),
        "write tools/call",
    )
    write_payload = decode_tool_text(write_result, "write tools/call")
    update = write_payload.get("skill_update", {})
    if update.get("employee_id") != "E1001" or "apim-smoke-test-validation" not in write_payload.get("current_skills", []):
        raise SmokeFailure(f"write tools/call returned unexpected skill update: {write_payload}")
    print("OK write tools/call")


def check_non_tool_methods_not_counted(mcp_url: str, token: str, subscription_key: str, timeout: float) -> None:
    for i in range(6):
        method = "tools/list" if i % 2 else "initialize"
        response = rpc_response(mcp_url, method, {}, f"non-tool-{i}", token, subscription_key, timeout)
        if response.status == 429:
            raise SmokeFailure(
                f"{method} returned HTTP 429 during non-tool accounting check. The APIM rate limit should apply only to tools/call."
            )
        payload = expect_http_200(response, f"non-tool {method}")
        assert_no_error_rpc(payload, f"non-tool {method}")
    print("OK non-tool JSON-RPC methods were not rate-limited")


def check_rate_limit(mcp_url: str, token: str, subscription_key: str, timeout: float) -> None:
    deadline = time.monotonic() + 30
    saw_429 = False
    successful_tool_calls = 0
    for i in range(6):
        if time.monotonic() >= deadline:
            raise SmokeFailure("Rate-limit check exceeded 30 seconds before sending more than 5 tools/call requests.")
        response = rpc_response(
            mcp_url,
            "tools/call",
            {"name": "get_employee_profile", "arguments": {"employee_id": "E1001"}},
            f"rate-{i}",
            token,
            subscription_key,
            timeout,
        )
        if response.status == 429:
            saw_429 = True
            retry_after = response.headers.get("Retry-After")
            detail = f" Retry-After={retry_after}." if retry_after else ""
            print(f"OK APIM tools/call rate limit returned HTTP 429 on excess call.{detail}")
            break
        payload = expect_http_200(response, f"rate-limit tools/call {i + 1}")
        assert_no_error_rpc(payload, f"rate-limit tools/call {i + 1}")
        successful_tool_calls += 1

    if not saw_429:
        raise SmokeFailure(
            f"APIM tools/call rate limit did not return HTTP 429 after {successful_tool_calls} rapid tools/call requests. "
            "Confirm the HR MCP APIM product policy is published and has rate-limit-by-key calls=\"5\" renewal-period=\"30\"."
        )


def resolve_workspace_id() -> str | None:
    explicit = first_value(
        os.getenv("HR_MCP_LOG_ANALYTICS_WORKSPACE_ID"),
        azd_value("HR_MCP_LOG_ANALYTICS_WORKSPACE_ID"),
        os.getenv("LOG_ANALYTICS_WORKSPACE_ID"),
    )
    if explicit:
        return explicit

    workspace_name = first_value(os.getenv("HR_MCP_LOG_ANALYTICS_NAME"), azd_value("HR_MCP_LOG_ANALYTICS_NAME"))
    resource_group = first_value(
        os.getenv("HR_MCP_RESOURCE_GROUP"),
        azd_value("HR_MCP_RESOURCE_GROUP"),
        os.getenv("AZURE_RESOURCE_GROUP"),
        azd_value("AZURE_RESOURCE_GROUP"),
    )
    if not workspace_name or not resource_group:
        return None
    return run_value_command(
        [
            "az",
            "monitor",
            "log-analytics",
            "workspace",
            "show",
            "--resource-group",
            resource_group,
            "--workspace-name",
            workspace_name,
            "--query",
            "customerId",
            "-o",
            "tsv",
        ]
    )


def check_apim_logs(skip: bool) -> None:
    if skip:
        print("APIM log query skipped by --skip-log-query.")
        return

    workspace_id = resolve_workspace_id()
    if not workspace_id:
        print(
            "APIM log query skipped: set HR_MCP_LOG_ANALYTICS_WORKSPACE_ID, or set "
            "HR_MCP_LOG_ANALYTICS_NAME plus HR_MCP_RESOURCE_GROUP, then rerun without --skip-log-query. "
            "If APIM diagnostics are configured, query recent gateway traces for source 'hr-mcp-apim'."
        )
        return

    query = (
        "AzureDiagnostics | where TimeGenerated > ago(30m) "
        "| where Category has 'Gateway' "
        "| where requestUrl_s has '/hr-mcp/mcp' or Message has 'hr-mcp-apim' or trace_s has 'hr-mcp-apim' "
        "| project TimeGenerated, Category, OperationName, requestUrl_s, responseCode_d, Message "
        "| take 5"
    )
    result = run_value_command(["az", "monitor", "log-analytics", "query", "--workspace", workspace_id, "--analytics-query", query, "-o", "json"])
    if not result:
        print(
            "APIM log query did not return results. This is non-fatal; verify APIM diagnostics route gateway logs/traces "
            "to the Log Analytics workspace, then query for source 'hr-mcp-apim' or the /hr-mcp/mcp request URL."
        )
        return
    try:
        rows = json.loads(result)
    except json.JSONDecodeError:
        print("APIM log query ran but returned non-JSON output. Inspect Azure Monitor manually for source 'hr-mcp-apim'.")
        return
    if rows:
        print("OK APIM log query returned recent gateway data")
    else:
        print("APIM log query returned no recent rows. This is non-fatal; confirm APIM diagnostics are enabled.")


def run_smoke(args: argparse.Namespace) -> None:
    mcp_url = resolve_mcp_url(args)
    token = acquire_token(args)
    subscription_key = resolve_subscription_key(args)

    print(f"Testing HR MCP APIM endpoint: {redact_url(mcp_url)}")
    check_negative_credentials(mcp_url, token, subscription_key, args.timeout)
    check_initialize_and_tools(mcp_url, token, subscription_key, args.timeout)
    check_read_write_tools(mcp_url, token, subscription_key, args.timeout)
    if args.skip_rate_limit:
        print("APIM rate-limit check skipped by --skip-rate-limit.")
    else:
        check_non_tool_methods_not_counted(mcp_url, token, subscription_key, args.timeout)
        check_rate_limit(mcp_url, token, subscription_key, args.timeout)
    check_apim_logs(args.skip_log_query)


def main() -> int:
    args = parse_args()
    try:
        run_smoke(args)
    except SmokeFailure as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print("HR MCP APIM smoke test passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
