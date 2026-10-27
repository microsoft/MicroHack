import os
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB / "orchestrator"))

from configuration import Configuration  # noqa: E402

ENDPOINT = "https://caldova.services.ai.azure.com/api/projects/regulatory-intelligence"


@pytest.mark.parametrize("endpoint", ["", "http://x/api/projects/p", "https://x/other", "https://u:p@x/api/projects/p",
                                      "https://x/api/projects/p?k=1"])
def test_endpoint_is_validated(endpoint):
    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": endpoint}, clear=True), pytest.raises(ValueError):
        Configuration.from_environment()


def test_defaults_use_workshop_agent_names_and_latest_versions():
    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT}, clear=True):
        config = Configuration.from_environment()
    assert config.names == {"CITATION": "citation-agent", "IMPACT": "impact-agent", "BRIEFING": "briefing-agent"}
    assert config.versions == {"CITATION": None, "IMPACT": None, "BRIEFING": None}
    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT, "IMPACT_AGENT_VERSION": "latest"}, clear=True):
        with pytest.raises(ValueError):
            Configuration.from_environment()


class NoNetworkCredential:
    def get_token(self, *args, **kwargs):
        raise AssertionError("Building the workflow must not request tokens")

    def close(self):
        pass


def test_real_sdk_chain_builds_offline():
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    from workflow import build_workflow

    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT}, clear=True):
        config = Configuration.from_environment()
    with patch("socket.socket.connect", side_effect=AssertionError("Unexpected network access")):
        assistant = build_workflow(config, NoNetworkCredential(), {"CITATION": "1", "IMPACT": "2", "BRIEFING": "3"})
    assert assistant.name == "regulatory-intelligence-assistant"


def test_event_processor_writes_pending_briefings_once(tmp_path):
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    import asyncio

    import process_events
    from regintel.lake import Lake

    lake = Lake(tmp_path / "lake")
    lake.monitor("monday")
    prompts = []

    class FakeAssistant:
        async def run(self, prompt):
            prompts.append(prompt)
            return SimpleNamespace(text="## Executive briefing\nProposed plan awaiting sign-off.")

    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT}, clear=True):
        config = Configuration.from_environment()
    with patch("workflow.resolve_versions", return_value={"CITATION": "1", "IMPACT": "1", "BRIEFING": "1"}), \
         patch("workflow.build_workflow", return_value=FakeAssistant()):
        written = asyncio.run(process_events.process(config, lake, NoNetworkCredential(), "EVT-EU-SA-2027-004-v1", 3))
        assert len(written) == 1
        again = asyncio.run(process_events.process(config, lake, NoNetworkCredential(), "EVT-EU-SA-2027-004-v1", 3))
    assert again == []
    briefing = written[0].read_text(encoding="utf-8")
    assert "PENDING HUMAN SIGN-OFF" in briefing and "citation-agent v1" in briefing
    assert "EU-SA-2027-004 v1" in prompts[0] and "Do not approve anything" in prompts[0]
    assert len(process_events.pending_events(lake)) == 8


def test_hosted_azure_yaml_never_hard_codes_versions():
    text = (LAB / "orchestrator" / "azure.yaml").read_text(encoding="utf-8")
    assert "AGENT_VERSION" not in text and "REGINTEL_MANAGED_IDENTITY" in text


def test_checker_passes_the_finished_chain_and_guides_the_starter():
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    import check_starter

    assert check_starter.check(check_starter.load(LAB / "orchestrator" / "workflow.py")) == []
    problems = check_starter.check(check_starter.load(LAB / "orchestrator" / "starter" / "workflow.py"))
    assert problems == ["TODO 1: create one AgentExecutor per saved agent"]


def test_checker_spots_a_wrong_chain(tmp_path):
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    import check_starter

    wrong = (LAB / "orchestrator" / "workflow.py").read_text(encoding="utf-8")
    wrong = wrong.replace('builder.add_edge(executors["IMPACT"], executors["BRIEFING"])',
                          'builder.add_edge(executors["CITATION"], executors["BRIEFING"])')
    wrong = wrong.replace('context_mode="custom", context_filter=handover(role)', 'context_mode="full"')
    path = tmp_path / "wrong" / "workflow.py"
    path.parent.mkdir()
    path.write_text(wrong, encoding="utf-8")
    problems = " ".join(check_starter.check(check_starter.load(path)))
    assert "Expected the edges" in problems and "context_mode='custom'" in problems


def test_checker_spots_the_wrong_handover(tmp_path):
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    import check_starter

    wrong = (LAB / "orchestrator" / "workflow.py").read_text(encoding="utf-8")
    wrong = wrong.replace("context_filter=handover(role)", 'context_filter=handover("IMPACT")')
    path = tmp_path / "wrong" / "workflow.py"
    path.parent.mkdir()
    path.write_text(wrong, encoding="utf-8")
    problems = " ".join(check_starter.check(check_starter.load(path)))
    assert "handover('BRIEFING')" in problems and "handover('IMPACT')" not in problems


def test_handover_phrases_the_previous_answer_as_a_request():
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    from agent_framework import Message
    from workflow import handover

    conversation = [Message(role="user", contents=["event"]), Message(role="assistant", contents=["Does not apply."])]
    handed = handover("BRIEFING")(conversation)
    assert len(handed) == 1 and handed[0].role == "user"
    assert handed[0].text.startswith("Prepare the action plan for sign-off") and handed[0].text.endswith("Does not apply.")


def test_unfinished_starter_is_refused_before_any_azure_call(capsys):
    pytest.importorskip("agent_framework", reason="uv sync --all-extras installs the orchestrator SDK")
    import process_events

    with patch.dict(os.environ, {"FOUNDRY_PROJECT_ENDPOINT": ENDPOINT}, clear=True), \
         patch("azure.identity.DefaultAzureCredential", side_effect=AssertionError("must not sign in")):
        assert process_events.main(["--starter"]) == 1
    assert "starter/workflow.py is not finished yet" in capsys.readouterr().err
