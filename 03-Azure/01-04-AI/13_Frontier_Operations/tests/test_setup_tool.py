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


def test_grant_agent_finds_the_agent_identity_by_name_and_assigns_foundry_user(monkeypatch, capsys):
    calls = []

    def fake(*args, capture=False, storage=True):
        calls.append(args)
        if args[:3] == ("ad", "sp", "list"):
            assert args[4] == "acct-proj-ops-agent-AgentIdentity"
            return json.dumps(["abc-123"])
        if args[:3] == ("role", "assignment", "list"):
            return "[]"
        if args[0] == "rest":
            pytest.fail("Cloud Shell can't get a Foundry token; the Graph lookup must be enough")
        return ""

    monkeypatch.setattr(tool, "_az", fake)
    project = "/subscriptions/s/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct/projects/proj"
    assert tool.main(["grant-agent", "ops-agent", "--project-endpoint", "https://x/api/projects/proj", "--project-id", project]) == 0
    create = next(c for c in calls if c[:3] == ("role", "assignment", "create"))
    assert "abc-123" in create and tool.FOUNDRY_USER in create and project in create
    assert "Granted Foundry User" in capsys.readouterr().out


def test_grant_agent_falls_back_to_the_agent_definition(monkeypatch, capsys):
    def fake(*args, capture=False, storage=True):
        if args[:3] == ("ad", "sp", "list"):
            return "[]"
        if args[0] == "rest":
            return json.dumps({"versions": {"latest": {"instance_identity": {"principal_id": "def-456"}}}})
        if args[:3] == ("role", "assignment", "list"):
            return "[]"
        return ""

    monkeypatch.setattr(tool, "_az", fake)
    assert tool.main(["grant-agent", "a", "--project-endpoint", "e", "--project-id", "/x/accounts/a/projects/p"]) == 0
    assert "def-456" in capsys.readouterr().out


def test_grant_agent_needs_a_saved_agent(monkeypatch, capsys):
    def fake(*args, capture=False, storage=True):
        if args[0] == "rest":
            raise tool.SetupError("no token")
        return "[]"

    monkeypatch.setattr(tool, "_az", fake)
    assert tool.main(["grant-agent", "x", "--project-endpoint", "e", "--project-id", "/x/accounts/a/projects/p"]) == 1
    assert "no identity yet" in capsys.readouterr().err


def test_publish_skill_explains_how_to_sign_in_for_foundry(tmp_path, monkeypatch, capsys):
    folder = _write_skill(tmp_path / "reconciliation", GOOD)

    def fake(*args, capture=False, storage=True):
        raise tool.SetupError("Azure command failed: az account get-access-token\nTimeout waiting for token from portal.")

    monkeypatch.setattr(tool, "_az", fake)
    assert tool.main(["publish-skill", str(folder), "--project-endpoint", "e"]) == 1
    err = capsys.readouterr().err
    assert "az login --use-device-code --scope https://ai.azure.com/.default" in err and "Timeout" in err


def _write_skill(folder, text):
    folder.mkdir(parents=True)
    (folder / "SKILL.md").write_text(text, encoding="utf-8")
    return folder


GOOD = "---\nname: reconciliation\ndescription: How we reconcile partner statements.\n---\n\n# Method\n\nMatch by reference.\n"


def test_setup_gives_a_starter_skill_with_todos(tmp_path, monkeypatch):
    monkeypatch.setattr(tool, "_az", lambda *a, **k: "")
    monkeypatch.setattr(tool, "MY_FILES", tmp_path / "my-files")
    tool.main(["--account", "x", "setup", "--industry", "energy"])
    starter = tmp_path / "my-files" / "skills" / "reconciliation"
    assert (starter / "SKILL.md").is_file()
    with pytest.raises(tool.SetupError, match="TODO"):
        tool.read_skill(starter)


def test_publish_skill_uploads_a_zip_with_skill_md_at_the_root(tmp_path, monkeypatch, capsys):
    import io
    import zipfile
    folder = _write_skill(tmp_path / "reconciliation", GOOD)
    (folder / "examples.md").write_text("example", encoding="utf-8")
    (folder / ".hidden").write_text("x", encoding="utf-8")
    sent = {}
    monkeypatch.setattr(tool, "_az", lambda *a, **k: "token-123\n")

    def fake_upload(url, token, archive, name):
        sent.update(url=url, token=token, names=zipfile.ZipFile(io.BytesIO(archive)).namelist(), name=name)
        return {"name": name, "version": "3"}

    monkeypatch.setattr(tool, "_upload_skill", fake_upload)
    monkeypatch.setattr(tool, "_set_default_skill_version", lambda url, token, version: sent.update(default=(url, version)))
    assert tool.main(["publish-skill", str(folder), "--project-endpoint", "https://x/api/projects/p/"]) == 0
    assert sent["url"] == "https://x/api/projects/p/skills/reconciliation/versions?api-version=v1"
    assert sent["default"] == ("https://x/api/projects/p/skills/reconciliation?api-version=v1", "3")
    assert sent["token"] == "token-123"
    assert sorted(sent["names"]) == ["SKILL.md", "examples.md"]
    assert "version 3" in capsys.readouterr().out


