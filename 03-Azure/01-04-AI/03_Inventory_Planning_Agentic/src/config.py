"""Central configuration for the hosted agents and the planner-console UI.

All values come from environment variables so the same code runs unchanged in a
Codespace, locally, or in the Foundry-hosted runtime. Copy ``.env.example`` to
``.env`` and fill in the three values your lab dashboard gives you.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    # Optional convenience: load src/.env (next to this file) if python-dotenv is
    # installed, so values load no matter which directory you launch from.
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).with_name(".env"))
except ImportError:  # pragma: no cover - dotenv is optional
    pass

# The Foundry project endpoint from your lab dashboard, e.g.
# https://inv-xxxxxxxx.services.ai.azure.com/api/projects/inventory-hack
PROJECT_ENDPOINT = os.getenv("PROJECT_ENDPOINT", "").strip()

# The model deployment name from your lab dashboard (default: gpt-5.4-mini).
#
# Model choice matters: this hack depends on the agent (1) reliably CALLING its
# function tools and (2) returning STRUCTURED JSON. gpt-5.4-mini is a low-cost
# GPT-5 model whose Foundry model card confirms BOTH Functions/Tools and
# Structured Outputs, it runs on GlobalStandard in EU regions, and it has the
# longest support horizon among the low-cost GPT-5 models (retires 2027-03-18).
#
# If you change this, pick a model whose Foundry model card shows Functions/Tools
# + Structured Outputs. Avoid already-DEPRECATED models (gpt-4.1-mini and
# gpt-4o-mini retire in Oct 2026) and the older o-series reasoning models
# (o1/o3/o4), which can refuse tool calls. A solid fallback is gpt-5-mini.
# Re-run `python cli.py` after any change to confirm every step still calls tools.
MODEL_DEPLOYMENT_NAME = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4-mini").strip()

# Optional: enable the Web Search grounding tool on the demand-sensing agent.
ENABLE_WEB_SEARCH = os.getenv("ENABLE_WEB_SEARCH", "false").strip().lower() == "true"

# The per-attendee Cosmos DB for NoSQL account endpoint from your lab dashboard, e.g.
# https://inv-cos-xxxxxxxx.documents.azure.com:443/  (provisioned by labautomation).
COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT", "").strip()
COSMOS_DATABASE = os.getenv("COSMOS_DATABASE", "inventory").strip()

# Reasoning effort for GPT-5 reasoning models (gpt-5.4-mini is one). Lower effort =
# faster, snappier responses with fewer hidden reasoning tokens — ideal for the
# interactive planner console. Valid: minimal | low | medium | high | none | default.
# "minimal" is the sweet spot for this tool-driven hack. Set to "default" (or empty)
# to let the model decide, or if you switch to a non-reasoning model.
REASONING_EFFORT = os.getenv("REASONING_EFFORT", "minimal").strip().lower()


def effective_reasoning_effort() -> str | None:
    """Return the reasoning-effort value to send, or None to omit the parameter."""
    if REASONING_EFFORT in ("", "default", "auto", "off"):
        return None
    return REASONING_EFFORT


def require_endpoint() -> str:
    """Return the project endpoint or raise a clear, actionable error."""
    if not PROJECT_ENDPOINT:
        raise RuntimeError(
            "PROJECT_ENDPOINT is not set. Copy .env.example to .env and paste the "
            "FoundryProjectEndpoint value from your lab dashboard (Challenge 0)."
        )
    return PROJECT_ENDPOINT


def require_cosmos_endpoint() -> str:
    """Return the Cosmos DB endpoint or raise a clear, actionable error."""
    if not COSMOS_ENDPOINT:
        raise RuntimeError(
            "COSMOS_ENDPOINT is not set. Copy .env.example to .env and paste the "
            "CosmosEndpoint value from your lab dashboard (Challenge 0)."
        )
    return COSMOS_ENDPOINT
