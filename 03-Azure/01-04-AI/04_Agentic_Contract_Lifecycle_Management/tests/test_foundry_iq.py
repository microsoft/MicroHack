from __future__ import annotations

import sys
import unittest
from pathlib import Path
from types import ModuleType, SimpleNamespace
from unittest.mock import Mock, patch

SRC = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC))

from clm_common import foundry_iq  # noqa: E402
from clm_common.config import Settings  # noqa: E402
import kb_setup  # noqa: E402


SETTINGS = SimpleNamespace(
    search_endpoint="https://clmsearch.search.windows.net",
    search_index="clm-corpus",
    foundry_iq_knowledge_source="clm-corpus-ks",
    foundry_iq_knowledge_base="clm-contracts-kb",
    foundry_iq_connection_name="clm-knowledge-mcp",
    foundry_iq_api_version="2026-05-01-preview",
    foundry_iq_enabled=True,
    model_drafting="gpt-5.4",
    require_project=lambda: (
        "https://clmfoundry.services.ai.azure.com/api/projects/clm-project"
    ),
)


class FoundryIqTests(unittest.TestCase):
    def test_model_resource_uri_uses_foundry_account_name(self):
        self.assertEqual(
            foundry_iq.model_resource_uri(SETTINGS.require_project()),
            "https://clmfoundry.openai.azure.com",
        )

    @patch.object(foundry_iq, "settings", SETTINGS)
    def test_knowledge_source_wraps_existing_semantic_index(self):
        payload = foundry_iq.knowledge_source_payload()
        self.assertEqual(payload["kind"], "searchIndex")
        self.assertEqual(
            payload["searchIndexParameters"]["semanticConfigurationName"],
            "clm-semantic",
        )
        self.assertEqual(
            payload["searchIndexParameters"]["searchIndexName"],
            "clm-corpus",
        )

    @patch.object(foundry_iq, "settings", SETTINGS)
    def test_knowledge_base_enables_low_effort_query_planning(self):
        payload = foundry_iq.knowledge_base_payload()
        self.assertEqual(payload["outputMode"], "extractiveData")
        self.assertEqual(payload["retrievalReasoningEffort"], {"kind": "low"})
        self.assertEqual(
            payload["models"][0]["azureOpenAIParameters"]["deploymentId"],
            "gpt-5.4",
        )
        self.assertNotIn(
            "apiKey",
            payload["models"][0]["azureOpenAIParameters"],
        )

    @patch.object(foundry_iq, "settings", SETTINGS)
    def test_mcp_tool_is_limited_to_knowledge_retrieval(self):
        tool = foundry_iq.mcp_tool_kwargs()
        self.assertEqual(tool["allowed_tools"], ["knowledge_base_retrieve"])
        self.assertEqual(tool["require_approval"], "never")
        self.assertIn("/knowledgebases/clm-contracts-kb/mcp", tool["server_url"])

    @patch.object(foundry_iq, "settings", SETTINGS)
    def test_build_knowledge_tool_selects_foundry_iq(self):
        with patch.object(kb_setup, "settings", SETTINGS):
            tool = kb_setup.build_knowledge_tool()
        self.assertEqual(tool["type"], "mcp")
        self.assertEqual(tool["allowed_tools"], ["knowledge_base_retrieve"])

    def test_build_knowledge_tool_retains_legacy_search_fallback(self):
        legacy = SimpleNamespace(
            foundry_iq_enabled=False,
            search_index="clm-corpus",
        )
        factory = Mock(
            return_value={
                "type": "azure_ai_search",
                "connection": "legacy-connection",
            }
        )
        fake_foundry = ModuleType("agent_framework.foundry")
        fake_foundry.FoundryChatClient = SimpleNamespace(
            get_azure_ai_search_tool=factory
        )
        with (
            patch.object(kb_setup, "settings", legacy),
            patch.dict(sys.modules, {"agent_framework.foundry": fake_foundry}),
        ):
            tool = kb_setup.build_knowledge_tool(connection_id="legacy-connection")
        self.assertEqual(tool["type"], "azure_ai_search")
        factory.assert_called_once_with(
            index_connection_id="legacy-connection",
            index_name="clm-corpus",
            query_type="semantic",
            top_k=5,
        )

    def test_existing_environment_defaults_to_legacy_search(self):
        with patch.dict(
            "os.environ",
            {"FOUNDRY_IQ_KNOWLEDGE_BASE": ""},
            clear=False,
        ):
            self.assertFalse(Settings().foundry_iq_enabled)

    @patch.object(foundry_iq, "settings", SETTINGS)
    @patch.object(foundry_iq, "_put_search_object")
    def test_ensure_is_idempotent_put_for_source_then_base(self, put):
        foundry_iq.ensure_foundry_iq()
        self.assertEqual(
            [call.args[0] for call in put.call_args_list],
            [
                "knowledgesources/clm-corpus-ks",
                "knowledgebases/clm-contracts-kb",
            ],
        )

    @patch.object(foundry_iq, "settings", SETTINGS)
    @patch.object(foundry_iq, "credential")
    @patch.object(foundry_iq.requests, "put")
    def test_rest_errors_are_propagated(self, put, credential):
        credential.return_value.get_token.return_value.token = "token"
        response = put.return_value
        response.raise_for_status.side_effect = RuntimeError("request failed")
        with self.assertRaisesRegex(RuntimeError, "request failed"):
            foundry_iq._put_search_object("knowledgebases/test", {})


if __name__ == "__main__":
    unittest.main()
