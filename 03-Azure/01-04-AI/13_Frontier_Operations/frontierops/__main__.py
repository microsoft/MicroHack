"""Set up your Frontier Operations lab.

    python3 -m frontierops packs
    python3 -m frontierops --account <StorageAccountName> setup --industry distribution --app-url <BackOfficeUrl>
    python3 -m frontierops grant-agent <agent-name> --project-endpoint <FoundryProjectEndpoint> --project-id <FoundryProjectResourceId>
    python3 -m frontierops --account <StorageAccountName> status
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
PACKS = LAB / "data" / "packs"
MY_FILES = LAB / "my-files"
FOUNDRY_USER = "53ca6127-db72-4b80-b1b0-d745d6d5456d"


class SetupError(Exception):
    pass


def packs() -> dict:
    result = {}
    for folder in sorted(PACKS.iterdir()):
        profile = folder / "pack.json"
        if profile.is_file():
            result[folder.name] = json.loads(profile.read_text(encoding="utf-8"))
    return result


def _az(*arguments: str, capture: bool = False, storage: bool = True) -> str:
    executable = shutil.which("az")
    if not executable:
        raise SetupError("Azure CLI (az) was not found. Use Azure Cloud Shell, Codespaces or the lab devcontainer.")
    command = [executable, *arguments, "--only-show-errors"]
    if storage:
        command += ["--auth-mode", "login"]
    if not capture:
        command += ["--output", "none"]
    if storage and arguments[2] in ("upload-batch", "download-batch"):
        command.append("--no-progress")
    # Never let az read from or redraw the Cloud Shell terminal.
    completed = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise SetupError(f"Azure command failed: az {' '.join(arguments[:3])}\n{detail}\n"
                         "Check that Cloud Shell uses your lab subscription and that the names come from your lab dashboard. "
                         "If the error mentions permissions and your lab was deployed in the last few minutes, wait 5 minutes "
                         "and run the command again: new role assignments take a few minutes to apply.")
    return completed.stdout


def copy_my_files(pack_id: str, target: Path | None = None) -> list:
    """Put the files participants attach in the Foundry chat in one easy-to-find folder."""
    target = target or MY_FILES
    if target.exists():
        shutil.rmtree(target)
    (target / "statements").mkdir(parents=True)
    source = PACKS / pack_id
    for file in sorted((source / "statements").glob("*.csv")):
        shutil.copy2(file, target / "statements" / file.name)
    shutil.copy2(source / "handbook.md", target / "handbook.md")
    return sorted(p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file())


def setup(account: str, pack_id: str, app_url: str | None) -> None:
    available = packs()
    if pack_id not in available:
        raise SetupError(f"Unknown industry '{pack_id}'. Choose one of: {', '.join(available)}.")
    profile = available[pack_id]
    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / "packs"
        shutil.copytree(PACKS / pack_id, staged)
        _az("storage", "blob", "delete-batch", "--account-name", account, "--source", "packs")
        _az("storage", "blob", "upload-batch", "--account-name", account, "--destination", "packs",
            "--source", str(staged), "--overwrite", "true")
        active = Path(tmp) / "active.json"
        active.write_text(json.dumps({"pack": pack_id}), encoding="utf-8")
        _az("storage", "blob", "upload", "--account-name", account, "--container-name", "ops-state",
            "--name", "active.json", "--file", str(active), "--overwrite", "true")
    files = copy_my_files(pack_id)

    print(f"Your company: {profile['company']} ({profile['industry']})")
    print(f"  Process: {profile['process']}")
    print(f"  {profile['partner_type_plural'].capitalize()}: {', '.join(p['name'] for p in profile['partners'])}")
    print(f"  ERP and {profile['portal']['name']}: switched to {profile['company']}")
    if app_url:
        check_app(app_url, profile)
    print("\nFiles to attach in the Foundry chat are in the my-files folder:")
    for name in files:
        print(f"  {name}")
    print("Download them with the Cloud Shell 'Manage files' > 'Download' button, or open them in the editor (code my-files).")


def check_app(app_url: str, profile: dict) -> None:
    base = app_url.rstrip("/")
    try:
        with urllib.request.urlopen(base + "/portal", timeout=60) as resp:
            ok = profile["portal"]["name"] in resp.read().decode("utf-8", "replace")
        print(f"  Portal check: {'OK' if ok else 'answers, but for another company'} ({base}/portal)")
    except (urllib.error.URLError, TimeoutError) as err:
        print(f"  Portal check: could not reach {base}/portal ({err}). It can take a minute to start; open it in your browser.")


def grant_agent(agent: str, project_endpoint: str, project_id: str) -> None:
    """Give an agent's own identity the Foundry User role on the project, so it can return files."""
    url = f"{project_endpoint.rstrip('/')}/agents/{agent}?api-version=v1"
    data = json.loads(_az("rest", "--method", "get", "--url", url, "--resource", "https://ai.azure.com",
                          capture=True, storage=False) or "{}")
    latest = (data.get("versions") or {}).get("latest") or data
    principal = (latest.get("instance_identity") or data.get("instance_identity") or {}).get("principal_id")
    if not principal:
        raise SetupError(f"Agent '{agent}' has no identity yet. Save the agent in the Foundry portal first.")
    existing = json.loads(_az("role", "assignment", "list", "--assignee", principal, "--scope", project_id,
                              "--role", FOUNDRY_USER, "--output", "json", capture=True, storage=False) or "[]")
    if existing:
        print(f"Agent '{agent}' already has Foundry User on the project. Nothing to do.")
        return
    _az("role", "assignment", "create", "--assignee-object-id", principal, "--assignee-principal-type", "ServicePrincipal",
        "--role", FOUNDRY_USER, "--scope", project_id, storage=False)
    print(f"Granted Foundry User to agent '{agent}' (identity {principal}).")
    print("Allow up to five minutes before the agent can return files, then start a new chat.")


