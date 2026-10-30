from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from verify_configuration import validate_definition


class ConfigurationTests(unittest.TestCase):
    def test_fabric_iq_prompt_specialist_accepted(self):
        validate_definition("demand", {
            "kind": "prompt", "tools": [{"type": "fabric_iq_preview"}, {"type": "web_search_preview"}],
        })

    def test_retired_tool_rejected_even_alongside_replacement(self):
        with self.assertRaisesRegex(ValueError, "retiring"):
            validate_definition("demand", {
                "kind": "prompt", "tools": [
                    {"type": "fabric_dataagent_preview"}, {"type": "fabric_iq_preview"},
                ],
            })

    def test_missing_fabric_iq_rejected(self):
        for definition in ({"kind": "prompt"}, {"kind": "prompt", "tools": []}):
            with self.subTest(definition=definition), self.assertRaisesRegex(ValueError, "Fabric IQ"):
                validate_definition("demand", definition)

    def test_workflow_and_hosted_specialists_rejected(self):
        for kind in ("hosted", "workflow"):
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "prompt specialist"):
                validate_definition("demand", {"kind": kind, "tools": [{"type": "fabric_iq_preview"}]})
