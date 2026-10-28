import ast
import json
from pathlib import Path

import pytest

from regintel import crawler
from regintel.__main__ import main
from regintel.lake import Lake, LakeError

LAB = Path(__file__).resolve().parents[1]


@pytest.fixture
def lake(tmp_path):
    return Lake(tmp_path / "lake")


def test_monday_crawl_detects_every_publication_type_once(lake):
    report = lake.monitor("monday")
    assert report["pages_crawled"] == 15 and report["navigation_pages"] == 5
    assert len(report["new"]) == 9 and report["updated"] == []
    assert len(report["duplicates"]) == 1 and "same content at another address" in report["duplicates"][0]
    assert report["skipped_links"] == 2
    documents = lake.state()["documents"]
    assert {v["versions"][0]["document_type"] for v in documents.values()} == crawler.DOCUMENT_TYPES
    assert {v["versions"][0]["region"] for v in documents.values()} == {"UK", "EU", "US"}
    domains = {d for v in documents.values() for d in v["versions"][0]["domains"]}
    assert domains == {"clinical", "labelling", "manufacturing", "vigilance", "market access"}


def test_tuesday_detects_revision_and_supersedes_previous_version(lake):
    lake.monitor("monday")
    report = lake.monitor("tuesday")
    assert report["new"] == [] and report["updated"] == ["US-CD-2027-015 v2"]
    assert len(report["duplicates"]) == 9
    old, new = lake.state()["documents"]["US-CD-2027-015"]["versions"]
    assert old["superseded_on"] == "2027-01-12" and new["superseded_on"] is None
    assert new["effective"] == "2027-04-01"
    v1 = (lake.knowledge / "documents" / "US-CD-2027-015-v1.md").read_text(encoding="utf-8")
    assert "Superseded by v2 on 2027-01-12" in v1
    event = json.loads((lake.raw / "events" / "EVT-US-CD-2027-015-v2.json").read_text(encoding="utf-8"))
    assert event["change"] == "updated" and event["supersedes"] == "US-CD-2027-015 v1"


def test_rerun_is_idempotent_and_order_is_enforced(lake):
    with pytest.raises(LakeError, match="Crawl monday first"):
        lake.monitor("tuesday")
    lake.monitor("monday")
    events = sorted(p.name for p in (lake.raw / "events").iterdir())
    again = lake.monitor("monday")
    assert again["new"] == [] and again["updated"] == []
    assert sorted(p.name for p in (lake.raw / "events").iterdir()) == events


def test_normalisation_strips_boilerplate_and_anchors_paragraphs(lake):
    lake.monitor("monday")
    text = (lake.knowledge / "documents" / "EU-SA-2027-004-v1.md").read_text(encoding="utf-8")
    assert "Fictional training portal" not in text and "Subscribe" not in text
    assert "[EU-SA-2027-004 v1 p3] The marketing authorisation holder must submit a variation" in text
    assert "Also published at | portal://eu-medicines-regulator/news/2027-01-11-caldivex.html" in text
    record = lake.version("EU-SA-2027-004", 1)
    assert record["products_named"] == ["CDX-TAB", "CDX-PEN"]
    assert lake.version("EU-GD-2027-019", 1)["products_named"] == []
    # The warning letter never names Caldivex: the link to the pen must come from the quality records.
    assert lake.version("US-EL-2027-007", 1)["products_named"] == []
    assert lake.version("US-CD-2027-015", 1)["domains"] == ["market access"]


def test_lake_contains_internal_artefacts_reference_data_and_task_register(lake):
    lake.monitor("monday")
    names = {p.name for p in (lake.knowledge / "internal").iterdir()}
    assert names == {"products.md", "labels.md", "studies.md", "submissions.md", "sops.md",
                     "quality-records.md", "market-access.md", "owners.md", "history.md"}
    assert (lake.knowledge / "reference" / "geographies.md").is_file()
    register = (lake.knowledge / "tracking" / "task-register.md").read_text(encoding="utf-8")
    assert "| TASK-2026-044 |" in register and "| open | yes |" in register


def test_cli_reports_errors_without_traceback(tmp_path, capsys):
    assert main(["--lake", str(tmp_path / "l"), "monitor", "--day", "tuesday"]) == 1
    assert "ERROR: Crawl monday first" in capsys.readouterr().err
    assert main(["--lake", str(tmp_path / "l"), "monitor", "--day", "monday"]) == 0
    assert "New documents:          9" in capsys.readouterr().out
    saved = (tmp_path / "l" / "lake-raw" / "reports" / "monitor-monday-run1.txt").read_text(encoding="utf-8")
    assert "run 1" in saved and "Duplicates ignored:     1" in saved
    assert main(["--lake", str(tmp_path / "l"), "monitor", "--day", "monday"]) == 0
    rerun = capsys.readouterr().out
    assert "run 2" in rerun and "Nothing changed since the last crawl" in rerun
    assert (tmp_path / "l" / "lake-raw" / "reports" / "monitor-monday-run1.txt").read_text(encoding="utf-8") == saved


def test_az_never_reads_the_terminal_or_draws_progress(monkeypatch):
    import regintel.__main__ as cli

    calls = []
    monkeypatch.setattr(cli.shutil, "which", lambda name: "az")
    monkeypatch.setattr(cli.subprocess, "run", lambda command, **kwargs: calls.append((command, kwargs))
                        or type("Done", (), {"returncode": 0, "stdout": "", "stderr": ""})())
    cli._az("storage", "blob", "upload-batch", "--account-name", "x")
    cli._az("storage", "blob", "download", "--account-name", "x")
    assert "--no-progress" in calls[0][0] and "--no-progress" not in calls[1][0]
    assert all(kwargs["stdin"] is cli.subprocess.DEVNULL for _, kwargs in calls)


def test_tools_run_on_cloud_shell_python():
    for path in (LAB / "regintel").glob("*.py"):
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path), feature_version=(3, 9))
