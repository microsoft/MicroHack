#!/usr/bin/env python
"""Challenge 1 · one-command SharePoint corpus setup (self-service, no coach).

For sandbox tenants where **you are an admin of your own tenant** (the MicroHack
default), this does the *entire* SharePoint grounding path end to end so the
Azure AI Search SharePoint indexer becomes the default corpus source — no manual
portal clicks, no coach hand-off:

    python src/scripts/setup_sharepoint_corpus.py

Steps (all idempotent — safe to re-run):
    1. Entra app registration — create/reuse an app, add the Microsoft Graph
       *application* permissions the indexer needs (Sites.ReadWrite.All +
       Files.Read.All) and **grant admin consent** for your tenant (done as you,
       the tenant admin, so the greyed-out "Grant admin consent" wall never
       applies here). Mint a client secret.
    2. SharePoint site — provision (or reuse) a Microsoft 365 group, which comes
       with a SharePoint team site + default "Documents" library. Pass
       --site-url to use a site you already have instead.
    3. .env — upsert the five SHAREPOINT_* values (and, when azd is present,
       mirror them with `azd env set` so a later provision keeps them).
    4. Upload — push the 14 corpus PDFs from src/data/ into the library.
    5. Index — run src/scripts/seed_corpus.py to build the clm-corpus index from
       the SharePoint library via the SharePoint Online indexer.

Prerequisites:
    - Azure CLI (`az`) installed and signed in (`az login` / `--use-device-code`)
      as an admin of the sandbox tenant.
    - A completed Challenge 1 deploy (so .env already has AZURE_SEARCH_ENDPOINT
      etc.). This script only *adds* the SHAREPOINT_* values.

No admin rights / not your own tenant? Skip this and use the local-PDF fallback:
    (leave SHAREPOINT_* blank and run `python src/scripts/seed_corpus.py`).
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import quote

# Print the ✓/·/— status glyphs safely on Windows consoles (cp1252) too.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001 — older/edge streams without reconfigure
        pass

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = REPO_ROOT / ".env"
SCRIPTS_DIR = Path(__file__).resolve().parent

GRAPH = "https://graph.microsoft.com/v1.0"
GRAPH_APP_ID = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
GRAPH_ROLES = ("Sites.ReadWrite.All", "Files.Read.All")

SHAREPOINT_KEYS = (
    "SHAREPOINT_SITE_URL",
    "SHAREPOINT_DOC_LIBRARY",
    "SHAREPOINT_APP_ID",
    "SHAREPOINT_APP_SECRET",
    "SHAREPOINT_TENANT_ID",
)


class SetupError(RuntimeError):
    """A fatal, user-actionable setup failure."""


# --------------------------------------------------------------------------- #
# az CLI helpers
# --------------------------------------------------------------------------- #
def _az_bin() -> str:
    """Resolve the `az` executable once (on Windows this is az.cmd, not az.exe)."""
    path = shutil.which("az")
    if not path:
        raise SetupError("Azure CLI (`az`) not found on PATH. Install it, then run `az login`.")
    return path


def _az(args: list[str], *, check: bool = True, capture: bool = True) -> str:
    """Run an `az` command and return stdout (text)."""
    proc = subprocess.run(
        [_az_bin(), *args],
        cwd=REPO_ROOT,
        capture_output=capture,
        text=True,
        check=False,
        shell=False,
    )
    if check and proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()
        raise SetupError(f"`az {' '.join(args)}` failed:\n  {err}")
    return (proc.stdout or "").strip()


def _graph_token() -> str:
    """Acquire a Microsoft Graph access token via the signed-in az session (cached)."""
    if not _graph_token._cache:  # type: ignore[attr-defined]
        tok = _az(["account", "get-access-token", "--resource", "https://graph.microsoft.com",
                   "--query", "accessToken", "-o", "tsv"])
        if not tok:
            raise SetupError("Could not get a Microsoft Graph token via `az account get-access-token`.")
        _graph_token._cache = tok  # type: ignore[attr-defined]
    return _graph_token._cache  # type: ignore[attr-defined]


_graph_token._cache = ""  # type: ignore[attr-defined]


def _graph(method: str, path: str, body: dict | None = None, *, check: bool = True) -> tuple[int, object]:
    """Call Microsoft Graph directly over HTTPS (urllib).

    Bypasses `az rest`, whose URL argument is re-parsed by cmd.exe on Windows and
    truncates query strings at unquoted '&'. Returns (status_code, parsed_body).
    """
    url = path if path.startswith("http") else f"{GRAPH}{path}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + _graph_token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            status = resp.status
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        status = exc.code
        if check:
            raise SetupError(f"Graph {method} {url} → HTTP {status}:\n  {raw[:600]}")
    except urllib.error.URLError as exc:
        raise SetupError(f"Graph {method} {url} failed: {exc.reason}")
    parsed: object = raw
    if raw and raw.lstrip()[:1] in "{[":
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = raw
    return status, parsed


def _run_script(script: str, extra: list[str] | None = None) -> None:
    """Run a sibling Python script in a fresh process (so it re-reads .env)."""
    cmd = [sys.executable, str(SCRIPTS_DIR / script), *(extra or [])]
    print(f"  → {' '.join([Path(cmd[0]).name, *cmd[1:]])}")
    proc = subprocess.run(cmd, cwd=REPO_ROOT)
    if proc.returncode != 0:
        raise SetupError(f"{script} exited with code {proc.returncode}.")


# --------------------------------------------------------------------------- #
# Steps
# --------------------------------------------------------------------------- #
def preflight() -> dict[str, str]:
    """Confirm az login and return {tenant_id, user_id, user_name}."""
    acct = _az(["account", "show", "-o", "json"], check=False)
    if not acct:
        raise SetupError("Not signed in. Run `az login` (or `az login --use-device-code`) first.")
    data = json.loads(acct)
    tenant_id = data.get("tenantId", "")
    user_name = (data.get("user") or {}).get("name", "")
    user_id = _az(["ad", "signed-in-user", "show", "--query", "id", "-o", "tsv"], check=False)
    print(f"· Signed in as {user_name or '<unknown>'} · tenant {tenant_id}")
    return {"tenant_id": tenant_id, "user_id": user_id, "user_name": user_name}


def ensure_app(display_name: str) -> dict[str, str]:
    """Create/reuse the Entra app, grant Graph app perms + admin consent, mint a secret."""
    print("· Entra app registration + Graph permissions + admin consent")

    graph_sp_oid = _az(["ad", "sp", "show", "--id", GRAPH_APP_ID, "--query", "id", "-o", "tsv"])
    role_ids: dict[str, str] = {}
    for role in GRAPH_ROLES:
        rid = _az(
            ["ad", "sp", "show", "--id", GRAPH_APP_ID,
             "--query", f"appRoles[?value=='{role}'].id | [0]", "-o", "tsv"]
        )
        if not rid:
            raise SetupError(f"Could not resolve Microsoft Graph app-role id for '{role}'.")
        role_ids[role] = rid

    app_id = _az(["ad", "app", "list", "--display-name", display_name,
                  "--query", "[0].appId", "-o", "tsv"], check=False)
    if not app_id or app_id == "None":
        app_id = _az(["ad", "app", "create", "--display-name", display_name,
                      "--sign-in-audience", "AzureADMyOrg", "--query", "appId", "-o", "tsv"])
        print(f"  ✓ created app registration '{display_name}' ({app_id})")
    else:
        print(f"  ✓ reusing app registration '{display_name}' ({app_id})")

    # Ensure a service principal exists for the app.
    sp_oid = _az(["ad", "sp", "show", "--id", app_id, "--query", "id", "-o", "tsv"], check=False)
    if not sp_oid:
        sp_oid = _az(["ad", "sp", "create", "--id", app_id, "--query", "id", "-o", "tsv"])

    # Record the required permissions on the app manifest (so the portal shows them).
    _az(["ad", "app", "permission", "add", "--id", app_id, "--api", GRAPH_APP_ID,
         "--api-permissions", *[f"{role_ids[r]}=Role" for r in GRAPH_ROLES]], check=False)

    # Grant admin consent deterministically by creating app-role assignments on the
    # Graph service principal (more reliable than `az ad app permission admin-consent`).
    for role, rid in role_ids.items():
        status, _resp = _graph(
            "POST",
            f"/servicePrincipals/{sp_oid}/appRoleAssignments",
            {"principalId": sp_oid, "resourceId": graph_sp_oid, "appRoleId": rid},
            check=False,
        )
        if status in (200, 201):
            print(f"  ✓ admin consent granted · {role}")
        # HTTP 400/409 ("permission already exists") is fine — _consent_complete is the gate.
    if not _consent_complete(sp_oid, graph_sp_oid, set(role_ids.values())):
        raise SetupError(
            "Admin consent did not take effect. You must be a tenant admin "
            "(Global Administrator / Privileged Role Administrator / Application "
            "Administrator) in this tenant. If you are not, use the local-PDF "
            "fallback instead: leave SHAREPOINT_* blank and run "
            "`python src/scripts/seed_corpus.py`."
        )
    print("  ✓ admin consent confirmed for both Graph permissions")

    secret = _az(["ad", "app", "credential", "reset", "--id", app_id,
                  "--display-name", "clm-microhack", "--years", "1",
                  "--query", "password", "-o", "tsv"])
    print("  ✓ client secret minted")
    return {"app_id": app_id, "sp_oid": sp_oid, "secret": secret}


def _consent_complete(sp_oid: str, graph_sp_oid: str, want_role_ids: set[str]) -> bool:
    """True once every wanted Graph app-role is assigned to our service principal."""
    for _ in range(6):
        _status, body = _graph(
            "GET",
            f"/servicePrincipals/{sp_oid}/appRoleAssignments?$select=appRoleId,resourceId",
            check=False,
        )
        assigned: set[str] = set()
        if isinstance(body, dict):
            assigned = {
                a.get("appRoleId")
                for a in body.get("value", [])
                if a.get("resourceId") == graph_sp_oid
            }
        if want_role_ids.issubset(assigned):
            return True
        time.sleep(5)
    return False


def _slug(text: str) -> str:
    s = re.sub(r"[^0-9A-Za-z]+", "-", text).strip("-").lower()
    return s or "clm-microhack-corpus"


def ensure_site(display_name: str, user_id: str) -> str:
    """Provision (or reuse) an M365 group's SharePoint site; return its webUrl."""
    print("· SharePoint site (Microsoft 365 group)")
    nickname = _slug(display_name)

    # Reuse an existing group of the same mailNickname.
    flt = quote(f"mailNickname eq '{nickname}'")
    _status, body = _graph(
        "GET", f"/groups?$filter={flt}&$select=id,displayName,mailNickname", check=False
    )
    group_id = ""
    if isinstance(body, dict):
        vals = body.get("value", [])
        if vals:
            group_id = vals[0].get("id", "")

    if group_id:
        print(f"  ✓ reusing group '{display_name}' ({group_id})")
    else:
        payload = {
            "displayName": display_name,
            "mailNickname": nickname,
            "mailEnabled": True,
            "securityEnabled": False,
            "groupTypes": ["Unified"],
            "description": "CLM Microhack corpus (SharePoint grounding source).",
        }
        if user_id:
            payload["owners@odata.bind"] = [f"{GRAPH}/users/{user_id}"]
            payload["members@odata.bind"] = [f"{GRAPH}/users/{user_id}"]
        _status, body = _graph("POST", "/groups", payload)
        group_id = body.get("id", "") if isinstance(body, dict) else ""
        if not group_id:
            raise SetupError("Group creation returned no id — check that group creation is allowed.")
        print(f"  ✓ created group '{display_name}' ({group_id})")

    # The SharePoint site provisions asynchronously — poll for its webUrl.
    print("  · waiting for the SharePoint site to provision (up to ~5 min)…")
    for _ in range(30):
        _status, body = _graph(
            "GET", f"/groups/{group_id}/sites/root?$select=webUrl", check=False
        )
        web_url = body.get("webUrl", "") if isinstance(body, dict) else ""
        if web_url:
            print(f"  ✓ site ready: {web_url}")
            return web_url
        time.sleep(10)
    raise SetupError(
        "The group's SharePoint site did not provision in time. Re-run this script "
        "(it will reuse the group), or create a site manually and pass "
        "--site-url https://<tenant>.sharepoint.com/sites/<name>."
    )


