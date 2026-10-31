"""Set up your Frontier Operations lab.

    python3 -m frontierops packs
    python3 -m frontierops setup --industry distribution --account <StorageAccountName> --app-url <BackOfficeUrl> --project-id <FoundryProjectResourceId>
    python3 -m frontierops grant-agent ops-agent
    python3 -m frontierops publish-skill my-files/skills/reconciliation
    python3 -m frontierops score ~/exceptions.xlsx
    python3 -m frontierops status

setup remembers your dashboard values in .state/lab.json, so the other commands don't need them.
"""
from __future__ import annotations

import argparse
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import uuid
import zipfile
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
PACKS = LAB / "data" / "packs"
TEMPLATES = LAB / "templates"
MY_FILES = LAB / "my-files"
STATE = LAB / ".state" / "lab.json"
FOUNDRY_USER = "53ca6127-db72-4b80-b1b0-d745d6d5456d"
SKILL_NAME = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")


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
    # Challenges 1 to 3 start from an ERP export, the way most teams work today; Challenge 4 connects the live ERP.
    shutil.copy2(source / "ledger.csv", target / "ledger-export.csv")
    # Challenge 2: the team writes the expert's method into this starter skill.
    (target / "skills" / "reconciliation").mkdir(parents=True)
    shutil.copy2(TEMPLATES / "SKILL.md", target / "skills" / "reconciliation" / "SKILL.md")
    return sorted(p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file())


def load_lab() -> dict:
    """The dashboard values saved by setup, so later commands stay short."""
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_lab(**values) -> None:
    current = load_lab()
    current.update({k: v for k, v in values.items() if v})
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(current, indent=2), encoding="utf-8")


def project_endpoint_from_id(project_id: str) -> str:
    match = re.search(r"/accounts/([^/]+)/projects/([^/]+)$", project_id.rstrip("/"))
    if not match:
        raise SetupError("That doesn't look like a FoundryProjectResourceId. Copy it from your lab dashboard: "
                         "it starts with /subscriptions/ and ends with /projects/frontier-operations.")
    return f"https://{match.group(1)}.services.ai.azure.com/api/projects/{match.group(2)}"


def need(value: str | None, name: str, dashboard: str) -> str:
    if value:
        return value
    raise SetupError(f"I don't know your {name} yet. Run the Challenge 1 setup command first (it remembers your "
                     f"dashboard values), or add --{name.replace(' ', '-')} <{dashboard}>.")


def setup(account: str, pack_id: str, app_url: str | None, project_id: str | None = None) -> None:
    available = packs()
    if pack_id not in available:
        raise SetupError(f"Unknown industry '{pack_id}'. Choose one of: {', '.join(available)}.")
    profile = available[pack_id]
    endpoint = project_endpoint_from_id(project_id) if project_id else None
    print(f"Loading {profile['company']} into your lab...")
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
    save_lab(account=account, industry=pack_id, app_url=app_url, project_id=project_id, project_endpoint=endpoint)

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
    print("\nYour dashboard values are saved in .state/lab.json, so the next commands don't need them.")


def check_app(app_url: str, profile: dict) -> None:
    base = app_url.rstrip("/")
    try:
        with urllib.request.urlopen(base + "/portal", timeout=60) as resp:
            ok = profile["portal"]["name"] in resp.read().decode("utf-8", "replace")
        print(f"  Portal check: {'OK' if ok else 'answers, but for another company'} ({base}/portal)")
    except (urllib.error.URLError, TimeoutError) as err:
        print(f"  Portal check: could not reach {base}/portal ({err}). It can take a minute to start; open it in your browser.")


AI_TOKEN_HELP = ("Cloud Shell's built-in sign-in can't get a token for Microsoft Foundry. Sign in once in this "
                 "terminal, then run the command again:\n  az login --use-device-code --scope https://ai.azure.com/.default")


def _foundry_token() -> str:
    try:
        return _az("account", "get-access-token", "--resource", "https://ai.azure.com", "--query", "accessToken",
                   "--output", "tsv", capture=True, storage=False).strip()
    except SetupError as err:
        raise SetupError(f"{AI_TOKEN_HELP}\n({str(err).splitlines()[1] if len(str(err).splitlines()) > 1 else err})")


