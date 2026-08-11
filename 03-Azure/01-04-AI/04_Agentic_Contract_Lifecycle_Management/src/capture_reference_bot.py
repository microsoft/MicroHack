"""Challenge 5 (Task 6 helper) — capture a Teams conversation reference.

WHY THIS EXISTS
    Proactive alerts (``proactive_alerts.py``) need a *saved conversation
    reference* — the **service URL** + **conversation id** of a real Teams chat
    with a bot **whose identity you own**. The Foundry-published agent is a
    **managed** bot: its app registration lives in another tenant, so you can't
    create a client secret for it and can't authenticate a local handler as it.

    So you stand up your **own** throwaway single-tenant Azure Bot and message
    *that* one. This tiny aiohttp bot, built with YOUR ``MICROSOFT_APP_ID`` /
    ``MICROSOFT_APP_PASSWORD`` / ``MICROSOFT_APP_TENANT_ID``, validates the
    inbound Teams token against your app id, then writes ``TEAMS_SERVICE_URL`` +
    ``TEAMS_CONVERSATION_ID`` into your ``.env`` so ``proactive_alerts.py`` can
    post through the same bot.

RUN (see challenges/challenge-05.md · Task 6)
    1. pip install -r requirements.txt        # botbuilder-integration-aiohttp, aiohttp
    2. Register your OWN single-tenant app: Entra ID -> App registrations ->
       New registration (this org only) -> Certificates & secrets -> new client
       secret. Put MICROSOFT_APP_ID / MICROSOFT_APP_PASSWORD /
       MICROSOFT_APP_TENANT_ID in .env.
    3. Create an Azure Bot that reuses it (Type of App = Single Tenant, Use
       existing app registration) and enable Channels -> Microsoft Teams.
    4. python src/capture_reference_bot.py    # listens on http://localhost:3978/api/messages
    5. Expose it publicly with a dev tunnel:
         devtunnel host -p 3978 --allow-anonymous       # or:  ngrok http 3978
    6. Your Bot -> Configuration -> Messaging endpoint =
         https://<tunnel-host>/api/messages   -> Apply
    7. Message YOUR bot ANY text ("hi") via Channels -> Teams -> Open in Teams.
       This bot captures the reference, writes it to .env, and replies to
       confirm. Then send the alert:
         python src/proactive_alerts.py --from-renewals --days 30

NO LOCAL RUN / NO TUNNEL (alternative to steps 4-6)
    Deploy this bot to Azure Container Apps instead (builds in the cloud, no local
    Docker); it reads MICROSOFT_APP_ID / MICROSOFT_APP_PASSWORD /
    MICROSOFT_APP_TENANT_ID from .env:
     bash deploy/capture-bot/deploy.sh      # or: pwsh deploy/capture-bot/deploy.ps1
    Point your Azure Bot's messaging endpoint at the printed
    https://<app>.azurecontainerapps.io/api/messages, then message it once in Teams.
    The bot echoes TEAMS_SERVICE_URL + TEAMS_CONVERSATION_ID back in the chat — paste
    those two lines into your local .env, then run proactive_alerts.py.
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
# Local runs bind localhost; the container (deploy/capture-bot) sets 0.0.0.0 so
# the Container Apps ingress can reach it.
_HOST = os.environ.get("CAPTURE_BOT_HOST", "localhost")


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
    print("  You can stop this bot (Ctrl+C) and run:")
    print("    python src/proactive_alerts.py --from-renewals --days 30\n")

    # Echo the two values back into the chat as well. When this bot runs in Azure
    # (deploy/capture-bot) it writes to the *container's* .env, not yours — so the
    # reply is how you retrieve them: copy these lines into your local .env.
    await turn_context.send_activity(
        "✅ Saved this conversation for proactive CLM alerts.\n\n"
        "If this bot is running in Azure (not on your laptop), copy these two lines "
        "into your local `.env`, then run "
        "`python src/proactive_alerts.py --from-renewals --days 30`:\n\n"
        f"```\nTEAMS_SERVICE_URL={service_url}\nTEAMS_CONVERSATION_ID={conversation_id}\n```"
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
    print(f"Capture bot listening on http://{_HOST}:{_PORT}/api/messages")
    print("Local: expose it with `devtunnel host -p 3978 --allow-anonymous`, then point your")
    print("Azure Bot's messaging endpoint at https://<tunnel>/api/messages.")
    print("No local run/tunnel? Deploy it instead:  bash deploy/capture-bot/deploy.sh")
    web.run_app(app, host=_HOST, port=_PORT)


if __name__ == "__main__":
    main()
