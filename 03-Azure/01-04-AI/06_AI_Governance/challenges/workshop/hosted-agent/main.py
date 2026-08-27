import os
from datetime import date, datetime, timedelta, timezone as tz
from typing import Annotated

import logging
import threading
import time as _time

from agent_framework import Agent, tool
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.identity import DefaultAzureCredential
from opentelemetry import trace
from pydantic import Field

# ---------------------------------------------------------------------------
# HR tools (all dummy / deterministic — no external systems).
# ---------------------------------------------------------------------------

@tool(approval_mode="never_require")
def get_pto_balance(
    employee_id: Annotated[str, Field(description="Employee ID, e.g. 'E12345'")]
) -> str:
    """Get the remaining PTO balance, days used this year, and accrual rate for an employee."""
    import hashlib
    seed = int(hashlib.md5(employee_id.encode()).hexdigest()[:6], 16)
    accrued = 20 + (seed % 6)           # 20-25 days/yr
    used = seed % accrued
    remaining = accrued - used
    return (
        f"PTO for employee {employee_id}: {remaining} days remaining "
        f"({used} used / {accrued} accrued this year, accrual rate "
        f"{accrued/12:.2f} days/month)."
    )


@tool(approval_mode="never_require")
def get_holiday_schedule(
    country: Annotated[str, Field(description="ISO country code: 'US', 'UK', or 'JP'")]
) -> str:
    """Get the next 3 upcoming Contoso company holidays for a country."""
    today = date.today()
    catalog = {
        "US": [("Memorial Day", (5, 27)), ("Independence Day", (7, 4)),
               ("Labor Day", (9, 2)), ("Thanksgiving", (11, 28)),
               ("Christmas Day", (12, 25))],
        "UK": [("Spring Bank Holiday", (5, 27)), ("Summer Bank Holiday", (8, 26)),
               ("Christmas Day", (12, 25)), ("Boxing Day", (12, 26))],
        "JP": [("Showa Day", (4, 29)), ("Greenery Day", (5, 4)),
               ("Marine Day", (7, 15)), ("Mountain Day", (8, 11)),
               ("Culture Day", (11, 3))],
    }
    code = country.upper()
    if code not in catalog:
        return f"No holiday schedule configured for country '{country}'. Supported: US, UK, JP."
    upcoming = []
    for name, (m, d) in catalog[code]:
        candidate = date(today.year, m, d)
        if candidate < today:
            candidate = date(today.year + 1, m, d)
        upcoming.append((candidate, name))
    upcoming.sort()
    top3 = ", ".join(f"{name} ({d.isoformat()})" for d, name in upcoming[:3])
    return f"Next 3 Contoso holidays in {code}: {top3}."


@tool(approval_mode="never_require")
def get_benefits_summary(
    plan_type: Annotated[str, Field(description="One of: 'medical', 'dental', 'vision', '401k'")]
) -> str:
    """Get a high-level summary of a Contoso benefits plan."""
    summaries = {
        "medical":  "Medical (Contoso PPO): $250 deductible, $20 PCP copay, 90% in-network coinsurance, $3,000 OOP max.",
        "dental":   "Dental (Contoso Premier): 100% preventive, 80% basic, 50% major; $2,000 annual maximum.",
        "vision":   "Vision (Contoso View): annual eye exam $0, $200 frames allowance every 12 months.",
        "401k":     "401(k): Contoso matches 100% of the first 6% of eligible pay; immediate vesting; Roth + traditional options.",
    }
    key = plan_type.lower()
    if key not in summaries:
        return f"Unknown plan '{plan_type}'. Supported: medical, dental, vision, 401k."
    return summaries[key]


@tool(approval_mode="never_require")
def get_open_enrollment_window() -> str:
    """Get the current open enrollment window dates for Contoso benefits."""
    today = date.today()
    start = date(today.year, 11, 1)
    end = date(today.year, 11, 21)
    if today > end:
        start = date(today.year + 1, 11, 1)
        end = date(today.year + 1, 11, 21)
    days = (start - today).days
    when = "currently open" if start <= today <= end else f"opens in {days} days"
    return f"Contoso open enrollment: {start.isoformat()} → {end.isoformat()} ({when})."


@tool(approval_mode="never_require")
def delete_user(
    user_id: Annotated[str, Field(description="Employee/user ID to delete, e.g. 'E12345'")]
) -> str:
    """Simulate deleting a Contoso HR user account."""
    return f"SIMULATION ONLY: user {user_id} would be deleted."


