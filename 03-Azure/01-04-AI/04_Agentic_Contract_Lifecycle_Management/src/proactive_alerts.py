"""Challenge 5 — proactive Teams alerts via the Bot Framework.

Sends a proactive (unprompted) message into a Teams channel/chat using a saved
conversation reference — this is how the Obligation & Renewal agent pushes
"contract renews in 30 days / high-risk clause flagged" alerts without the user
asking first.

FLOW
1. When your published bot receives ANY inbound message, save
   `TurnContext.get_conversation_reference(activity)` (persist it). The values
   land in .env as TEAMS_* by your bot's message handler.
2. Later (on a schedule, or when the renewal agent finds something), call
   `send_proactive_alert(text)` which uses `ADAPTER.continue_conversation(...)`
   to post into that saved conversation.

This module is runnable in two ways:
    python src/proactive_alerts.py --text "🔴 Contract CT-4821 renews in 30 days…"
    python src/proactive_alerts.py --from-renewals --days 30   # generate + send

Requires: MICROSOFT_APP_ID / MICROSOFT_APP_PASSWORD / MICROSOFT_APP_TENANT_ID and a saved
conversation reference (TEAMS_SERVICE_URL, TEAMS_CONVERSATION_ID) — all set once the bot is
published and has received one message (see README).
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))             # src (clm_common)
sys.path.insert(0, str(Path(__file__).resolve().parent / "agents"))  # agent modules

from clm_common.config import settings  # noqa: E402


def _conversation_reference():
    """Rebuild a ConversationReference from env saved by the bot's message handler."""
    from botbuilder.schema import ConversationReference, ConversationAccount, ChannelAccount

    app_id = os.environ.get("MICROSOFT_APP_ID", "")
    service_url = os.environ.get("TEAMS_SERVICE_URL", "")
    conversation_id = os.environ.get("TEAMS_CONVERSATION_ID", "")
    if not (app_id and service_url and conversation_id):
        raise RuntimeError(
            "Missing MICROSOFT_APP_ID / TEAMS_SERVICE_URL / TEAMS_CONVERSATION_ID. "
            "Publish the bot (Ch5), send it one message, and save the conversation reference. "
            "See challenges/challenge-05.md."
        )
    return ConversationReference(
        channel_id="msteams",
        service_url=service_url,
        bot=ChannelAccount(id=f"28:{app_id}"),
        conversation=ConversationAccount(id=conversation_id),
    )


def _adapter():
    from botbuilder.core import BotFrameworkAdapter, BotFrameworkAdapterSettings

    return BotFrameworkAdapter(
        BotFrameworkAdapterSettings(
            app_id=os.environ.get("MICROSOFT_APP_ID", ""),
            app_password=os.environ.get("MICROSOFT_APP_PASSWORD", ""),
        )
    )


async def _send(text: str) -> None:
    from botbuilder.core import TurnContext

    adapter = _adapter()
    reference = _conversation_reference()

    async def _callback(turn_context: TurnContext):
        await turn_context.send_activity(text)

    await adapter.continue_conversation(
        reference, _callback, bot_id=os.environ.get("MICROSOFT_APP_ID", "")
    )
    print("✓ Proactive alert sent to Teams.")


def send_proactive_alert(text: str) -> None:
    """Post `text` proactively into the saved Teams conversation."""
    asyncio.run(_send(text))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", help="literal alert text to send")
    parser.add_argument("--from-renewals", action="store_true",
                        help="generate the alert from the Obligation & Renewal agent")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true",
                        help="print the alert instead of sending (no bot needed)")
    args = parser.parse_args()

    if args.from_renewals:
        from obligation_renewal_agent import summarize_renewals

        text = summarize_renewals(args.days)
    else:
        text = args.text or "🔴 Contract CT-4821 renewal approaching — high-risk indemnity clause flagged. Recommend legal review."

    if args.dry_run:
        print("--- alert (dry run) ---\n" + text)
        return

    send_proactive_alert(text)


if __name__ == "__main__":
    main()
