import os
import asyncio
from typing import Annotated
from datetime import datetime, timezone as tz

from pydantic import Field
from agent_framework import Agent, tool
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.identity import DefaultAzureCredential

from governance import GovernanceLayer


# ---- Governance Configuration ----
governance = GovernanceLayer(
    allowed_tools=["get_current_time", "get_weather"],
    # send_email is NOT in the allowed list => BLOCKED
    policy_rules=[
        {
            "name": "block-ssn",
            "pattern": r"\b\d{3}-\d{2}-\d{4}\b",
            "message": "PII detected (SSN pattern) - blocked for data protection",
        },
        {
            "name": "block-sensitive-keywords",
            "pattern": r"(?i)(password|credit.card|social.security)",
            "message": "Sensitive information detected - blocked for data protection",
        },
    ],
)


# ---- Tools (governed via CapabilityGuard) ----
@tool(approval_mode="never_require")
async def get_current_time(
    timezone: Annotated[str, Field(description="IANA timezone name, e.g. 'America/New_York', 'Europe/London'")]
) -> str:
    """Get the current date and time for a given timezone."""
    decision = governance.check_tool("get_current_time")
    if not decision.allowed:
        return f"[GOVERNANCE BLOCKED] {decision.reason}"
    import zoneinfo
    try:
        zone = zoneinfo.ZoneInfo(timezone)
        now = datetime.now(zone)
        return f"Current time in {timezone}: {now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    except Exception as e:
        return f"Could not get time for timezone '{timezone}': {e}"


@tool(approval_mode="never_require")
async def get_weather(
    location: Annotated[str, Field(description="City name, e.g. 'Seattle', 'London', 'Tokyo'")]
) -> str:
    """Get the current weather for a given location (simulated)."""
    decision = governance.check_tool("get_weather")
    if not decision.allowed:
        return f"[GOVERNANCE BLOCKED] {decision.reason}"
    import hashlib
    seed = hashlib.md5(f"{location}{datetime.now(tz.utc).strftime('%Y-%m-%d')}".encode()).hexdigest()
    conditions = ["sunny", "partly cloudy", "cloudy", "rainy", "windy", "snowy"]
    condition = conditions[int(seed[:2], 16) % len(conditions)]
    temp_c = 5 + (int(seed[2:4], 16) % 30)
    humidity = 30 + (int(seed[4:6], 16) % 50)
    return f"Weather in {location}: {condition}, {temp_c} deg C, humidity {humidity}%"


@tool(approval_mode="never_require")
async def send_email(
    to: Annotated[str, Field(description="Recipient email address")],
    body: Annotated[str, Field(description="Email body text")],
) -> str:
    """Send an email to a recipient."""
    decision = governance.check_tool("send_email")
    if not decision.allowed:
        return f"[GOVERNANCE BLOCKED] {decision.reason}"
    return f"Email sent to {to}"


async def setup():
    credential = DefaultAzureCredential()

    client = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
        credential=credential,
    )

    # Enable OpenTelemetry -> Application Insights
    try:
        await client.configure_azure_monitor(enable_sensitive_data=False)
    except Exception as e:
        print(f"Warning: Could not configure Azure Monitor: {e}")

    agent = Agent(
        client=client,
        name="citadel-governed-agent",
        instructions=(
            "You are a governed customer service assistant. "
            "You can check the weather, tell the time, and send emails. "
            "If a tool returns a GOVERNANCE BLOCKED message, explain to the user "
            "that the action was denied by the governance policy and state the reason. "
            "Be concise and helpful."
        ),
        tools=[get_current_time, get_weather, send_email],
        default_options={"store": False},
    )

    return ResponsesHostServer(agent)


if __name__ == "__main__":
    server = asyncio.run(setup())
    server.run()