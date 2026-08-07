"""Challenge 5 (Task 6 helper) — capture a Teams conversation reference.

WHY THIS EXISTS
    Proactive alerts (``proactive_alerts.py``) need a *saved conversation
    reference* — the **service URL** + **conversation id** of a real Teams chat
    with your bot. A Foundry-published agent is a **managed** bot, so you don't
    own a message handler that could save that reference the first time a user
    writes to it. Without it, ``TEAMS_SERVICE_URL`` / ``TEAMS_CONVERSATION_ID``
    stay empty and ``proactive_alerts.py`` can't post anything.

    This tiny aiohttp bot fills the gap. Point your Azure Bot's messaging
    endpoint at it *temporarily*, send it **one** message from Teams, and it
    writes ``TEAMS_SERVICE_URL`` + ``TEAMS_CONVERSATION_ID`` into your ``.env``.
    Then revert the endpoint and run ``proactive_alerts.py``.

RUN (see challenges/challenge-05.md · Task 6)
    1. pip install -r requirements.txt        # botbuilder-integration-aiohttp, aiohttp
    2. In .env set MICROSOFT_APP_ID / MICROSOFT_APP_PASSWORD / MICROSOFT_APP_TENANT_ID
       (Azure portal -> your Bot -> Configuration; create a client secret for the
       app registration if you don't have the password).
    3. python src/capture_reference_bot.py    # listens on http://localhost:3978/api/messages
    4. Expose it publicly with a dev tunnel:
         devtunnel host -p 3978 --allow-anonymous       # or:  ngrok http 3978
    5. Azure portal -> your Bot -> Configuration -> Messaging endpoint =
         https://<tunnel-host>/api/messages   -> Apply
    6. In Teams, send your published agent ANY message ("hi"). This bot captures
       the reference, writes it to .env, and replies to confirm.
    7. Revert the messaging endpoint to the one Foundry set (so the agent keeps
       answering), then send the alert:
         python src/proactive_alerts.py --from-renewals --days 30
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from aiohttp import web
from botbuilder.core import BotFrameworkAdapter, BotFrameworkAdapterSettings, TurnContext
from botbuilder.core.integration import aiohttp_error_middleware
from botbuilder.schema import Activity

sys.path.insert(0, str(Path(__file__).resolve().parent))  # src (for optional .env load)

try:  # optional convenience — load .env if python-dotenv is installed
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
except Exception:  # noqa: BLE001 — dotenv is optional
    pass

_ENV_PATH = Path(__file__).resolve().parents[1] / ".env"
_PORT = int(os.environ.get("CAPTURE_BOT_PORT", "3978"))


def _adapter() -> BotFrameworkAdapter:
    """Same tenant-aware settings the proactive sender uses (single-tenant safe)."""
    return BotFrameworkAdapter(
        BotFrameworkAdapterSettings(
            app_id=os.environ.get("MICROSOFT_APP_ID", ""),
            app_password=os.environ.get("MICROSOFT_APP_PASSWORD", ""),
            channel_auth_tenant=os.environ.get("MICROSOFT_APP_TENANT_ID") or None,
        )
    )


def _upsert_env(values: dict[str, str]) -> None:
    """Write/replace KEY=value lines in the repo-root .env (creating it if absent)."""
    lines = _ENV_PATH.read_text(encoding="utf-8").splitlines() if _ENV_PATH.exists() else []
    remaining = dict(values)
    out: list[str] = []
    for line in lines:
        key = line.split("=", 1)[0].strip() if "=" in line and not line.lstrip().startswith("#") else None
        if key in remaining:
            out.append(f"{key}={remaining.pop(key)}")
        else:
            out.append(line)
    for key, val in remaining.items():  # keys not already present
        out.append(f"{key}={val}")
    _ENV_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")


ADAPTER = _adapter()


async def _on_turn(turn_context: TurnContext) -> None:
    reference = TurnContext.get_conversation_reference(turn_context.activity)
    service_url = reference.service_url or ""
    conversation_id = reference.conversation.id if reference.conversation else ""

    _upsert_env({"TEAMS_SERVICE_URL": service_url, "TEAMS_CONVERSATION_ID": conversation_id})
    os.environ["TEAMS_SERVICE_URL"] = service_url
    os.environ["TEAMS_CONVERSATION_ID"] = conversation_id

    print("\n✓ Captured Teams conversation reference — written to .env:")
    print(f"    TEAMS_SERVICE_URL={service_url}")
    print(f"    TEAMS_CONVERSATION_ID={conversation_id}")
    print("  You can stop this bot (Ctrl+C), revert the messaging endpoint, and run:")
    print("    python src/proactive_alerts.py --from-renewals --days 30\n")

    await turn_context.send_activity(
        "✅ Saved this conversation for proactive CLM alerts. "
        "You can close this and expect renewal/risk pings here."
    )


async def messages(req: web.Request) -> web.Response:
    if "application/json" not in req.headers.get("Content-Type", ""):
        return web.Response(status=415)
    activity = Activity().deserialize(await req.json())
    auth_header = req.headers.get("Authorization", "")
    await ADAPTER.process_activity(activity, auth_header, _on_turn)
    return web.Response(status=201)


def main() -> None:
    if not os.environ.get("MICROSOFT_APP_ID"):
        print("⚠ MICROSOFT_APP_ID is not set. Set the bot's app id/password/tenant in .env first.")
    app = web.Application(middlewares=[aiohttp_error_middleware])
    app.router.add_post("/api/messages", messages)
    print(f"Capture bot listening on http://localhost:{_PORT}/api/messages")
    print("Expose it (devtunnel host -p 3978 --allow-anonymous), point your Azure Bot's")
    print("messaging endpoint at https://<tunnel>/api/messages, then message the agent in Teams.")
    web.run_app(app, host="localhost", port=_PORT)


if __name__ == "__main__":
    main()
