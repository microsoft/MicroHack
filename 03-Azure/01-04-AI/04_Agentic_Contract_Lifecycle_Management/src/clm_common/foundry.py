"""Microsoft Agent Framework helpers shared across challenges.

Every CLM agent in this repo is built with the **Microsoft Agent Framework**
(`agent-framework` + `agent-framework-foundry`). Foundry is used as the *chat
client provider*, which keeps the multi-model GPT fleet (one deployment per
specialist in a single Foundry project) and Foundry IQ / Azure AI Search
grounding available while the agent, tool-calling and orchestration APIs stay
provider-agnostic.

The framework is async-first. This module gives challenge scripts one obvious way
to build a client, wrap a plain function as an auto-executed tool, and run a
prompt from either sync or async code:

    from clm_common.foundry import build_chat_client, function_tool, run_prompt
    from agent_framework import Agent

    agent = Agent(
        client=build_chat_client(settings.model_drafting),
        name="intake-drafting-agent",
        instructions=INSTRUCTIONS,
        tools=[function_tool(get_contract_status)],
    )
    print(run_prompt(agent, "Draft a mutual NDA for Acme."))     # sync callers
    text = await run_agent(agent, "…")                           # async callers
"""
from __future__ import annotations

import asyncio
import random
import threading
from typing import Any, Callable

from .config import settings, credential


def build_chat_client(model: str):
    """Return a `FoundryChatClient` bound to a specific model deployment.

    The SAME call backs any agent in the fleet — only ``model`` changes, which is
    what lets the microhack run a multi-model GPT fleet inside one Foundry
    project.
    """
    from agent_framework.foundry import FoundryChatClient

    return FoundryChatClient(
        model=model,
        project_endpoint=settings.require_project(),
        credential=credential(),
    )


def function_tool(func: Callable[..., Any]):
    """Wrap a plain Python function as an auto-executing Agent Framework tool.

    The type hints + docstring become the tool's JSON schema. ``approval_mode``
    is ``never_require`` so tools run automatically in these headless scripts;
    use ``always_require`` in an interactive/production app that wants a human to
    approve each call.
    """
    from agent_framework import tool

    return tool(approval_mode="never_require")(func)


async def run_agent(agent, prompt: str, *, session=None) -> str:
    """Run `prompt` on `agent` and return the reply text (async, framework-native)."""
    result = await agent.run(prompt, session=session)
    return result.text


# --- Rate-limit-aware retry --------------------------------------------------
# The shared Foundry model deployments (gpt-5.4 / gpt-5.6-sol / gpt-5.4-nano)
# are throughput-throttled, so a burst of demo prompts can hit HTTP 429
# `rate_limit_exceeded` and crash a run mid-way. `run_agent_with_retry` retries
# transient rate-limit errors with exponential backoff (honouring a Retry-After
# header when present) so demos and eval loops ride through throttling instead of
# aborting. Non-rate-limit errors are re-raised immediately.
_RATE_LIMIT_MARKERS = ("rate limit", "rate_limit", "too many requests", "429")


def _is_rate_limit_error(exc: BaseException) -> bool:
    """True if `exc` (or a cause in its chain) looks like an HTTP 429 throttle."""
    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        status = getattr(current, "status_code", None) or getattr(
            getattr(current, "response", None), "status_code", None
        )
        if status == 429:
            return True
        if type(current).__name__ == "RateLimitError":
            return True
        message = str(current).lower()
        if any(marker in message for marker in _RATE_LIMIT_MARKERS):
            return True
        current = current.__cause__ or current.__context__
    return False


def _retry_after_seconds(exc: BaseException) -> float | None:
    """Return the server's Retry-After hint (seconds) if the error carries one."""
    headers = getattr(getattr(exc, "response", None), "headers", None)
    if not headers:
        return None
    value = None
    if hasattr(headers, "get"):
        value = headers.get("retry-after") or headers.get("Retry-After")
    try:
        return float(value) if value is not None else None
    except (TypeError, ValueError):
        return None


async def run_agent_with_retry(
    agent,
    prompt: str,
    *,
    session=None,
    max_attempts: int = 5,
    base_delay: float = 2.0,
    max_delay: float = 60.0,
) -> str:
    """Like `run_agent`, but retry rate-limit (429) errors with exponential backoff.

    Retries only when the error looks like throttling; anything else propagates on
    the first attempt. Backoff is ``base_delay * 2**(attempt-1)`` (capped at
    ``max_delay``) plus jitter, unless the server sends a ``Retry-After`` header.
    After ``max_attempts`` the last error is re-raised so the caller can decide
    whether to skip or fail.
    """
    for attempt in range(1, max_attempts + 1):
        try:
            return await run_agent(agent, prompt, session=session)
        except Exception as exc:  # noqa: BLE001 — inspect, then re-raise if not throttling
            if attempt >= max_attempts or not _is_rate_limit_error(exc):
                raise
            delay = _retry_after_seconds(exc)
            if delay is None:
                delay = min(max_delay, base_delay * (2 ** (attempt - 1)))
                delay += random.uniform(0, delay * 0.25)  # jitter to de-sync retries
            await asyncio.sleep(delay)
    raise RuntimeError("run_agent_with_retry exhausted retries without returning")


# One event loop per thread. Reusing a live loop across repeated sync calls keeps
# the framework's underlying async HTTP client bound to an open loop (a fresh
# asyncio.run() per call would close the loop and break the next call), while
# per-thread isolation keeps it safe when a harness (e.g. azure-ai-evaluation)
# invokes a target from worker threads.
_local = threading.local()


def _thread_loop() -> asyncio.AbstractEventLoop:
    loop = getattr(_local, "loop", None)
    if loop is None or loop.is_closed():
        loop = asyncio.new_event_loop()
        _local.loop = loop
    return loop


def run_prompt(agent, prompt: str, *, session=None) -> str:
    """Single-turn helper for **sync** callers: run `prompt`, return the reply text."""
    return _thread_loop().run_until_complete(run_agent(agent, prompt, session=session))


def get_project_client():
    """Return an authenticated AIProjectClient for the configured Foundry project.

    Still used to resolve project connections (e.g. the default Azure AI Search
    connection that backs Foundry IQ grounding). Endpoint format:
        https://<resource>.services.ai.azure.com/api/projects/<project>
    """
    from azure.ai.projects import AIProjectClient

    return AIProjectClient(endpoint=settings.require_project(), credential=credential())
