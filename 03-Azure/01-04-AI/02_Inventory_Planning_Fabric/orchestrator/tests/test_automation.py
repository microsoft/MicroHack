import asyncio
from copy import deepcopy
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from agent_framework import AgentSession
from azure.ai.projects.models import PromptAgentDefinition

from azure.core.exceptions import ResourceNotFoundError

from configure_specialists import (
    STAGES, configure, ensure_toolbox, resolve_versions, validate_connection, with_fabric_iq,
)
from main import HostedInventoryAssistant, InventoryAssistant, MAX_TOOL_ROUNDS
from planning import ProposalRejected
from verify_hosted import (
    ENDPOINT_ATTEMPTS, HostedEndpointUnavailable, TOTAL_TURNS, create_conversation,
    exercise, proposal_token, stop_test_session,
)


PROJECT = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct/projects/proj"
CONNECTION = PROJECT + "/connections/inventory-iq"
TARGET = ("https://api.fabric.microsoft.com/v1/mcp/workspaces/"
          "11111111-1111-1111-1111-111111111111/dataagents/"
          "22222222-2222-2222-2222-222222222222/agent")


class ConfigurationAutomationTests(unittest.TestCase):
    def toolbox_project(self, tools=None, missing=False):
        project = MagicMock()
        if missing:
            project.toolboxes.get.side_effect = ResourceNotFoundError("missing")
        else:
            latest = MagicMock(version="3")
            latest.as_dict.return_value = {"tools": tools}
            project.toolboxes.get.return_value = SimpleNamespace(versions=SimpleNamespace(latest=latest))
        project.toolboxes.create_version.return_value = SimpleNamespace(version="4")
        return project

    def test_toolbox_is_created_when_missing_or_different_and_reused_when_identical(self):
        env = {"FOUNDRY_PROJECT_ENDPOINT": "https://account.services.ai.azure.com/api/projects/proj/"}
        same = [{"type": "fabric_iq_preview", "project_connection_id": CONNECTION.upper()}]
        other = [{"type": "fabric_iq_preview", "project_connection_id": CONNECTION + "-other"}]
        with patch.dict("os.environ", env):
            reused = self.toolbox_project(same)
            self.assertTrue(ensure_toolbox(reused, CONNECTION).endswith(
                "/toolboxes/inventory-fabric-iq/versions/3/mcp?api-version=v1"))
            reused.toolboxes.create_version.assert_not_called()
            for project in (self.toolbox_project(other), self.toolbox_project(missing=True)):
                self.assertIn("/versions/4/", ensure_toolbox(project, CONNECTION))
                project.toolboxes.create_version.assert_called_once()

    def test_resolves_saved_versions_without_writes_or_latest_literal(self):
        project = MagicMock()
        project.agents.get.return_value = SimpleNamespace(versions=SimpleNamespace(latest=SimpleNamespace(
            version="8", definition=SimpleNamespace(kind="prompt"),
        )))
        names = {stage: stage.lower() for stage in STAGES}
        pins = resolve_versions(project, names)
        self.assertEqual(pins["DEMAND_AGENT_VERSION"], "8")
        self.assertEqual(project.agents.get.call_count, 3)
        project.agents.create_version.assert_not_called()
        project.agents.get.return_value.versions.latest.definition.kind = "hosted"
        with self.assertRaisesRegex(ValueError, "prompt"):
            resolve_versions(project, names)

    def test_migration_preserves_other_tools_and_instructions_without_mutation(self):
        source = {
            "kind": "prompt", "model": "model", "instructions": "Keep this instruction.",
            "tools": [{"type": "fabric_dataagent_preview"},
                      {"type": "web_search_preview"},
                      {"type": "fabric_iq_preview", "project_connection_id": "old"}],
        }
        before = deepcopy(source)
        result = with_fabric_iq(source, CONNECTION)
        self.assertEqual(source, before)
        self.assertEqual(result["instructions"], source["instructions"])
        self.assertEqual(result["tools"], [
            {"type": "web_search_preview"},
            {"type": "fabric_iq_preview", "project_connection_id": CONNECTION, "require_approval": "never"},
        ])
        self.assertEqual(with_fabric_iq(result, CONNECTION), result)

    def test_reject_foreign_project_and_non_data_agent_targets(self):
        validate_connection(CONNECTION, TARGET, PROJECT)
        validate_connection(CONNECTION, TARGET.replace(
            "api.fabric.microsoft.com",
            "11111111111111111111111111111111.za1.w.api.fabric.microsoft.com",
        ), PROJECT)
        for connection, target in [
            (CONNECTION.replace("/projects/proj/", "/projects/other/"), TARGET),
            (CONNECTION, TARGET.replace("https:", "http:")),
            (CONNECTION, TARGET.replace("api.fabric.microsoft.com", "example.org")),
            (CONNECTION, TARGET.replace("api.fabric.microsoft.com", "api.fabric.microsoft.com.example.org")),
            (CONNECTION, TARGET.replace("api.fabric.microsoft.com", "user@api.fabric.microsoft.com")),
            (CONNECTION, TARGET.replace("api.fabric.microsoft.com", "api.fabric.microsoft.com:8443")),
            (CONNECTION, TARGET + "?token=secret"),
            (CONNECTION, "https://api.fabric.microsoft.com/v1/mcp/fabricaihub/integrations/m365"),
        ]:
            with self.subTest(target=target), self.assertRaises(ValueError):
                validate_connection(connection, target, PROJECT)
        with self.assertRaisesRegex(ValueError, "prompt"):
            with_fabric_iq({"kind": "hosted"}, CONNECTION)

    def project(self):
        project = MagicMock()
        source = SimpleNamespace(
            definition=PromptAgentDefinition(model="model", instructions="Test", tools=[]),
            version="1", description="Description", metadata={"workshop": "test"},
        )
        project.connections.get.return_value = SimpleNamespace(id=CONNECTION, target=TARGET)
        project.agents.get_version.return_value = source
        project.agents.get.return_value = SimpleNamespace(versions=SimpleNamespace(latest=source))
        project.agents.create_version.return_value = SimpleNamespace(version="2")
        return project, source

    def test_creates_new_versions_then_reuses_identical_versions(self):
        project, source = self.project()
        sources = {stage: (stage.lower(), "1") for stage in STAGES}
        pins = configure(project, "inventory-iq", PROJECT, sources)
        self.assertEqual(project.agents.create_version.call_count, 3)
        self.assertEqual(pins["DEMAND_AGENT_VERSION"], "2")
        project.connections.get.assert_called_once_with("inventory-iq", include_credentials=False)
        current = SimpleNamespace(
            definition=PromptAgentDefinition(with_fabric_iq(source.definition.as_dict(), CONNECTION)),
            version="2",
        )
        project.agents.get.return_value = SimpleNamespace(versions=SimpleNamespace(latest=current))
        project.agents.create_version.reset_mock()
        self.assertEqual(configure(project, "inventory-iq", PROJECT, sources), pins)
        project.agents.create_version.assert_not_called()

    def test_newer_edits_or_invalid_sources_block_all_writes(self):
        project, source = self.project()
        sources = {stage: (stage.lower(), "1") for stage in STAGES}
        project.agents.get.side_effect = [
            SimpleNamespace(versions=SimpleNamespace(latest=source)),
            SimpleNamespace(versions=SimpleNamespace(latest=SimpleNamespace(
                version="3", definition=PromptAgentDefinition(model="model", instructions="New edits"),
            ))),
        ]
        with self.assertRaisesRegex(ValueError, "newer version 3"):
            configure(project, "inventory-iq", PROJECT, sources)
        project.agents.create_version.assert_not_called()


