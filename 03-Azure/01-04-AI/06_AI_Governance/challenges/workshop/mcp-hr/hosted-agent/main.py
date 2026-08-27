"""Citadel HR MCP hosted agent.

A Microsoft Agent Framework (MAF) hosted agent (same shape as the workshop
`hosted-agent`) whose tools are served by the HR MCP server *through Azure API
Management*. The agent itself runs in the spoke Foundry project and reasons with
the same Foundry model used by the workshop HR agent.

Auth to the APIM-published MCP endpoint uses the agent's managed identity:
on every HTTP request to APIM we attach a fresh Entra token for the HR MCP API
audience plus the APIM subscription key. This avoids baking an expiring token
into the image and works for a long-lived hosted agent.

Required environment variables (set at deploy time):
  AZURE_AI_MODEL_DEPLOYMENT_NAME  Foundry gateway connection/model (e.g. Hub-HR-ChatAgent-DEV-LLM/gpt-4.1)
  FOUNDRY_PROJECT_ENDPOINT        Injected automatically by the Foundry hosted-agent platform
  HR_MCP_APIM_MCP_URL             APIM MCP endpoint, e.g. https://<apim>.azure-api.net/hr-mcp/mcp
  HR_MCP_AUDIENCE                 HR MCP API audience, e.g. api://<mcp-api-client-id>
  HR_MCP_APIM_SUBSCRIPTION_KEY    APIM subscription key for the HR MCP access contract
"""

import os

from agent_framework import Agent, MCPStreamableHTTPTool
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.identity import DefaultAzureCredential
from httpx import AsyncClient, Request, Timeout

AGENT_NAME = os.environ.get("OTEL_SERVICE_NAME", "citadel-hr-mcp-agent")
MCP_URL = os.environ["HR_MCP_APIM_MCP_URL"]
SUBSCRIPTION_KEY = os.environ.get("HR_MCP_APIM_SUBSCRIPTION_KEY", "")
AUDIENCE = os.environ.get("HR_MCP_AUDIENCE", "")

# Single shared credential. azure-identity caches tokens and refreshes them
# near expiry, so calling get_token per request is cheap.
_credential = DefaultAzureCredential()
_token_scope = f"{AUDIENCE}/.default" if AUDIENCE else None


def _build_mcp_http_client() -> AsyncClient:
    """httpx client that authenticates every request to the APIM MCP endpoint.

    The request hook runs for the MCP handshake (initialize / tools/list) and
    for every tool call, so both connection and invocation are authenticated.
    """

    async def _attach_auth(request: Request) -> None:  # noqa: RUF029 - hook signature
        if SUBSCRIPTION_KEY:
            request.headers["Ocp-Apim-Subscription-Key"] = SUBSCRIPTION_KEY
        if _token_scope:
            token = _credential.get_token(_token_scope).token
            request.headers["Authorization"] = f"Bearer {token}"

    client = AsyncClient(
        follow_redirects=True,
        timeout=Timeout(60.0, read=300.0),
    )
    client.event_hooks["request"].append(_attach_auth)
    return client


def main() -> None:
    mcp_tool = MCPStreamableHTTPTool(
        name="hr_mcp_via_apim",
        url=MCP_URL,
        http_client=_build_mcp_http_client(),
        request_timeout=60,
    )

    client = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
        credential=_credential,
    )

    agent = Agent(
        client=client,
        name=AGENT_NAME,
        instructions=(
            "You are the Contoso HR assistant. Answer HR questions by calling the "
            "hr_mcp_via_apim MCP tools, which are published through the Citadel API "
            "Management gateway. Use search_employees and get_employee_profile for "
            "lookups, recommend_learning_path for development guidance, and "
            "submit_pto_request / update_employee_skills for changes. Always rely on "
            "the MCP tools for HR data; never invent employee records. Be concise and "
            "summarize what the tools returned."
        ),
        tools=[mcp_tool],
        # Conversation history is managed by the hosting infrastructure.
        default_options={"store": False},
    )

    ResponsesHostServer(agent).run()


if __name__ == "__main__":
    main()
