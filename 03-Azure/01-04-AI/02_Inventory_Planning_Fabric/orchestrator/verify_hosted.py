"""Exercise the deployed assistant; this does not certify Teams/M365 web channels."""

import argparse
from collections.abc import Callable
from contextlib import ExitStack
import json
from pathlib import Path
import re
import time
from typing import Any

from azure.ai.projects import AIProjectClient
from azure.identity import AzureCliCredential


SCENARIO = (
    "A prolonged heatwave is hitting the Pacific Northwest. Check our exposure on "
    "outdoor power tools and prepare a replenishment order for approval. "
    "Include Leaf Blower X2 (P004) at Seattle and Portland. Use real Fabric data."
)
TOTAL_TURNS = 12
ENDPOINT_ATTEMPTS = 3
ENDPOINT_WAIT_SECONDS = 20


class HostedEndpointUnavailable(RuntimeError):
    """Foundry's hosted-agent endpoint does not recognise the project, so no check can run."""


def require(text: str, expected: str) -> None:
    if expected not in text:
        raise AssertionError(f"Expected {expected!r} in hosted response, got:\n{text}")


def create_conversation(client: Any, sleep: Callable[[float], None] = time.sleep) -> Any:
    for attempt in range(1, ENDPOINT_ATTEMPTS + 1):
        try:
            return client.conversations.create()
        except Exception as error:
            if getattr(error, "status_code", None) != 404 or "Project not found" not in str(error):
                raise
            if attempt < ENDPOINT_ATTEMPTS:
                print(f"The hosted agent endpoint is not ready yet (attempt {attempt}/{ENDPOINT_ATTEMPTS}). "
                      f"Waiting {ENDPOINT_WAIT_SECONDS} seconds...", flush=True)
                sleep(ENDPOINT_WAIT_SECONDS)
    raise HostedEndpointUnavailable(
        "The assistant deployed, but Foundry's hosted-agent endpoint answered 'Project not found'. "
        "Wait a few minutes and rerun the same command. If it still fails, tell your facilitator: "
        "this can happen when the Foundry account name was used and deleted earlier."
    )


def proposal_token(text: str) -> tuple[str, int]:
    match = re.search(r"Proposal: ([0-9a-f]{32}) \| Revision: ([0-9]+) \| Status: AWAITING_APPROVAL", text)
    if not match:
        raise AssertionError(f"No pending proposal ID/revision in hosted response:\n{text}")
    return match[1], int(match[2])


def stop_test_session(project: AIProjectClient, name: str, session_id: str) -> None:
    if project.agents.get_session(name, session_id).status != "idle":
        project.agents.stop_session(name, session_id)
    if project.agents.get_session(name, session_id).status != "idle":
        raise RuntimeError(f"Test sandbox {session_id} did not stop.")


def exercise(client: Any, name: str, version: str, records: list[dict[str, Any]],
             stop_session: Callable[[str], None] | None = None,
             sleep: Callable[[float], None] = time.sleep) -> None:
    with ExitStack() as cleanup:
        sessions: set[str] = set()
        first = create_conversation(client, sleep).id
        cleanup.callback(client.conversations.delete, conversation_id=first)
        second = create_conversation(client, sleep).id
        cleanup.callback(client.conversations.delete, conversation_id=second)
        passed = 0

        def turn(conversation: str, prompt: str, *expected: str) -> str:
            nonlocal passed
            label = "planning request" if prompt == SCENARIO else prompt.split()[0]
            if prompt == SCENARIO:
                print(f"Turn {passed + 1}/{TOTAL_TURNS}: {label} (takes 2-4 minutes)...", flush=True)
            started = time.monotonic()
            response = client.responses.create(
                conversation=conversation, input=prompt, store=True,
                extra_body={"agent_reference": {"type": "agent_reference", "name": name, "version": version}},
            )
            text = response.output_text
            session_id = getattr(response, "agent_session_id", None)
            if session_id and session_id not in sessions and stop_session is not None:
                sessions.add(session_id)
                cleanup.callback(stop_session, session_id)
            error = getattr(response, "error", None)
            records.append({
                "conversation": conversation, "input": prompt, "response_id": response.id,
                "status": response.status, "output": text,
                "agent_session_id": session_id,
                "seconds": round(time.monotonic() - started, 1),
                "error": error.model_dump() if error is not None else None,
            })
            if response.status != "completed":
                raise AssertionError(f"Hosted response did not complete: {response.model_dump_json()}")
            for value in expected:
                require(text, value)
            passed += 1
            print(f"Turn {passed}/{TOTAL_TURNS} passed: {label} ({records[-1]['seconds']} s)", flush=True)
            return text

        turn(first, "STATUS", "No proposal exists")
        text = turn(first, SCENARIO, "PURCHASE ORDER PROPOSAL (simulation only)", "P004",
                    "Total estimated value:", "No real ERP")
        proposal, revision = proposal_token(text)
        turn(second, f"YES {proposal} {revision}", "No proposal exists")
        changed = turn(first, f"MODIFY {proposal} {revision} 1 50")
        changed_id, changed_revision = proposal_token(changed)
        if changed_id != proposal or changed_revision != revision + 1:
            raise AssertionError("MODIFY did not preserve proposal ID and increment revision.")
        require(changed, "| 50 |")
        turn(first, f"YES {proposal} {revision}", "stale", "AWAITING_APPROVAL")
        approval = f"YES {proposal} {changed_revision}"
        turn(first, approval, "SIMULATED submission:", "Status: APPROVED")
        turn(first, approval, "No duplicate submission")
        turn(first, "STATUS", "Status: APPROVED")
        turn(first, "NEW", "Ready for a new planning request")
        text = turn(first, SCENARIO)
        proposal, revision = proposal_token(text)
        turn(first, f"NO {proposal} {revision}", "Order cancelled.", "Status: CANCELLED")
        turn(first, "STATUS", "Status: CANCELLED")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--name", default="inventory-planning-assistant")
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    records: list[dict[str, Any]] = []
    passed = False
    exception: str | None = None
    try:
        with AzureCliCredential() as credential, AIProjectClient(
            endpoint=args.endpoint, credential=credential,
        ) as project, project.get_openai_client(
            agent_name=args.name, timeout=600, max_retries=0,
        ) as client:
            exercise(
                client, args.name, args.version, records,
                stop_session=lambda session_id: stop_test_session(project, args.name, session_id),
            )
        passed = True
    except BaseException as error:
        exception = f"{type(error).__name__}: {error}"[:1500]
        raise
    finally:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps({
            "passed": passed, "agent": args.name, "version": args.version,
            "endpoint": args.endpoint, "turns": records, "exception": exception,
            "not_tested": ["Teams/M365 web", "second user", "denied Fabric access", "idle/restart",
                           "Fabric cost correctness and tool traces (inspect separately)"],
        }, indent=2), encoding="utf-8")
    print(f"PASS: hosted multi-turn checks. Evidence: {args.output}")
    print("Teams/M365 web, delegated access and real-data accuracy still need verification.")


if __name__ == "__main__":
    try:
        main()
    except HostedEndpointUnavailable as error:
        raise SystemExit(f"FAIL: {error}") from None
