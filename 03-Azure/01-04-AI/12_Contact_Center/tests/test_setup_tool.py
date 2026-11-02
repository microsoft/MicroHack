import json
import sys
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB))
from contactcenter import __main__ as cli  # noqa: E402

PACKS = ["telco", "energy", "bank", "insurance", "retail"]


def test_all_five_packs_are_listed(capsys):
    assert cli.main(["packs"]) == 0
    out = capsys.readouterr().out
    for company in ("Kestrel Connect", "Lumora Energy", "Harbourline Bank", "Northmere Insurance", "Parcelpine"):
        assert company in out


@pytest.mark.parametrize("pack", PACKS)
def test_stage_puts_only_this_pack_in_each_container(tmp_path, pack):
    staged = cli.stage(pack, tmp_path)
    prefix = cli.packs()[pack]["prefix"]
    assert len(staged["knowledge"]) == 8 and all(name.startswith(f"KB-{prefix}-") for name in staged["knowledge"])
    assert staged["insights"] == [f"{prefix}-CONTACTS.md"]
    assert len(staged["calls"]) == 3 and all(name.startswith(prefix) and name.endswith(".mp3") for name in staged["calls"])
    assert staged["evaluation"] == ["evaluation.jsonl"]


def test_setup_replaces_containers_and_selects_the_pack(monkeypatch, capsys):
    calls = []
    monkeypatch.setattr(cli, "_az", lambda *args, **kw: calls.append(args) or "")
    monkeypatch.setattr(cli.shutil, "which", lambda name: "az")
    assert cli.main(["--account", "stexample", "setup", "--industry", "Bank"]) == 0
    deletes = [a for a in calls if a[2] == "delete-batch"]
    assert {a[a.index("--source") + 1] for a in deletes} == {"knowledge", "insights", "calls", "evaluation"}
    active = [a for a in calls if a[2] == "upload" and "active.json" in a]
    assert active, "the CRM must be switched to the selected pack"
    out = capsys.readouterr().out
    assert "Harbourline Bank" in out and "HB500301" in out


def test_unknown_pack_and_missing_account_are_explained(capsys):
    assert cli.main(["--account", "x", "setup", "--industry", "airline"]) == 1
    assert "Choose one of" in capsys.readouterr().err
    assert cli.main(["setup", "--industry", "telco"]) == 1
    assert "--account" in capsys.readouterr().err