class HostedAutomationTests(unittest.TestCase):
    def test_cleanup_skips_stopped_sandbox_and_stops_active_sandbox(self):
        project = MagicMock()
        project.agents.get_session.return_value = SimpleNamespace(status="idle")
        stop_test_session(project, "assistant", "own-session")
        project.agents.stop_session.assert_not_called()
        project.agents.get_session.side_effect = [
            SimpleNamespace(status="active"), SimpleNamespace(status="idle"),
        ]
        stop_test_session(project, "assistant", "own-session")
        project.agents.stop_session.assert_called_once_with("assistant", "own-session")

    def test_cleanup_fails_if_sandbox_stays_active(self):
        project = MagicMock()
        project.agents.get_session.return_value = SimpleNamespace(status="active")
        with self.assertRaisesRegex(RuntimeError, "did not stop"):
            stop_test_session(project, "assistant", "own-session")

    def client(self):
        client = MagicMock()
        sessions = {"first": AgentSession(), "second": AgentSession()}
        client.conversations.create.side_effect = [SimpleNamespace(id=key) for key in sessions]

        async def specialist(stage, prompt):
            if stage == "replenishment":
                return '{"lines":[{"sku":"P004","location":"Seattle","quantity":18,"unit_cost":"10.25"}]}'
            return "Recommendation"

        assistant = InventoryAssistant(specialist)

        def create(**kwargs):
            response = asyncio.run(assistant.respond(kwargs["input"], sessions[kwargs["conversation"]]))
            return SimpleNamespace(output_text=response.text, id="response", status="completed")

        client.responses.create.side_effect = create
        return client

    def test_exercises_deployed_contract_and_cleans_both_conversations(self):
        client = self.client()
        records = []
        exercise(client, "inventory-planning-assistant", "7", records)
        self.assertEqual(len(records), TOTAL_TURNS)
        self.assertIn("Status: CANCELLED", records[-1]["output"])
        self.assertEqual(client.conversations.delete.call_count, 2)
        for call in client.responses.create.call_args_list:
            self.assertTrue(call.kwargs["store"])
            self.assertEqual(call.kwargs["extra_body"]["agent_reference"]["version"], "7")

    def test_unexpected_answer_fails_and_still_cleans_up(self):
        client = self.client()
        client.responses.create.side_effect = None
        client.responses.create.return_value = SimpleNamespace(
            output_text="No data available", id="response", status="completed",
        )
        with self.assertRaisesRegex(AssertionError, "No proposal exists"):
            exercise(client, "inventory-planning-assistant", "7", [])
        self.assertEqual(client.conversations.delete.call_count, 2)

    def test_pending_response_is_not_success(self):
        client = self.client()
        client.responses.create.side_effect = None
        response = MagicMock(output_text="", id="response", status="in_progress")
        response.agent_session_id = "own-session"
        response.error = None
        response.model_dump_json.return_value = '{"status":"in_progress"}'
        client.responses.create.return_value = response
        stop = MagicMock()
        with self.assertRaisesRegex(AssertionError, "did not complete"):
            exercise(client, "inventory-planning-assistant", "7", [], stop_session=stop)
        stop.assert_called_once_with("own-session")

    def test_stops_only_returned_test_session_once_and_preserves_error(self):
        client = self.client()
        client.responses.create.side_effect = None
        error = SimpleNamespace(model_dump=lambda: {"code": "server_error", "message": "MCP handshake failed"})
        client.responses.create.return_value = SimpleNamespace(
            output_text="", id="response", status="failed", agent_session_id="own-session",
            error=error, model_dump_json=lambda: '{"status":"failed"}',
        )
        records = []
        stop = MagicMock()
        with self.assertRaises(AssertionError):
            exercise(client, "inventory-planning-assistant", "7", records, stop_session=stop)
        stop.assert_called_once_with("own-session")
        self.assertEqual(records[0]["error"]["message"], "MCP handshake failed")
        self.assertEqual(client.conversations.delete.call_count, 2)

    def test_proposal_parser_rejects_model_prose_or_final_order(self):
        for text in ("Order submitted", "Proposal: abc | Revision: 1 | Status: APPROVED"):
            with self.assertRaisesRegex(AssertionError, "No pending proposal"):
                proposal_token(text)

    def test_hosted_endpoint_gets_a_short_retry_then_a_plain_message(self):
        class ApiError(Exception):
            status_code = 404

        not_ready = ApiError("Error code: 404 - {'error': {'message': 'Project not found'}}")
        client, sleep = MagicMock(), MagicMock()
        client.conversations.create.side_effect = [not_ready, not_ready, SimpleNamespace(id="ready")]
        self.assertEqual(create_conversation(client, sleep).id, "ready")
        self.assertEqual(sleep.call_count, 2)

        client, sleep = MagicMock(), MagicMock()
        client.conversations.create.side_effect = not_ready
        with self.assertRaisesRegex(HostedEndpointUnavailable, "Project not found.*facilitator"):
            create_conversation(client, sleep)
        self.assertEqual(client.conversations.create.call_count, ENDPOINT_ATTEMPTS)

        client, sleep = MagicMock(), MagicMock()
        client.conversations.create.side_effect = ApiError("Agent 'x' not found")
        with self.assertRaises(ApiError):
            create_conversation(client, sleep)
        sleep.assert_not_called()