# ---------------------------------------------------------------------------
# OpenTelemetry note.
#
# The Foundry hosted-agent platform auto-configures the global OTel
# TracerProvider / MeterProvider / LoggerProvider via the
# microsoft-opentelemetry distro using the injected
# APPLICATIONINSIGHTS_CONNECTION_STRING. We deliberately do NOT call
# configure_azure_monitor() or agentmesh.governance.enable_otel() here:
# both attempt to override the global providers and trigger
# "Overriding of current TracerProvider is not allowed" warnings, which
# leaves AGT spans attached to a process-local provider that nobody
# exports.
#
# AGT telemetry instead flows through the canonical
# AuditLog.export_cloudevents() surface: we construct a shared AuditLog,
# pass it to create_governance_middleware(audit_log=...), and the existing
# OTel pipeline picks it up. Custom span emission can use:
#     tracer = trace.get_tracer(__name__)
# ---------------------------------------------------------------------------

tracer = trace.get_tracer(__name__)


# ---------------------------------------------------------------------------
# AGT AuditLog -> OTel logger flush task.
#
# create_governance_middleware records every policy / capability / rogue
# decision into the in-memory AuditLog. To surface those decisions in
# Application Insights we periodically drain AuditLog.export_cloudevents()
# onto a stdlib logger. The platform distro auto-bridges stdlib logging to
# the OTel LoggerProvider, so each CloudEvent becomes a structured log
# record (visible in App Insights "traces" table with logger name
# `agt.audit`).
#
# Runs in a daemon thread so it does not interfere with the Hypercorn
# event loop owned by ResponsesHostServer.run().
# ---------------------------------------------------------------------------

def _start_audit_flusher(audit_log, interval_s: float = 5.0) -> None:
    audit_logger = logging.getLogger("agt.audit")
    # Force INFO so flusher diagnostics survive any root-level filter the
    # platform may install. logger.propagate stays True so the OTel logging
    # bridge installed by the distro still picks the records up.
    audit_logger.setLevel(logging.INFO)

    # One-shot startup diagnostic: log the actual AuditLog API surface so we
    # can see in stderr which method name to call (export_cloudevents vs.
    # export vs. something else).
    public_methods = sorted(m for m in dir(audit_log) if not m.startswith("_"))
    audit_logger.info(
        "agt.audit flusher starting (interval=%.1fs); AuditLog API: %s",
        interval_s, ", ".join(public_methods),
    )

    def _flush_loop() -> None:
        # AGT 3.6.0 AuditLog.export_cloudevents() returns the FULL ordered
        # list of events recorded so far (no incremental kwarg). We track how
        # many we've already emitted and slice from there each tick.
        seen = 0
        tick = 0
        while True:
            tick += 1
            drained_this_tick = 0
            err: Exception | None = None
            try:
                events = audit_log.export_cloudevents() or []
                new_events = events[seen:]
                for ce in new_events:
                    ce_type = ce.get("type") if isinstance(ce, dict) else getattr(ce, "type", None)
                    audit_logger.info(
                        "agt.audit.event",
                        extra={"agt.event.type": ce_type, "agt.cloudevent": ce},
                    )
                    drained_this_tick += 1
                seen = len(events)
            except Exception as exc:  # never let the flusher die silently
                err = exc

            # Heartbeat once per minute (every 12 ticks at 5s interval) so we
            # can confirm the thread is alive even when nothing is drained.
            if err is not None:
                audit_logger.warning(
                    "agt.audit flush tick %d failed: %s: %s",
                    tick, type(err).__name__, err,
                )
            elif drained_this_tick > 0:
                audit_logger.info(
                    "agt.audit flush tick %d drained=%d total=%d",
                    tick, drained_this_tick, seen,
                )
            elif tick % 12 == 1:
                audit_logger.info(
                    "agt.audit flush tick %d heartbeat (no new events; total=%d)",
                    tick, seen,
                )
            _time.sleep(interval_s)

    threading.Thread(
        target=_flush_loop,
        name="agt-audit-flusher",
        daemon=True,
    ).start()