def upsert_env(values: dict[str, str]) -> None:
    """Insert/replace the SHAREPOINT_* keys in repo-root .env, preserving the rest."""
    lines: list[str] = []
    if ENV_PATH.exists():
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
    else:
        print("  ! .env not found — creating one with only the SHAREPOINT_* values.")
        print("    Run your Challenge 1 deploy (or write_env.py) to add the rest.")

    seen: set[str] = set()
    for i, line in enumerate(lines):
        m = re.match(r"\s*([A-Z0-9_]+)\s*=", line)
        if m and m.group(1) in values:
            key = m.group(1)
            lines[i] = f"{key}={values[key]}"
            seen.add(key)
    for key in SHAREPOINT_KEYS:
        if key in values and key not in seen:
            lines.append(f"{key}={values[key]}")

    ENV_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  ✓ wrote SHAREPOINT_* values to {ENV_PATH}")

    # Best-effort: mirror into the azd environment so a later `azd provision`/`azd up`
    # regenerates .env with these values instead of blanking them.
    azd = shutil.which("azd")
    if azd:
        for key in SHAREPOINT_KEYS:
            if key in values:
                subprocess.run(
                    [azd, "env", "set", key, values[key]],
                    cwd=REPO_ROOT, capture_output=True, text=True, check=False,
                )


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> None:
    parser = argparse.ArgumentParser(
        description="One-command SharePoint corpus setup for admin sandbox tenants."
    )
    parser.add_argument("--display-name", default="CLM Microhack Corpus",
                        help="Display name for the Entra app and the SharePoint site/group.")
    parser.add_argument("--site-url", default="",
                        help="Use an existing SharePoint site instead of provisioning one.")
    parser.add_argument("--library", default="Documents",
                        help="Target document library name (default: Documents).")
    parser.add_argument("--skip-upload", action="store_true",
                        help="Skip uploading the corpus PDFs to SharePoint.")
    parser.add_argument("--skip-index", action="store_true",
                        help="Skip running seed_corpus.py to build the index.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would happen; make no Azure/Graph/.env changes.")
    args = parser.parse_args()

    print("SharePoint corpus setup — self-service (admin sandbox tenant)\n")

    try:
        who = preflight()

        if args.dry_run:
            print("\n[dry-run] Would then:")
            print("  1. create/reuse Entra app "
                  f"'{args.display_name}' + grant Graph admin consent + mint a secret")
            site = args.site_url or f"https://<tenant>.sharepoint.com/sites/{_slug(args.display_name)}"
            print(f"  2. {'use existing site ' + args.site_url if args.site_url else 'provision an M365-group site'} "
                  f"→ {site}")
            print(f"  3. upsert SHAREPOINT_* into {ENV_PATH}")
            print("  4. upload src/data/**/*.pdf to the library"
                  + (" (skipped)" if args.skip_upload else ""))
            print("  5. run seed_corpus.py to build clm-corpus"
                  + (" (skipped)" if args.skip_index else ""))
            print("\nDry run complete — no changes made.")
            return

        app = ensure_app(args.display_name)
        site_url = args.site_url or ensure_site(args.display_name, who["user_id"])

        print("· Writing configuration")
        upsert_env({
            "SHAREPOINT_SITE_URL": site_url,
            "SHAREPOINT_DOC_LIBRARY": args.library,
            "SHAREPOINT_APP_ID": app["app_id"],
            "SHAREPOINT_APP_SECRET": app["secret"],
            "SHAREPOINT_TENANT_ID": who["tenant_id"],
        })

        if not args.skip_upload:
            print("· Uploading the corpus PDFs to SharePoint")
            _run_script("upload_corpus_to_sharepoint.py")

        if not args.skip_index:
            print("· Building the clm-corpus index from the SharePoint library")
            _run_script("seed_corpus.py")

        print(f"\n✅ Done. SharePoint is now your corpus source: {site_url}")
        if args.skip_index:
            print(
                "   Index step skipped (--skip-index). Once your Challenge 1 deploy has\n"
                "   populated .env with AZURE_SEARCH_ENDPOINT, build the index with:\n"
                "     python src/scripts/seed_corpus.py"
            )
        else:
            print(
                "   The 'clm-corpus' index is populated by the SharePoint Online indexer.\n"
                "   Give the indexer 1–2 minutes, then confirm a non-zero document count\n"
                "   in the Azure portal (Search service → Indexes → clm-corpus)."
            )
    except SetupError as exc:
        print(f"\n✗ {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