def status(account: str) -> None:
    active = _az("storage", "blob", "download", "--account-name", account, "--container-name", "ops-state",
                 "--name", "active.json", "--file", "/dev/stdout" if sys.platform != "win32" else "CON", capture=True)
    names = json.loads(_az("storage", "blob", "list", "--account-name", account, "--container-name", "packs",
                           "--query", "[].name", "--output", "json", capture=True) or "[]")
    print(f"  Active pack: {active.strip() or 'none'}")
    print(f"  packs container: {len(names)} file(s)")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="python3 -m frontierops", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--account", help="Storage account name from your lab dashboard (StorageAccountName)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("packs", help="List the industry packs you can choose from")
    setup_parser = sub.add_parser("setup", help="Load an industry pack into your lab")
    setup_parser.add_argument("--industry", required=True, help="distribution, telco, energy, insurance or retail")
    setup_parser.add_argument("--app-url", help="BackOfficeUrl from your lab dashboard, to check the portal answers")
    grant = sub.add_parser("grant-agent", help="Let an agent return files (Foundry User for its own identity)")
    grant.add_argument("agent", help="Agent name, for example ops-agent")
    grant.add_argument("--project-endpoint", required=True, help="FoundryProjectEndpoint from your lab dashboard")
    grant.add_argument("--project-id", required=True, help="FoundryProjectResourceId from your lab dashboard")
    sub.add_parser("status", help="Show what is loaded in your lab")
    args = parser.parse_args(argv)
    try:
        if args.command == "packs":
            for pack_id, profile in packs().items():
                print(f"  {pack_id:13} {profile['company']:21} {profile['process']}")
            return 0
        if args.command == "grant-agent":
            grant_agent(args.agent, args.project_endpoint, args.project_id)
            return 0
        if not args.account:
            raise SetupError("Add --account <StorageAccountName> (from your lab dashboard) before the command.")
        if args.command == "setup":
            setup(args.account, args.industry.lower(), args.app_url)
        else:
            status(args.account)
        return 0
    except SetupError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
