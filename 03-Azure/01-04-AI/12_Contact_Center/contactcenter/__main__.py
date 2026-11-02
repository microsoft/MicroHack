"""Load an industry pack into your lab: knowledge articles, supervisor insights, recorded calls and the CRM.

    python3 -m contactcenter packs
    python3 -m contactcenter --account <StorageAccountName> setup --industry telco
    python3 -m contactcenter --account <StorageAccountName> status
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
CONTAINERS = ("knowledge", "insights", "calls", "evaluation")


class SetupError(Exception):
    pass


def packs() -> dict:
    result = {}
    for folder in sorted(PACKS.iterdir()):
        profile = folder / "pack.json"
        if profile.is_file():
            result[folder.name] = json.loads(profile.read_text(encoding="utf-8"))
    return result


def _az(*arguments: str, capture: bool = False) -> str:
    executable = shutil.which("az")
    if not executable:
        raise SetupError("Azure CLI (az) was not found. Use Azure Cloud Shell, Codespaces or the lab devcontainer.")
    command = [executable, *arguments, "--auth-mode", "login", "--only-show-errors"]
    if not capture:
        command += ["--output", "none"]
    if arguments[2] in ("upload-batch", "download-batch"):
        command.append("--no-progress")
    # Never let az read from or redraw the Cloud Shell terminal.
    completed = subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise SetupError(f"Azure Storage command failed: az {' '.join(arguments[:3])}\n{detail}\n"
                         "Check that Cloud Shell uses your lab subscription and that the storage account name is correct. "
                         "If the error mentions permissions and your lab was deployed in the last few minutes, wait 5 minutes "
                         "and run the command again: new role assignments take a few minutes to apply.")
    return completed.stdout


def stage(pack_id: str, folder: Path) -> dict:
    """Copy what each container should hold into a temporary folder."""
    source = PACKS / pack_id
    plan = {"knowledge": sorted((source / "knowledge").glob("*.md")),
            "insights": sorted((source / "insights").glob("*.md")),
            "calls": sorted((source / "calls").glob("*.mp3")),
            "evaluation": [source / "evaluation.jsonl"]}
    for container, files in plan.items():
        target = folder / container
        target.mkdir(parents=True)
        for file in files:
            shutil.copy2(file, target / file.name)
    return {container: [f.name for f in files] for container, files in plan.items()}


def setup(account: str, pack_id: str, crm_url: str | None) -> None:
    available = packs()
    if pack_id not in available:
        raise SetupError(f"Unknown industry '{pack_id}'. Choose one of: {', '.join(available)}.")
    profile = available[pack_id]
    with tempfile.TemporaryDirectory() as tmp:
        staged = stage(pack_id, Path(tmp))
        for container, files in staged.items():
            # Replace the container's contents so knowledge from another industry never mixes in.
            _az("storage", "blob", "delete-batch", "--account-name", account, "--source", container)
            if files:
                _az("storage", "blob", "upload-batch", "--account-name", account, "--destination", container,
                    "--source", str(Path(tmp) / container), "--overwrite", "true")
        active = Path(tmp) / "active.json"
        active.write_text(json.dumps({"pack": pack_id}), encoding="utf-8")
        _az("storage", "blob", "upload", "--account-name", account, "--container-name", "crm-state",
            "--name", "active.json", "--file", str(active), "--overwrite", "true")

    print(f"Your company: {profile['company']} ({profile['industry']})")
    print(f"  Knowledge articles: {len(staged['knowledge'])}  -> container 'knowledge'")
    print(f"  Supervisor insights: {len(staged['insights'])}  -> container 'insights'")
    print(f"  Recorded calls: {len(staged['calls'])}  -> container 'calls'")
    print(f"  Evaluation questions: {len(staged['evaluation'])} file  -> container 'evaluation'")
    print("  CRM: switched to this company's customers, appointment slots and cases")
    if crm_url:
        check_crm(crm_url, profile["company"])
    print("\nTest customers you can use (account number, postcode):")
    crm = json.loads((PACKS / pack_id / "crm.json").read_text(encoding="utf-8"))
    for customer in crm["customers"][:4]:
        print(f"  {customer['account_number']}  {customer['postcode']}  {customer['name']} - {customer['notes'] or customer['product']}")


def check_crm(crm_url: str, company: str) -> None:
    url = crm_url.rstrip("/") + "/company"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = json.loads(resp.read())
        status = "OK" if data.get("company") == company else f"answers as '{data.get('company')}'"
        print(f"  CRM check: {status} ({url})")
    except (urllib.error.URLError, TimeoutError) as err:
        print(f"  CRM check: could not reach {url} ({err}). It can take a minute to start; open it in your browser.")


def status(account: str) -> None:
    for container in CONTAINERS:
        names = json.loads(_az("storage", "blob", "list", "--account-name", account, "--container-name", container,
                               "--query", "[].name", "--output", "json", capture=True) or "[]")
        print(f"  {container}: {len(names)} file(s)")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="python3 -m contactcenter", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--account", help="Storage account name from your lab dashboard (StorageAccountName)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("packs", help="List the industry packs you can choose from")
    setup_parser = sub.add_parser("setup", help="Load an industry pack into your lab")
    setup_parser.add_argument("--industry", required=True, help="telco, energy, bank, insurance or retail")
    setup_parser.add_argument("--crm-url", help="CrmUrl from your lab dashboard, to check the CRM answers")
    sub.add_parser("status", help="Show what is loaded in your storage account")
    args = parser.parse_args(argv)
    try:
        if args.command == "packs":
            for pack_id, profile in packs().items():
                print(f"  {pack_id:10} {profile['company']:20} {profile['industry']}: {profile['tagline']}")
            return 0
        if not args.account:
            raise SetupError("Add --account <StorageAccountName> (from your lab dashboard) before the command.")
        if args.command == "setup":
            setup(args.account, args.industry.lower(), args.crm_url)
        else:
            status(args.account)
        return 0
    except SetupError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