@pytest.mark.parametrize("text, message", [
    ("# no front matter\n", "front matter"),
    ("---\nname: reconciliation\n---\nbody\n", "description"),
    ("---\nname: \"reconciliation\"\ndescription: x\n---\nbody\n", "quotes"),
    ("---\nname: Reconciliation\ndescription: x\n---\nbody\n", "isn't valid"),
    ("---\nname: other-name\ndescription: x\n---\nbody\n", "must match the folder"),
    ("---\nname: reconciliation\ndescription: x\n---\n\n", "no instructions"),
])
def test_publish_skill_explains_problems_before_uploading(tmp_path, monkeypatch, capsys, text, message):
    folder = _write_skill(tmp_path / "reconciliation", text)
    monkeypatch.setattr(tool, "_az", lambda *a, **k: pytest.fail("must not call Azure"))
    assert tool.main(["publish-skill", str(folder), "--project-endpoint", "e"]) == 1
    assert message in capsys.readouterr().err


def test_publish_skill_needs_a_skill_md(tmp_path, capsys):
    (tmp_path / "empty").mkdir()
    assert tool.main(["publish-skill", str(tmp_path / "empty"), "--project-endpoint", "e"]) == 1
    assert "no SKILL.md" in capsys.readouterr().err


def test_every_handbook_is_a_valid_skill_body(tmp_path):
    for handbook in tool.PACKS.glob("*/handbook.md"):
        folder = _write_skill(tmp_path / handbook.parent.name / "reconciliation",
                              "---\nname: reconciliation\ndescription: Our method.\n---\n\n" + handbook.read_text(encoding="utf-8"))
        assert tool.read_skill(folder)[0] == "reconciliation"


def _xlsx(path, sheets):
    """Write a minimal .xlsx with inline strings, like the ones agents return."""
    import zipfile
    from xml.sax.saxutils import escape
    with zipfile.ZipFile(path, "w") as book:
        names = list(sheets)
        book.writestr("xl/workbook.xml", '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
                      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
                      + "".join(f'<sheet name="{escape(n, {chr(34): "&quot;"})}" sheetId="{i}" r:id="rId{i}"/>' for i, n in enumerate(names, 1))
                      + "</sheets></workbook>")
        book.writestr("xl/_rels/workbook.xml.rels", '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                      + "".join(f'<Relationship Id="rId{i}" Target="worksheets/sheet{i}.xml"/>' for i in range(1, len(names) + 1))
                      + "</Relationships>")
        for i, name in enumerate(names, 1):
            rows = "".join("<row>" + "".join(f'<c t="inlineStr"><is><t>{escape(str(v))}</t></is></c>' for v in row) + "</row>"
                           for row in sheets[name])
            book.writestr(f"xl/worksheets/sheet{i}.xml", '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
                          f"<sheetData>{rows}</sheetData></worksheet>")


LABELS = {"mismatch": "Amount mismatch", "missing_on_statement": "Missing on statement", "missing_in_ledger": "Missing in ledger",
          "duplicate": "Possible duplicate charge", "credit": "Credit to confirm"}


def _answer_key_workbook(path, pack, labels=LABELS):
    expected = json.loads((tool.PACKS / pack / "expected.json").read_text(encoding="utf-8"))
    partners = {p["id"]: p["name"] for p in tool.packs()[pack]["partners"]}
    sheets = {"Summary": [["Partner", "Money at stake"]]}
    for pid, name in partners.items():
        sheets[name[:31]] = [["Reference", "Category", "Action"]] + [
            [e["reference"], labels[e["kind"]], e["action"]] for e in expected if e["partner_id"] == pid and e["kind"] in labels]
    _xlsx(path, sheets)


@pytest.mark.parametrize("pack", ["distribution", "telco", "energy", "insurance", "retail"])
def test_score_gives_full_marks_for_the_answer_key(tmp_path, pack):
    _answer_key_workbook(tmp_path / "x.xlsx", pack)
    result = tool.score(tmp_path / "x.xlsx", pack)
    assert result["correct"] == result["total"] == 30 and not result["extra"]


def test_score_spots_the_typical_mistakes_without_a_skill(tmp_path, capsys):
    loose = dict(LABELS, duplicate="Statement only", credit="Statement only", missing_in_ledger="Statement only",
                 missing_on_statement="Ledger only")
    _answer_key_workbook(tmp_path / "x.xlsx", "distribution", loose)
    assert tool.main(["score", str(tmp_path / "x.xlsx"), "--industry", "distribution"]) == 0
    out = capsys.readouterr().out
    assert "Score: 20 of 30" in out
    assert "should be credit to confirm, the workbook says missing in ledger" in out


def test_score_flags_lines_that_are_not_in_the_answer_key(tmp_path):
    _xlsx(tmp_path / "x.xlsx", {"Kellerman": [["Reference", "Issue type"], ["NOTE", "Statement only"],
                                              ["Total money at stake", "", "3200.10"]]})
    result = tool.score(tmp_path / "x.xlsx", "distribution")
    assert result["extra"] == ["Kellerman Hygiene NOTE"]
    assert result["total"] == 6, "only the partners in the workbook are scored"


def test_score_needs_partner_sheets(tmp_path, capsys):
    _xlsx(tmp_path / "x.xlsx", {"Summary": [["Partner", "Total"]]})
    assert tool.main(["score", str(tmp_path / "x.xlsx"), "--industry", "distribution"]) == 1
    assert "one sheet per partner" in capsys.readouterr().err


def test_score_explains_a_file_that_is_not_a_workbook(tmp_path, capsys):
    (tmp_path / "x.xlsx").write_text("not a workbook", encoding="utf-8")
    assert tool.main(["score", str(tmp_path / "x.xlsx"), "--industry", "distribution"]) == 1
    assert "Excel workbook" in capsys.readouterr().err
