"""The regulatory lake: versioned documents, change events, change log and task register."""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import shutil
from pathlib import Path
from typing import Dict, List, Optional

from . import crawler

RAW = "lake-raw"
KNOWLEDGE = "regulatory-knowledge"
TASK_STATUSES = ("open", "in progress", "blocked", "done")
CITATION = re.compile(r"^(?P<doc>[A-Z]{2}-[A-Z]{2,3}-\d{4}-\d{3}) v(?P<version>\d+) p(?P<paragraph>\d+)$")
FRIENDLY_TYPES = {
    "regulation": "Regulation", "guidance": "Guidance", "safety-alert": "Safety alert",
    "enforcement-letter": "Enforcement letter", "coverage-decision": "Coverage decision",
    "pricing-rule": "Pricing rule",
}


class LakeError(Exception):
    pass


def _read_json(path: Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else default


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _write_json(path: Path, value) -> None:
    _write(path, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


class Lake:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.raw = self.root / RAW
        self.knowledge = self.root / KNOWLEDGE
        self.state_path = self.raw / "state" / "monitor-state.json"
        self.tasks_path = self.raw / "tracking" / "tasks.json"
        self.audit_path = self.raw / "tracking" / "audit-log.jsonl"

    # ----- state -----------------------------------------------------------------
    def state(self) -> dict:
        return _read_json(self.state_path, {"documents": {}, "runs": []})

    def as_of(self) -> str:
        runs = self.state()["runs"]
        return runs[-1]["date"] if runs else crawler.DAYS["monday"]["date"]

    def version(self, document_id: str, version: int) -> Optional[dict]:
        document = self.state()["documents"].get(document_id)
        if not document or not 1 <= version <= len(document["versions"]):
            return None
        return document["versions"][version - 1]

    # ----- Regulatory Web and Change Monitor ---------------------------------------
    def monitor(self, day: str) -> dict:
        result = crawler.crawl(day)
        date = crawler.DAYS[day]["date"]
        state = self.state()
        earlier = [name for name, info in crawler.DAYS.items() if info["date"] < date]
        missing = [name for name in earlier if name not in {run["day"] for run in state["runs"]}]
        if missing:
            raise LakeError(f"Crawl {', '.join(missing)} first, so the monitor can tell what changed on {day}.")
        report = {"day": day, "date": date, "pages_crawled": len(result.pages), "new": [], "updated": [],
                  "duplicates": [], "navigation_pages": 0, "skipped_links": len(result.skipped_links)}
        for page in result.pages:
            _write(self.raw / "raw" / day / page.portal["id"] / page.path, page.html)
            extracted = crawler.extract(page.html)
            if "document-id" not in extracted.meta:
                report["navigation_pages"] += 1
                continue
            metadata = crawler.enrich(extracted, page.portal)
            document_id = metadata["document_id"]
            content_hash = extracted.content_hash
            entry = state["documents"].setdefault(document_id, {"versions": []})
            versions = entry["versions"]
            known = next((v for v in versions if v["content_hash"] == content_hash), None)
            if known:
                if known is not versions[-1]:
                    reason = "older version re-published; current version kept"
                elif page.url in known["urls"]:
                    reason = "unchanged since an earlier crawl"
                else:
                    reason = "same content at another address"
                    known["urls"].append(page.url)
                report["duplicates"].append(f"{document_id} v{known['version']} ({reason}): {page.url}")
                continue
            version = len(versions) + 1
            record = dict(metadata, version=version, content_hash=content_hash, urls=[page.url],
                          detected=date, paragraphs=extracted.paragraphs, superseded_on=None)
            if versions:
                versions[-1]["superseded_on"] = date
            versions.append(record)
            kind = "updated" if version > 1 else "new"
            report[kind].append(f"{document_id} v{version}")
            event = {
                "event_id": f"EVT-{document_id}-v{version}",
                "type": "regulatory-change-detected",
                "change": kind,
                "document_id": document_id,
                "version": version,
                "document_path": f"documents/{document_id}-v{version}.md",
                "title": metadata["title"],
                "document_type": metadata["document_type"],
                "region": metadata["region"],
                "domains": metadata["domains"],
                "products_named": metadata["products_named"],
                "detected": date,
            }
            if version > 1:
                event["supersedes"] = f"{document_id} v{version - 1}"
            _write_json(self.raw / "events" / f"{event['event_id']}.json", event)
        state["runs"].append({key: (len(value) if isinstance(value, list) else value) for key, value in report.items()})
        _write_json(self.state_path, state)
        self._publish(state)
        return report

    def _publish(self, state: dict) -> None:
        for document_id, entry in state["documents"].items():
            for record in entry["versions"]:
                _write(self.knowledge / "documents" / f"{document_id}-v{record['version']}.md", render_document(record, entry))
        _write(self.knowledge / "change-log.md", render_change_log(state))
        for folder in ("internal", "reference"):
            for source in sorted((crawler.DATA / folder).glob("*.md")):
                destination = self.knowledge / folder / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
        if not self.tasks_path.is_file():
            self.tasks_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(crawler.DATA / "tracking" / "tasks.json", self.tasks_path)
        self.render_tasks()

    # ----- Human sign-off and progress tracking --------------------------------------
    def tasks(self) -> dict:
        if not self.tasks_path.is_file():
            raise LakeError("Run the monitor first: python3 -m regintel monitor --day monday")
        return _read_json(self.tasks_path, {})

    def _audit(self, entry: dict) -> None:
        self.audit_path.parent.mkdir(parents=True, exist_ok=True)
        with self.audit_path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")

    def signoff(self, decision_file: Path) -> List[str]:
        raw = Path(decision_file).read_text(encoding="utf-8")
        try:
            decision = json.loads(raw)
        except json.JSONDecodeError as error:
            raise LakeError(f"The sign-off file is not valid JSON: {error}") from error
        owners = _owner_roles()
        change = str(decision.get("change", "")).strip().strip("[]").strip()
        match = re.fullmatch(r"(?P<doc>[A-Z]{2}-[A-Z]{2,3}-\d{4}-\d{3}) v(?P<version>\d+)", change)
        if not match or not self.version(match["doc"], int(match["version"])):
            raise LakeError(f"'change' must name a detected document version such as 'EU-SA-2027-004 v1'; got '{change}'.")
        record = self.version(match["doc"], int(match["version"]))
        if record["superseded_on"]:
            raise LakeError(f"{change} was superseded on {record['superseded_on']}. Re-assess the current version before sign-off.")
        if decision.get("decision") not in {"approved", "rejected"}:
            raise LakeError("'decision' must be 'approved' or 'rejected'.")
        if decision.get("approver_role") != "Regulatory Affairs Lead":
            raise LakeError("'approver_role' must be 'Regulatory Affairs Lead' (see internal/owners.md).")
        approved_by = str(decision.get("approved_by", "")).strip()
        if not approved_by:
            raise LakeError("'approved_by' is empty. A decision needs a person: reply APPROVE <your name>.")
        if "agent" in approved_by.lower():
            raise LakeError("'approved_by' must be the person who made the decision, not an agent.")
        tasks = decision.get("tasks") or []
        prepared: List[dict] = []
        if decision["decision"] == "approved":
            if not tasks:
                raise LakeError("An approved plan must contain at least one task.")
            if any(task.get("domain") == "manufacturing" for task in tasks) and not str(decision.get("quality_approval_by", "")).strip():
                raise LakeError("Manufacturing tasks also need 'quality_approval_by' (the Quality Head's sign-off).")
            prepared = [self._validate_task(task, owners) for task in tasks]
        # Checked after the content checks, so every error in a record is reported even for a change already decided.
        audit = [json.loads(line) for line in self.audit_path.read_text(encoding="utf-8").splitlines()] if self.audit_path.is_file() else []
        if any(item.get("event") == "signoff" and item.get("change") == change for item in audit):
            raise LakeError(f"{change} already has a recorded decision. Update task status with 'regintel task' instead.")
        register = self.tasks()
        created: List[str] = []
        if prepared:
            year = self.as_of()[:4]
            existing = [int(t["id"].rsplit("-", 1)[1]) for t in register["tasks"] if t["id"].startswith(f"TASK-{year}-")]
            next_number = max(existing, default=0) + 1
            for offset, task in enumerate(prepared):
                task_id = f"TASK-{year}-{next_number + offset:03d}"
                register["tasks"].append(dict(task, id=task_id, change=change, status="open", history=[
                    {"at": self.as_of(), "event": "approved", "by": f"{approved_by} ({decision['approver_role']})",
                     "note": str(decision.get("note", "")).strip()}]))
                created.append(task_id)
        self._audit({"event": "signoff", "change": change, "decision": decision["decision"],
                     "by": approved_by, "role": decision["approver_role"],
                     "quality_approval_by": decision.get("quality_approval_by"), "tasks": created,
                     "at": self.as_of(), "recorded_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                     "decision_sha256": hashlib.sha256(raw.encode("utf-8")).hexdigest()})
        _write_json(self.tasks_path, register)
        self.render_tasks()
        return created

    def _validate_task(self, task: dict, owners: List[str]) -> dict:
        title = str(task.get("title", "")).strip()
        if not title:
            raise LakeError("Every task needs a 'title'.")
        if task.get("owner_role") not in owners:
            raise LakeError(f"Task '{title}': owner_role must be one of {owners}.")
        try:
            dt.date.fromisoformat(str(task.get("due")))
        except ValueError as error:
            raise LakeError(f"Task '{title}': 'due' must be a date such as 2027-03-01.") from error
        citation = str(task.get("citation", "")).strip().strip("[]").strip()
        match = CITATION.fullmatch(citation)
        record = self.version(match["doc"], int(match["version"])) if match else None
        if not record or not 1 <= int(match["paragraph"]) <= len(record["paragraphs"]):
            raise LakeError(f"Task '{title}': citation '{citation}' is not a paragraph in the lake (format: EU-SA-2027-004 v1 p3).")
        domain = str(task.get("domain", "")).strip()
        if domain not in crawler.load_json("domains.json")["domains"]:
            raise LakeError(f"Task '{title}': unknown domain '{domain}'.")
        return {"title": title, "citation": citation, "domain": domain, "region": str(task.get("region", "")).strip(),
                "owner_role": task["owner_role"], "due": str(task["due"])}

    def update_task(self, task_id: str, status: str, by: str, note: str = "") -> dict:
        if status not in TASK_STATUSES:
            raise LakeError(f"Status must be one of {TASK_STATUSES}.")
        if not by.strip():
            raise LakeError("Say who changed the status with --by.")
        register = self.tasks()
        task = next((t for t in register["tasks"] if t["id"] == task_id), None)
        if not task:
            raise LakeError(f"Unknown task {task_id}.")
        task["status"] = status
        task["history"].append({"at": self.as_of(), "event": "status", "by": by.strip(), "note": note.strip() or status})
        self._audit({"event": "status", "task": task_id, "status": status, "by": by.strip(), "at": self.as_of(),
                     "recorded_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")})
        _write_json(self.tasks_path, register)
        self.render_tasks()
        return task

    def render_tasks(self) -> None:
        register = _read_json(self.tasks_path, {"tasks": []})
        today = self.as_of()
        lines = [
            "# Caldova regulatory task register", "",
            f"Fictional training record, rendered from the sign-off audit trail. Status as of **{today}**.", "",
            "A task is **at risk** when its due date has passed and it is not done.", "",
            "| Task | Title | Change and citation | Domain | Region | Owner role | Due | Status | At risk |",
            "|---|---|---|---|---|---|---|---|---|",
        ]
        for task in register["tasks"]:
            at_risk = "yes" if task["status"] != "done" and task["due"] < today else "no"
            lines.append(f"| {task['id']} | {task['title']} | {task['change']}: {task['citation']} | {task['domain']} | "
                         f"{task['region']} | {task['owner_role']} | {task['due']} | {task['status']} | {at_risk} |")
        lines += ["", "## Audit trail", "", "| Task | Date | Event | By | Note |", "|---|---|---|---|---|"]
        for task in register["tasks"]:
            for item in task["history"]:
                lines.append(f"| {task['id']} | {item['at']} | {item['event']} | {item['by']} | {item['note']} |")
        _write(self.knowledge / "tracking" / "task-register.md", "\n".join(lines) + "\n")


def _owner_roles() -> List[str]:
    text = (crawler.DATA / "internal" / "owners.md").read_text(encoding="utf-8")
    section = text.split("## Who owns which domain", 1)[1].split("##", 1)[0]
    return [row.split("|")[2].strip() for row in section.splitlines() if row.startswith("| ") and "---" not in row][1:]


def render_document(record: dict, entry: dict) -> str:
    version, document_id = record["version"], record["document_id"]
    later = [v for v in entry["versions"] if v["version"] > version]
    status = f"Superseded by v{later[0]['version']} on {record['superseded_on']}. Do not use for new decisions." if later else "Current"
    rows = [
        ("Document ID", document_id), ("Version", f"v{version}"), ("Status", status),
        ("Cite paragraphs as", f"{document_id} v{version} p<number>"),
        ("Publisher", record["publisher"]), ("Source kind", record["source_kind"]), ("Region", record["region"]),
        ("Document type", FRIENDLY_TYPES[record["document_type"]]), ("Published", record["published"] or "not stated"),
        ("Effective", record["effective"] or "not stated"), ("Detected by monitor", record["detected"]),
        ("Impacted domains (keyword tags)", ", ".join(record["domains"]) or "none found"),
        ("Caldova products named", ", ".join(record["products_named"]) or "none named"),
        ("Caldova sells in this region", "yes" if record["caldova_sells_in_region"] else "no"),
        ("Source address", record["urls"][0]),
        ("Also published at", ", ".join(record["urls"][1:]) or "-"),
        ("Content hash (SHA-256)", record["content_hash"]),
    ]
    lines = [f"# {document_id} v{version}: {record['title']}", "",
             "Synthetic training document. Not a real regulatory publication.", "",
             "| Field | Value |", "|---|---|"]
    lines += [f"| {name} | {value} |" for name, value in rows]
    lines += ["", "## Text", ""]
    for number, paragraph in enumerate(record["paragraphs"], 1):
        lines += [f"[{document_id} v{version} p{number}] {paragraph}", ""]
    return "\n".join(lines)


def render_change_log(state: dict) -> str:
    lines = ["# Regulatory change log", "",
             "Written by the Regulatory Web and Change Monitor. One row per detected document version.", "",
             "| Document | Version | Status | Detected | Type | Region | Title | Effective | Domains | Caldova products named |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for document_id, entry in sorted(state["documents"].items()):
        for record in entry["versions"]:
            status = f"superseded {record['superseded_on']}" if record["superseded_on"] else "current"
            lines.append(f"| {document_id} | v{record['version']} | {status} | {record['detected']} | "
                         f"{FRIENDLY_TYPES[record['document_type']]} | {record['region']} | {record['title']} | "
                         f"{record['effective'] or '-'} | {', '.join(record['domains']) or '-'} | "
                         f"{', '.join(record['products_named']) or '-'} |")
    lines += ["", "## Monitor runs", "", "| Day | Date | Pages crawled | New | Updated | Duplicates | Skipped links |",
              "|---|---|---|---|---|---|---|"]
    for run in state["runs"]:
        lines.append(f"| {run['day']} | {run['date']} | {run['pages_crawled']} | {run['new']} | {run['updated']} | "
                     f"{run['duplicates']} | {run['skipped_links']} |")
    return "\n".join(lines) + "\n"
