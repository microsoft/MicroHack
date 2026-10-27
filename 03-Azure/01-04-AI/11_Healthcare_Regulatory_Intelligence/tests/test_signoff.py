import json

import pytest

from regintel.lake import Lake, LakeError


@pytest.fixture
def lake(tmp_path):
    lake = Lake(tmp_path / "lake")
    lake.monitor("monday")
    return lake


def decision(**overrides):
    value = {
        "change": "EU-SA-2027-004 v1",
        "decision": "approved",
        "approver_role": "Regulatory Affairs Lead",
        "approved_by": "Workshop participant",
        "note": "Plan agreed in readiness meeting",
        "tasks": [
            {"title": "Submit EU label variation adding liver warning", "domain": "labelling", "region": "EU",
             "owner_role": "Labelling Lead", "due": "2027-03-01", "citation": "EU-SA-2027-004 v1 p3"},
            {"title": "Agree DHPC text with the regulator", "domain": "vigilance", "region": "EU",
             "owner_role": "Pharmacovigilance Lead", "due": "2027-02-15", "citation": "EU-SA-2027-004 v1 p4"},
        ],
    }
    value.update(overrides)
    return value


def write(tmp_path, value):
    path = tmp_path / "signoff.json"
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def test_approved_plan_creates_tasks_and_audit(lake, tmp_path):
    created = lake.signoff(write(tmp_path, decision()))
    assert created == ["TASK-2027-001", "TASK-2027-002"]
    register = (lake.knowledge / "tracking" / "task-register.md").read_text(encoding="utf-8")
    assert "| TASK-2027-001 | Submit EU label variation" in register
    assert "Workshop participant (Regulatory Affairs Lead)" in register
    audit = [json.loads(line) for line in lake.audit_path.read_text(encoding="utf-8").splitlines()]
    assert audit[0]["event"] == "signoff" and audit[0]["tasks"] == created and len(audit[0]["decision_sha256"]) == 64


def test_decision_cannot_be_recorded_twice(lake, tmp_path):
    lake.signoff(write(tmp_path, decision()))
    with pytest.raises(LakeError, match="already has a recorded decision"):
        lake.signoff(write(tmp_path, decision()))


def test_content_errors_are_reported_before_the_duplicate_check(lake, tmp_path):
    lake.signoff(write(tmp_path, decision()))
    broken = decision()
    broken["tasks"][0]["citation"] = "EU-SA-2027-004 v1 p9"
    with pytest.raises(LakeError, match="not a paragraph"):
        lake.signoff(write(tmp_path, broken))


def test_rejection_is_audited_without_tasks(lake, tmp_path):
    assert lake.signoff(write(tmp_path, decision(decision="rejected", tasks=[]))) == []
    assert "rejected" in lake.audit_path.read_text(encoding="utf-8")


@pytest.mark.parametrize("overrides, message", [
    ({"change": "EU-SA-2027-999 v1"}, "detected document version"),
    ({"decision": "maybe"}, "'decision' must be"),
    ({"approver_role": "Labelling Lead"}, "Regulatory Affairs Lead"),
    ({"approved_by": "briefing-agent"}, "not an agent"),
    ({"approved_by": ""}, "needs a person"),
    ({"tasks": []}, "at least one task"),
])
def test_invalid_decisions_are_rejected(lake, tmp_path, overrides, message):
    with pytest.raises(LakeError, match=message):
        lake.signoff(write(tmp_path, decision(**overrides)))
    assert not lake.audit_path.exists()


@pytest.mark.parametrize("field, value, message", [
    ("citation", "EU-SA-2027-004 v1 p9", "not a paragraph"),
    ("citation", "the EU alert", "not a paragraph"),
    ("owner_role", "Chief Robot", "owner_role must be"),
    ("due", "next week", "'due' must be a date"),
    ("domain", "finance", "unknown domain"),
])
def test_invalid_tasks_are_rejected(lake, tmp_path, field, value, message):
    value_decision = decision()
    value_decision["tasks"][0][field] = value
    with pytest.raises(LakeError, match=message):
        lake.signoff(write(tmp_path, value_decision))


def test_manufacturing_actions_need_quality_head(lake, tmp_path):
    plan = decision(change="US-EL-2027-007 v1", tasks=[
        {"title": "Assess CMO-17 findings for CDX-PEN supply", "domain": "manufacturing", "region": "US",
         "owner_role": "Quality Head", "due": "2027-01-20", "citation": "US-EL-2027-007 v1 p4"}])
    with pytest.raises(LakeError, match="quality_approval_by"):
        lake.signoff(write(tmp_path, plan))
    plan["quality_approval_by"] = "Quality Head (workshop)"
    assert lake.signoff(write(tmp_path, plan)) == ["TASK-2027-001"]


def test_superseded_versions_cannot_be_signed_off(lake, tmp_path):
    lake.monitor("tuesday")
    plan = decision(change="US-CD-2027-015 v1", tasks=[
        {"title": "Submit evidence to the health plan", "domain": "market access", "region": "US",
         "owner_role": "Market Access Lead", "due": "2027-02-01", "citation": "US-CD-2027-015 v1 p4"}])
    with pytest.raises(LakeError, match="superseded"):
        lake.signoff(write(tmp_path, plan))
    plan["change"], plan["tasks"][0]["citation"] = "US-CD-2027-015 v2", "US-CD-2027-015 v2 p4"
    assert lake.signoff(write(tmp_path, plan)) == ["TASK-2027-001"]


def test_progress_tracking_updates_status_and_risk(lake, tmp_path):
    lake.signoff(write(tmp_path, decision()))
    lake.update_task("TASK-2027-002", "done", "Pharmacovigilance Lead", "DHPC agreed")
    lake.update_task("TASK-2026-044", "in progress", "Quality Head")
    register = (lake.knowledge / "tracking" / "task-register.md").read_text(encoding="utf-8")
    assert "| TASK-2027-002 |" in register and "| done | no |" in register
    assert "| 2027-01-11 | status | Pharmacovigilance Lead | DHPC agreed |" in register
    with pytest.raises(LakeError):
        lake.update_task("TASK-2099-001", "done", "Quality Head")
    with pytest.raises(LakeError):
        lake.update_task("TASK-2027-001", "finished", "Quality Head")