def _agent_principal(agent: str, project_endpoint: str, project_id: str) -> str | None:
    """Find the agent's own identity. Its Entra name is <account>-<project>-<agent>-AgentIdentity."""
    match = re.search(r"/accounts/([^/]+)/projects/([^/]+)$", project_id.rstrip("/"))
    if match:
        name = f"{match.group(1)}-{match.group(2)}-{agent}-AgentIdentity"
        found = json.loads(_az("ad", "sp", "list", "--display-name", name, "--query", "[].id", "--output", "json",
                               capture=True, storage=False) or "[]")
        if found:
            return found[0]
    # Fall back to the agent definition in Foundry (needs a token for https://ai.azure.com).
    try:
        data = json.loads(_az("rest", "--method", "get", "--url", f"{project_endpoint.rstrip('/')}/agents/{agent}?api-version=v1",
                              "--resource", "https://ai.azure.com", capture=True, storage=False) or "{}")
    except SetupError:
        return None
    latest = (data.get("versions") or {}).get("latest") or data
    return (latest.get("instance_identity") or data.get("instance_identity") or {}).get("principal_id")


def grant_agent(agent: str, project_endpoint: str, project_id: str) -> None:
    """Give an agent's own identity the Foundry User role on the project, so it can return files."""
    principal = _agent_principal(agent, project_endpoint, project_id)
    if not principal:
        raise SetupError(f"Agent '{agent}' has no identity yet. Check the name, and save the agent in the Foundry portal first.")
    existing = json.loads(_az("role", "assignment", "list", "--assignee", principal, "--scope", project_id,
                              "--role", FOUNDRY_USER, "--output", "json", capture=True, storage=False) or "[]")
    if existing:
        print(f"Agent '{agent}' already has Foundry User on the project. Nothing to do.")
        return
    _az("role", "assignment", "create", "--assignee-object-id", principal, "--assignee-principal-type", "ServicePrincipal",
        "--role", FOUNDRY_USER, "--scope", project_id, storage=False)
    print(f"Granted Foundry User to agent '{agent}' (identity {principal}).")
    print("Allow up to five minutes before the agent can return files, then start a new chat.")


def read_skill(folder: Path) -> tuple[str, str]:
    """Check a skill folder the way Foundry will, and explain any problem in plain words."""
    skill_file = folder / "SKILL.md"
    if not skill_file.is_file():
        raise SetupError(f"There is no SKILL.md in {folder}. Point the command at the folder that contains it.")
    text = skill_file.read_text(encoding="utf-8")
    match = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n(.*)\Z", text, re.S)
    if not match:
        raise SetupError("SKILL.md must start with a front matter block: a line '---', then 'name:' and "
                         "'description:', then another '---'.")
    fields = dict(re.findall(r"^([a-z]+):[ \t]*(.*?)[ \t]*$", match.group(1), re.M))
    name, description, body = fields.get("name", ""), fields.get("description", ""), match.group(2).strip()
    for key, value in (("name", name), ("description", description)):
        if not value:
            raise SetupError(f"The front matter needs a '{key}:' line.")
        if value[0] in "'\"":
            raise SetupError(f"Remove the quotes around the {key}. Foundry needs it unquoted.")
    if not SKILL_NAME.match(name) or "--" in name or len(name) > 64:
        raise SetupError(f"The name '{name}' isn't valid: use lowercase letters, numbers and single hyphens, "
                         "for example 'reconciliation' or 'supplier-onboarding'.")
    if name != folder.name:
        raise SetupError(f"The name in SKILL.md ('{name}') must match the folder name ('{folder.name}').")
    if len(description) > 1024:
        raise SetupError("The description is longer than 1,024 characters. Keep it to one sentence.")
    if not body:
        raise SetupError("SKILL.md has no instructions after the front matter.")
    todo = [n for n, line in enumerate(text.splitlines(), 1) if "TODO" in line]
    if todo:
        raise SetupError(f"SKILL.md still has TODO on line(s) {', '.join(map(str, todo))}. Replace each TODO with your own words.")
    return name, description


def _skill_archive(folder: Path) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(folder.rglob("*")):
            if file.is_file() and not any(part.startswith(".") for part in file.relative_to(folder).parts):
                archive.write(file, file.relative_to(folder).as_posix())
    return buffer.getvalue()


