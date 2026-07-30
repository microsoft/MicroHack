#!/usr/bin/env python
"""azd preprovision hook — auto-skip Claude Opus 4.8 when the subscription has no quota.

`azd up` provisions labautomation/infra/main.bicep, whose Claude model deployment is
gated by the `deployClaudeModel` parameter (sourced from the `DEPLOY_CLAUDE_MODEL`
azd env var, default "true"). Unlike the platform `deploy-lab.ps1`, plain `azd up`
has no quota preflight, so on a subscription/region with **0** Anthropic Claude Opus
4.8 quota the deployment fails preflight with:

    InsufficientQuota: This operation require 20 new capacity in quota Tokens Per
    Minute (thousands) - Claude Opus 4.8, which is bigger than the current available
    capacity 0. ... the quota limit is 0 for quota ... Claude Opus 4.8.

This hook probes that quota *before* provisioning and, when it is insufficient, runs
`azd env set DEPLOY_CLAUDE_MODEL false` so Bicep skips Claude and the deploy still
succeeds GPT-only (the Drafting agent falls back to the GPT orchestrator; Clause &
Risk stays on gpt-5.6-sol). When quota is sufficient it sets it back to "true", so a
teammate who is later granted quota gets Claude again on the next `azd up`.

Availability != quota: Claude Opus 4.8 is only *offered* in some regions (e.g.
swedencentral, not norwayeast/francecentral), but even there a fresh sandbox
subscription usually starts at 0 allocated capacity — which is exactly this case.

Override (skip the probe): set DEPLOY_CLAUDE_MODEL_FORCE=true|false in your shell
before `azd up` to force Claude on or off regardless of the probe.

Fail-safe: any error (no region yet, az not signed in, API hiccup) disables Claude so
`azd up` never fails on this. Force it on with DEPLOY_CLAUDE_MODEL_FORCE=true once you
have quota.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys

MODEL_NAME = "claude-opus-4-8"
QUOTA_FAMILY = f"AIServices.GlobalStandard.{MODEL_NAME}"
REQUIRED_CAPACITY = 20  # matches sku.capacity in resources.bicep (GlobalStandard, 20)

# Print status glyphs safely on Windows consoles (cp1252) too.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001
        pass


def _az_bin() -> str | None:
    return shutil.which("az")


def _azd_bin() -> str | None:
    return shutil.which("azd")


def _run(cmd: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False, shell=False)
    return proc.returncode, (proc.stdout or "").strip(), (proc.stderr or "").strip()


def _set_flag(value: str, reason: str) -> None:
    """Persist DEPLOY_CLAUDE_MODEL into the selected azd environment."""
    azd = _azd_bin()
    label = "deploy Claude Opus 4.8" if value == "true" else "skip Claude (GPT-only)"
    print(f"  Claude preflight: {reason} -> DEPLOY_CLAUDE_MODEL={value} ({label}).")
    if not azd:
        # No azd on PATH (e.g. run standalone) — nothing to persist; Bicep keeps its default.
        print("  Claude preflight: `azd` not found on PATH; leaving the azd env unchanged.")
        return
    code, _out, err = _run([azd, "env", "set", "DEPLOY_CLAUDE_MODEL", value])
    if code != 0:
        print(f"  Claude preflight: WARN could not `azd env set DEPLOY_CLAUDE_MODEL {value}`: {err}")


def _resolve_subscription() -> str:
    sub = os.environ.get("AZURE_SUBSCRIPTION_ID", "").strip()
    if sub:
        return sub
    az = _az_bin()
    if not az:
        return ""
    code, out, _err = _run([az, "account", "show", "--query", "id", "-o", "tsv"])
    return out if code == 0 else ""


def _probe_quota(subscription_id: str, region: str) -> tuple[bool, str]:
    """Return (has_capacity, detail). has_capacity False on any uncertainty (fail-safe)."""
    az = _az_bin()
    if not az:
        return False, "Azure CLI (`az`) not found on PATH"

    url = (
        f"https://management.azure.com/subscriptions/{subscription_id}"
        f"/providers/Microsoft.CognitiveServices/locations/{region}"
        f"/usages?api-version=2024-10-01"
    )
    code, out, err = _run([az, "rest", "--method", "get", "--url", url])
    if code != 0:
        return False, f"usages query failed ({err or 'non-zero exit'})"

    try:
        usages = (json.loads(out) or {}).get("value", []) if out else []
    except json.JSONDecodeError:
        return False, "could not parse the usages response"

    def _name(entry: dict) -> str:
        name = entry.get("name")
        if isinstance(name, dict):
            return str(name.get("value", ""))
        return str(name or "")

    entry = next((u for u in usages if _name(u) == QUOTA_FAMILY), None)
    if entry is None:
        # Fall back to any entry mentioning the model (naming varies across API versions).
        candidates = [u for u in usages if MODEL_NAME in _name(u)]
        candidates.sort(key=lambda u: float(u.get("limit", 0) or 0), reverse=True)
        entry = candidates[0] if candidates else None
    if entry is None:
        return False, f"no Anthropic quota entry for '{MODEL_NAME}' in '{region}'"

    limit = float(entry.get("limit", 0) or 0)
    used = float(entry.get("currentValue", 0) or 0)
    available = limit - used
    if limit <= 0 or available < REQUIRED_CAPACITY:
        return False, (
            f"insufficient quota in '{region}' "
            f"(limit={limit:g}, used={used:g}, need={REQUIRED_CAPACITY})"
        )
    return True, f"'{MODEL_NAME}' deployable in '{region}' (limit={limit:g}, used={used:g})"


def main() -> None:
    print("azd preprovision - Anthropic Claude Opus 4.8 quota preflight")

    force = os.environ.get("DEPLOY_CLAUDE_MODEL_FORCE", "").strip().lower()
    if force in ("true", "false"):
        _set_flag(force, f"DEPLOY_CLAUDE_MODEL_FORCE={force} (skipping quota probe)")
        return

    region = os.environ.get("AZURE_LOCATION", "").strip()
    if not region:
        _set_flag("false", "target region not resolved yet (AZURE_LOCATION unset)")
        return

    subscription_id = _resolve_subscription()
    if not subscription_id:
        _set_flag("false", "could not resolve the subscription id (run `az login` / `azd auth login`)")
        return

    has_capacity, detail = _probe_quota(subscription_id, region)
    _set_flag("true" if has_capacity else "false", detail)


if __name__ == "__main__":
    main()
