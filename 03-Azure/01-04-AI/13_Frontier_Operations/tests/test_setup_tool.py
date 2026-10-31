import json
import sys
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB))
import frontierops.__main__ as tool  # noqa: E402


def test_packs_lists_five_companies(capsys):
    assert tool.main(["packs"]) == 0
    out = capsys.readouterr().out
    for company in ["Ashgrove Supply", "Kestrel Connect", "Lumora Energy", "Northmere Insurance", "Parcelpine"]:
        assert company in out


def test_setup_uploads_selects_pack_and_prepares_files(tmp_path, monkeypatch, capsys):
    calls = []
    monkeypatch.setattr(tool, "_az", lambda *a, **k: calls.append(a) or "")
    monkeypatch.setattr(tool, "MY_FILES", tmp_path / "my-files")
    assert tool.main(["--account", "stfrontierx", "setup", "--industry", "telco"]) == 0
    verbs = [" ".join(c[:3]) for c in calls]
    assert verbs == ["storage blob delete-batch", "storage blob upload-batch", "storage blob upload"]
    assert ("--container-name", "ops-state") == calls[2][4:6] or "ops-state" in calls[2]
    files = sorted(p.relative_to(tmp_path / "my-files").as_posix() for p in (tmp_path / "my-files").rglob("*") if p.is_file())
    assert "handbook.md" in files and "ledger-export.csv" in files and sum(f.startswith("statements/") for f in files) == 5
    out = capsys.readouterr().out
    assert "Kestrel Connect" in out and "Carrier Exchange" in out


def test_setup_rejects_unknown_industry(capsys):
    assert tool.main(["--account", "x", "setup", "--industry", "banking"]) == 1
    assert "Unknown industry" in capsys.readouterr().err


def test_setup_replaces_files_from_another_pack(tmp_path, monkeypatch):
    monkeypatch.setattr(tool, "_az", lambda *a, **k: "")
    monkeypatch.setattr(tool, "MY_FILES", tmp_path / "my-files")
    tool.main(["--account", "x", "setup", "--industry", "telco"])
    tool.main(["--account", "x", "setup", "--industry", "retail"])
    names = {p.stem for p in (tmp_path / "my-files" / "statements").glob("*.csv")}
    assert names == {"shopwell", "brightbasket", "homeharbour", "gardenly", "dealdock"}


def test_grant_agent_assigns_foundry_user_to_the_agent_identity(monkeypatch, capsys):
    calls = []

    def fake(*args, capture=False, storage=True):
        calls.append(args)
        if args[0] == "rest":
            return json.dumps({"versions": {"latest": {"instance_identity": {"principal_id": "abc-123"}}}})
        if args[:3] == ("role", "assignment", "list"):
            return "[]"
        return ""

    monkeypatch.setattr(tool, "_az", fake)
    assert tool.main(["grant-agent", "ops-agent", "--project-endpoint", "https://x/api/projects/p", "--project-id", "/subs/p"]) == 0
    create = next(c for c in calls if c[:3] == ("role", "assignment", "create"))
    assert "abc-123" in create and tool.FOUNDRY_USER in create and "/subs/p" in create
    assert "Granted Foundry User" in capsys.readouterr().out


def test_grant_agent_needs_a_saved_agent(monkeypatch, capsys):
    monkeypatch.setattr(tool, "_az", lambda *a, **k: json.dumps({"versions": {"latest": {}}}))
    assert tool.main(["grant-agent", "x", "--project-endpoint", "e", "--project-id", "p"]) == 1
    assert "no identity yet" in capsys.readouterr().err