def _create_streaming_governance_middleware(
    *,
    policy_directory: str,
    allowed_tools: list[str],
    agent_id: str,
    audit_log,
) -> list:
    from agent_framework import (
        AgentMiddleware,
        AgentResponse,
        AgentResponseUpdate,
        Content,
        Message,
        ResponseStream,
    )
    from agent_os.integrations.maf_adapter import create_governance_middleware
    from agent_os.policies import PolicyEvaluator

    class StreamingGovernancePolicyMiddleware(AgentMiddleware):
        def __init__(self, evaluator: PolicyEvaluator, audit_log) -> None:
            self.evaluator = evaluator
            self.audit_log = audit_log

        async def process(self, context, call_next) -> None:
            agent_name = getattr(context.agent, "name", "unknown")
            messages = getattr(context, "messages", None) or []
            last_message_text = ""
            if messages:
                last_msg = messages[-1]
                last_message_text = getattr(last_msg, "text", None) or str(last_msg)

            decision = self.evaluator.evaluate(
                {
                    "agent": agent_name,
                    "message": last_message_text,
                    "timestamp": _time.time(),
                    "stream": getattr(context, "stream", False),
                    "message_count": len(messages),
                }
            )

            metadata = getattr(context, "metadata", {})
            metadata["governance_decision"] = decision

            if decision.allowed:
                if self.audit_log:
                    self.audit_log.log(
                        event_type="policy_evaluation",
                        agent_did=agent_name,
                        action="allow",
                        data={
                            "matched_rule": decision.matched_rule,
                            "message_preview": last_message_text[:200],
                        },
                        outcome="success",
                        policy_decision=decision.action,
                    )
                await call_next()
                return

            logging.getLogger("agent_os.integrations.maf_adapter").info(
                "Policy DENY for agent '%s': %s (rule=%s)",
                agent_name,
                decision.reason,
                decision.matched_rule,
            )
            refusal = f"Policy violation: {decision.reason}"

            if self.audit_log:
                self.audit_log.log(
                    event_type="policy_violation",
                    agent_did=agent_name,
                    action="deny",
                    data={
                        "reason": decision.reason,
                        "matched_rule": decision.matched_rule,
                        "message_preview": last_message_text[:200],
                    },
                    outcome="denied",
                    policy_decision=decision.action,
                )

            if getattr(context, "stream", False):
                async def _deny_stream():
                    yield AgentResponseUpdate(
                        contents=[Content.from_text(refusal)],
                        role="assistant",
                        agent_id=agent_name,
                    )

                context.result = ResponseStream(
                    _deny_stream(),
                    finalizer=AgentResponse.from_updates,
                )
            else:
                context.result = AgentResponse(
                    messages=[Message("assistant", [refusal])]
                )

    evaluator = PolicyEvaluator()
    evaluator.load_policies(policy_directory)
    stack = create_governance_middleware(
        policy_directory=None,
        allowed_tools=allowed_tools,
        agent_id=agent_id,
        enable_rogue_detection=True,
        audit_log=audit_log,
    )
    stack.insert(1, StreamingGovernancePolicyMiddleware(evaluator, audit_log))
    return stack


# ---------------------------------------------------------------------------
# Main entrypoint.
# ---------------------------------------------------------------------------

def main() -> None:
    from agentmesh.governance import AuditLog

    tools = [
        get_pto_balance,
        get_holiday_schedule,
        get_benefits_summary,
        get_open_enrollment_window,
        delete_user,
    ]
    allowed_tool_names = [t.name if hasattr(t, "name") else t.__name__ for t in tools]

    agent_name_env = os.environ.get("OTEL_SERVICE_NAME", "citadel-hr-agent")

    # Shared AuditLog — emits OTel-compatible CloudEvents via
    # audit_log.export_cloudevents(); plugs into the already-configured
    # global LoggerProvider installed by the platform distro.
    audit_log = AuditLog()

    governance = _create_streaming_governance_middleware(
        policy_directory="policies",
        allowed_tools=allowed_tool_names,
        agent_id=agent_name_env,
        audit_log=audit_log,
    )

    # Drain AGT audit events into the OTel pipeline every 5s.
    _start_audit_flusher(audit_log, interval_s=5.0)

    client = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
        credential=DefaultAzureCredential(),
    )

    agent = Agent(
        client=client,
        name=agent_name_env,
        instructions=(
            "You are Contoso HR Assistant, a friendly internal HR helper. "
            "Use the provided tools to answer questions about an employee's own PTO balance, "
            "Contoso company holidays, benefits plans (medical/dental/vision/401k), and the "
            "open enrollment window. The delete_user tool exists only to demonstrate governance "
            "for explicit user deletion requests. Never disclose another employee's personal data "
            "(salary, SSN, compensation). Be concise."
        ),
        tools=tools,
        middleware=governance,
        # History is managed by the hosting infrastructure.
        default_options={"store": False},
    )

    server = ResponsesHostServer(agent)
    server.run()


if __name__ == "__main__":
    main()