class HostedEndpointTests(unittest.IsolatedAsyncioTestCase):
    def environment(self):
        values = {
            "FOUNDRY_PROJECT_ENDPOINT": "https://account.services.ai.azure.com/api/projects/project",
            "TOOLBOX_ENDPOINT": "https://account.services.ai.azure.com/api/projects/project/toolboxes/iq/versions/1/mcp?api-version=v1",
        }
        for stage in STAGES:
            values[f"{stage}_AGENT_NAME"] = stage.lower()
            values[f"{stage}_AGENT_VERSION"] = "7"
        return values

    async def test_loads_pinned_participant_specialists_and_forwards_only_call_id_to_toolbox(self):
        project = MagicMock()
        project_context = AsyncMock()
        project_context.__aenter__.return_value = project
        project.get_openai_client.return_value = AsyncMock()
        snapshot = {stage.lower(): {"model": "deployment", "instructions": stage.lower()} for stage in STAGES}
        context = MagicMock(call_id="trusted-call", user_id="trusted-user")
        context.platform_headers.return_value = {"x-agent-foundry-call-id": "opaque"}
        with patch.dict("os.environ", self.environment()), \
                patch("main.get_request_context", return_value=context), \
                patch("main.load_specialists", return_value=snapshot), \
                patch("main.DefaultAzureCredential", return_value=AsyncMock()), \
                patch("main.AIProjectClient", return_value=project_context):
            async with HostedInventoryAssistant() as assistant:
                assert assistant.toolbox is not None
                self.assertEqual(assistant.toolbox.headers, {"x-agent-foundry-call-id": "opaque"})
                self.assertEqual(assistant.specialists["demand"]["instructions"], "demand")
        project.agents.get_version.assert_not_called()
        project.get_openai_client.assert_called_once_with(max_retries=0)

    def test_load_specialists_rejects_missing_or_malformed_snapshots(self):
        import json
        import tempfile
        from main import load_specialists

        good = {s.lower(): {"model": "m", "instructions": "i"} for s in STAGES}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "specialists.json"
            with self.assertRaisesRegex(RuntimeError, "missing or invalid"):
                load_specialists(path)
            path.write_text("not json", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "missing or invalid"):
                load_specialists(path)
            for broken in ({**good, "demand": {"model": "", "instructions": "i"}},
                           {**good, "optimisation": {"model": "m"}},
                           {k: v for k, v in good.items() if k != "replenishment"}, []):
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.assertRaisesRegex(RuntimeError, "no valid|missing or invalid"):
                    load_specialists(path)
            path.write_text(json.dumps(good), encoding="utf-8")
            self.assertEqual(load_specialists(path), good)

    def test_export_snapshots_pinned_definitions_and_rejects_non_prompt_agents(self):
        from configure_specialists import export_specialists

        project = MagicMock()
        project.agents.get_version.side_effect = lambda **kw: SimpleNamespace(
            definition=PromptAgentDefinition(model="gpt", instructions="Instr " + kw["agent_name"], tools=[]),
        )
        sources = {stage: (stage.lower(), "7") for stage in STAGES}
        exported = export_specialists(project, sources)
        self.assertEqual(exported["demand"], {"model": "gpt", "instructions": "Instr demand"})
        self.assertEqual({c.kwargs["agent_version"] for c in project.agents.get_version.call_args_list}, {"7"})
        project.agents.get_version.side_effect = lambda **kw: SimpleNamespace(
            definition=SimpleNamespace(as_dict=lambda: {"kind": "hosted"}),
        )
        with self.assertRaisesRegex(ValueError, "prompt specialist"):
            export_specialists(project, sources)

    async def test_missing_trusted_caller_blocks_before_opening_project(self):
        context = MagicMock(call_id=None, user_id=None)
        with patch.dict("os.environ", self.environment()), \
                patch("main.get_request_context", return_value=context), \
                patch("main.AIProjectClient") as project:
            with self.assertRaisesRegex(RuntimeError, "trusted Foundry caller"):
                await HostedInventoryAssistant().__aenter__()
        project.assert_not_called()

    async def test_specialist_uses_saved_instructions_and_data_tool_loop(self):
        assistant = HostedInventoryAssistant()
        assistant.specialists["demand"] = {"model": "deployment", "instructions": "Participant text"}
        assistant.toolbox = AsyncMock()
        assistant.toolbox.ask.return_value = "You have 4 retail stores."
        call = SimpleNamespace(
            type="function_call", name="query_inventory_data_agent", call_id="c1",
            arguments='{"userQuestion":"How many stores?"}',
        )
        first = SimpleNamespace(id="r1", output=[call], status="completed", output_text="")
        final = SimpleNamespace(id="r2", output=[], status="completed", output_text="Four stores.")
        assistant.client = AsyncMock()
        assistant.client.responses.create.side_effect = [first, final]
        self.assertEqual(await assistant.call_specialist("demand", "Plan"), "Four stores.")
        assistant.toolbox.ask.assert_awaited_once_with("How many stores?")
        second = assistant.client.responses.create.await_args_list[1].kwargs
        self.assertEqual(second["previous_response_id"], "r1")
        self.assertEqual(second["instructions"], "Participant text")
        self.assertIs(second["parallel_tool_calls"], False)
        self.assertEqual(second["input"][0]["call_id"], "c1")

    def scripted(self, stage, answers, final_text, arguments='{"userQuestion":"What is the unit cost?"}'):
        assistant = HostedInventoryAssistant()
        assistant.specialists[stage] = {"model": "deployment", "instructions": ""}
        assistant.toolbox = AsyncMock()
        assistant.toolbox.ask.side_effect = list(answers)
        assistant.client = AsyncMock()
        responses = [
            SimpleNamespace(id=f"r{index}", status="completed", output_text="", output=[SimpleNamespace(
                type="function_call", name="query_inventory_data_agent", call_id=f"c{index}", arguments=arguments,
            )]) for index in range(len(answers))
        ]
        responses.append(SimpleNamespace(id="final", status="completed", output_text=final_text, output=[]))
        assistant.client.responses.create.side_effect = responses
        return assistant

    async def test_replenishment_costs_must_come_from_fabric_answers(self):
        proposal = '{"lines":[{"sku":"P004","location":"Seattle","quantity":18,"unit_cost":"%s"}]}'
        fabric = ["The unit cost for SKU P004 is 95."]
        assistant = self.scripted("replenishment", fabric, proposal % "95.00")
        self.assertEqual(await assistant.call_specialist("replenishment", "Plan"), proposal % "95.00")
        for answers, cost in ((fabric, "29.99"), ([], "95.00")):
            assistant = self.scripted("replenishment", answers, proposal % cost)
            with self.assertRaisesRegex(ProposalRejected, "was not returned by the Fabric Data Agent"):
                await assistant.call_specialist("replenishment", "Plan")

    async def test_cost_fetched_by_an_earlier_stage_in_the_same_request_is_accepted(self):
        proposal = '{"lines":[{"sku":"P004","location":"Seattle","quantity":18,"unit_cost":"95"}]}'
        assistant = self.scripted("replenishment", [], proposal)
        assistant.fabric_answers.append("P004 Leaf Blower X2 costs $95.00 per unit.")
        self.assertEqual(await assistant.call_specialist("replenishment", "Plan"), proposal)

    async def test_tool_round_limit_is_exact_and_bad_arguments_are_rejected(self):
        assistant = self.scripted("demand", ["data"] * MAX_TOOL_ROUNDS, "Done")
        self.assertEqual(await assistant.call_specialist("demand", "Plan"), "Done")
        assistant = self.scripted("demand", ["data"] * (MAX_TOOL_ROUNDS + 1), "Done")
        with self.assertRaisesRegex(RuntimeError, "exceeded its data-query limit"):
            await assistant.call_specialist("demand", "Plan")
        for arguments in ("not json", "{}", '{"userQuestion": 5}', '{"userQuestion": "  "}'):
            assistant = self.scripted("demand", ["data"], "Done", arguments)
            with self.assertRaisesRegex(RuntimeError, "invalid data question"):
                await assistant.call_specialist("demand", "Plan")

    async def test_unknown_tool_data_failure_or_failed_response_is_not_a_proposal(self):
        assistant = HostedInventoryAssistant()
        assistant.specialists["demand"] = {"model": "deployment", "instructions": ""}
        assistant.toolbox = AsyncMock()
        assistant.client = AsyncMock()
        bad = SimpleNamespace(type="function_call", name="shell", call_id="c", arguments="{}")
        assistant.client.responses.create.return_value = SimpleNamespace(id="r", output=[bad], status="completed")
        with self.assertRaisesRegex(RuntimeError, "unknown tool"):
            await assistant.call_specialist("demand", "Plan")
        failed = MagicMock(output=[], status="failed")
        failed.model_dump_json.return_value = '{"status":"failed"}'
        assistant.client.responses.create.return_value = failed
        with self.assertRaisesRegex(RuntimeError, "demand specialist did not complete"):
            await assistant.call_specialist("demand", "Plan")