def _upload_skill(url: str, token: str, archive: bytes, name: str) -> dict:
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}.zip\"\r\n"
            "Content-Type: application/zip\r\n\r\n").encode() + archive + f"\r\n--{boundary}--\r\n".encode()
    request = urllib.request.Request(url, data=body, method="POST", headers={
        "Authorization": f"Bearer {token}", "Foundry-Features": "Skills=V1Preview",
        "Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as err:
        raise SetupError(f"Foundry refused the skill ({err.code}): {err.read().decode('utf-8', 'replace')[:400]}")


def _set_default_skill_version(url: str, token: str, version: str) -> None:
    request = urllib.request.Request(url, data=json.dumps({"default_version": version}).encode(), method="POST", headers={
        "Authorization": f"Bearer {token}", "Foundry-Features": "Skills=V1Preview", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60):
            pass
    except urllib.error.HTTPError as err:
        raise SetupError(f"The skill was uploaded, but Foundry didn't make version {version} the default ({err.code}).")


def publish_skill(folder: Path, project_endpoint: str) -> None:
    """Upload a skill folder as a SKILL.md package, the format the Copilot harness loads, and make it the default."""
    folder = folder.resolve()
    name, description = read_skill(folder)
    token = _foundry_token()
    base = f"{project_endpoint.rstrip('/')}/skills/{name}"
    created = _upload_skill(f"{base}/versions?api-version=v1", token, _skill_archive(folder), name)
    version = str(created.get("version", ""))
    if version:
        _set_default_skill_version(f"{base}?api-version=v1", token, version)
    print(f"Published skill '{name}' version {version or '?'} and made it the default: {description}")
    print("In the Foundry portal, open your agent and select Tools > Add > Add skills, choose it, "
          "then Save and start new chat.")
    print("Each publish creates a new version. An agent keeps the version it was saved with: after you publish again, "
          "remove the skill from the agent, add it again and save.")


def _xlsx_sheets(path: Path) -> dict:
    """Read every sheet of an .xlsx file as rows of strings, with the standard library only."""
    import xml.etree.ElementTree as ET
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
          "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
    try:
        book = zipfile.ZipFile(path)
    except (zipfile.BadZipFile, FileNotFoundError) as err:
        raise SetupError(f"Can't open {path} as an Excel workbook ({err}).")
    shared = []
    if "xl/sharedStrings.xml" in book.namelist():
        for item in ET.fromstring(book.read("xl/sharedStrings.xml")).findall("m:si", ns):
            shared.append("".join(t.text or "" for t in item.iter(f"{{{ns['m']}}}t")))
    rels = {r.get("Id"): r.get("Target") for r in ET.fromstring(book.read("xl/_rels/workbook.xml.rels"))}
    sheets = {}
    for sheet in ET.fromstring(book.read("xl/workbook.xml")).find("m:sheets", ns):
        target = rels[sheet.get(f"{{{ns['r']}}}id")].lstrip("/")
        target = target if target.startswith("xl/") else f"xl/{target}"
        rows = []
        for row in ET.fromstring(book.read(target)).iter(f"{{{ns['m']}}}row"):
            values = []
            for cell in row.findall("m:c", ns):
                kind, value = cell.get("t"), cell.find("m:v", ns)
                if kind == "s" and value is not None:
                    values.append(shared[int(value.text)])
                elif kind == "inlineStr":
                    values.append("".join(t.text or "" for t in cell.iter(f"{{{ns['m']}}}t")))
                else:
                    values.append(value.text if value is not None else "")
            rows.append(values)
        sheets[sheet.get("name")] = rows
    return sheets


def _normalise_reference(value: str) -> str:
    text = re.sub(r"[^A-Z0-9]", "", str(value).upper())
    match = re.match(r"([A-Z]+?)(0*)(\d+)$", text)
    return f"{match.group(1)}{match.group(3)}" if match else text


CATEGORY_WORDS = [
    ("within_tolerance", ("tolerance", "rounding", "accept")),
    ("duplicate", ("duplicate", "double")),
    ("credit", ("credit", "refund", "adjustment", "return premium")),
    ("missing_on_statement", ("missing on statement", "missing from statement", "not on statement", "ledger only",
                              "missing on their statement", "missing payout")),
    ("missing_in_ledger", ("missing in ledger", "missing from ledger", "not in ledger", "not in our ledger",
                           "statement only", "missing in our ledger")),
    ("mismatch", ("mismatch", "difference", "dispute", "query", "claim", "variance")),
]


def _category(text: str) -> str:
    lowered = text.lower()
    for kind, words in CATEGORY_WORDS:
        if any(word in lowered for word in words):
            return kind
    return "other"


def score(workbook: Path, pack_id: str) -> dict:
    """Compare an agent's exceptions workbook with the pack's answer key."""
    available = packs()
    if pack_id not in available:
        raise SetupError(f"Unknown industry '{pack_id}'. Choose one of: {', '.join(available)}.")
    profile = available[pack_id]
    expected = json.loads((PACKS / pack_id / "expected.json").read_text(encoding="utf-8"))
    names = {p["id"]: p for p in profile["partners"]}
    found = {}
    for sheet, rows in _xlsx_sheets(workbook).items():
        key = sheet.lower().replace(" ", "")
        partner = next((pid for pid, p in names.items()
                        if pid.replace("-", "") in key or p["name"].lower().replace(" ", "").startswith(key[:6])), None)
        header = next((i for i, row in enumerate(rows) if any("ref" in c.lower() for c in row)
                       and any(w in c.lower() for c in row for w in ("category", "issue", "type", "exception"))), None)
        if partner is None or header is None:
            continue
        columns = [c.lower() for c in rows[header]]
        ref_col = next(i for i, c in enumerate(columns) if "ref" in c)
        cat_col = next(i for i, c in enumerate(columns) if any(w in c for w in ("category", "issue", "type", "exception")))
        for row in rows[header + 1:]:
            if len(row) > max(ref_col, cat_col) and row[ref_col].strip() \
                    and not row[ref_col].strip().lower().startswith(("total", "summary", "grand")):
                found[(partner, _normalise_reference(row[ref_col]))] = _category(row[cat_col])
    results = {"correct": 0, "total": 0, "wrong": [], "extra": [], "partners": sorted({p for p, _ in found})}
    if not found:
        raise SetupError("No partner sheets with a reference and a category column were found in the workbook. "
                         "Ask the agent for one sheet per partner with Reference and Category columns.")
    wanted = set()
    for item in expected:
        if item["partner_id"] not in results["partners"]:
            continue
        results["total"] += 1
        key = (item["partner_id"], _normalise_reference(item["reference"]))
        wanted.add(key)
        got = found.get(key)
        if item["kind"] == "within_tolerance":
            ok = got in (None, "within_tolerance")
        else:
            ok = got == item["kind"]
        if ok:
            results["correct"] += 1
        else:
            results["wrong"].append((names[item["partner_id"]]["name"], item["reference"], item["kind"], got or "not listed"))
    results["extra"] = sorted(f"{names[p]['name']} {ref}" for p, ref in set(found) - wanted)
    return results


def print_score(workbook: Path, pack_id: str) -> None:
    result = score(workbook, pack_id)
    partners = len(result["partners"])
    print(f"Score: {result['correct']} of {result['total']} planted lines handled the way the handbook says "
          f"({partners} partner{'s' if partners != 1 else ''}).")
    labels = {"mismatch": "amount mismatch", "within_tolerance": "within tolerance (accept, don't list)",
              "missing_on_statement": "missing on statement", "missing_in_ledger": "missing in ledger",
              "duplicate": "possible duplicate", "credit": "credit to confirm", "other": "a category the score didn't recognise"}
    for partner, reference, kind, got in result["wrong"]:
        print(f"  {partner} {reference}: should be {labels[kind]}, the workbook says {labels.get(got, got)}")
    for extra in result["extra"]:
        print(f"  Listed but not in the answer key: {extra}")


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
    setup_parser = sub.add_parser("setup", help="Load an industry pack into your lab and remember your dashboard values")
    setup_parser.add_argument("--industry", required=True, help="distribution, telco, energy, insurance or retail")
    setup_parser.add_argument("--account", dest="setup_account", help="StorageAccountName from your lab dashboard")
    setup_parser.add_argument("--app-url", help="BackOfficeUrl from your lab dashboard, to check the portal answers")
    setup_parser.add_argument("--project-id", help="FoundryProjectResourceId from your lab dashboard")
    grant = sub.add_parser("grant-agent", help="Let an agent return files (Foundry User for its own identity)")
    grant.add_argument("agent", help="Agent name, for example ops-agent")
    grant.add_argument("--project-id", help="FoundryProjectResourceId (saved by setup)")
    publish = sub.add_parser("publish-skill", help="Publish a skill folder (with SKILL.md) to your Foundry project")
    publish.add_argument("folder", help="Skill folder, for example my-files/skills/reconciliation")
    publish.add_argument("--project-id", help="FoundryProjectResourceId (saved by setup)")
    score_parser = sub.add_parser("score", help="Check an agent's exceptions workbook against the answer key")
    score_parser.add_argument("workbook", help="The .xlsx file the agent returned")
    score_parser.add_argument("--industry", help="distribution, telco, energy, insurance or retail (saved by setup)")
    sub.add_parser("status", help="Show what is loaded in your lab")
    args = parser.parse_args(argv)
    lab = load_lab()
    try:
        if args.command == "packs":
            for pack_id, profile in packs().items():
                print(f"  {pack_id:13} {profile['company']:21} {profile['process']}")
            return 0
        if args.command == "setup":
            account = need(getattr(args, "setup_account", None) or args.account, "account", "StorageAccountName")
            setup(account, args.industry.lower(), args.app_url, args.project_id)
            return 0
        if args.command in ("grant-agent", "publish-skill"):
            project_id = need(args.project_id or lab.get("project_id"), "project id", "FoundryProjectResourceId")
            endpoint = project_endpoint_from_id(project_id)
            if args.command == "grant-agent":
                grant_agent(args.agent, endpoint, project_id)
            else:
                publish_skill(Path(args.folder), endpoint)
            return 0
        if args.command == "score":
            industry = need(args.industry or lab.get("industry"), "industry", "distribution, telco, energy, insurance or retail")
            print_score(Path(args.workbook).expanduser(), industry.lower())
            return 0
        status(need(args.account or lab.get("account"), "account", "StorageAccountName"))
        return 0
    except SetupError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
