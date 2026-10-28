import asyncio
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from toolbox import ToolboxClient, ToolboxError


class FakeToolbox(ToolboxClient):
    def __init__(self, replies, **kwargs):
        async def token():
            return "token"

        super().__init__("https://example.services.ai.azure.com/toolbox", token, {"x-agent-foundry-call-id": "id"},
                         poll_seconds=0, **kwargs)
        self.replies = list(replies)
        self.calls = []

    def _post(self, bearer, body):
        self.calls.append((bearer, body))
        reply = self.replies.pop(0)
        return reply if "error" in reply else {"result": reply}


TOOL = {"tools": [{"name": "iq___DataAgent"}]}
DONE = {"task": {"taskId": "t", "status": "working"}}


class ToolboxTests(unittest.TestCase):
    def ask(self, replies, **kwargs):
        client = FakeToolbox(replies, **kwargs)
        return client, asyncio.run(client.ask("How many retail stores?"))

    def test_uses_task_mode_polls_and_returns_text(self):
        client, answer = self.ask([
            {}, TOOL, DONE, {"taskId": "t", "status": "working"}, {"taskId": "t", "status": "completed"},
            {"content": [{"type": "text", "text": "You have 4 retail stores."}], "isError": False},
        ])
        self.assertEqual(answer, "You have 4 retail stores.")
        call = next(body for _, body in client.calls if body["method"] == "tools/call")
        self.assertEqual(call["params"]["name"], "iq___DataAgent")
        self.assertIn("task", call["params"])
        self.assertEqual(call["params"]["arguments"], {"userQuestion": "How many retail stores?"})

    def test_failed_error_or_empty_results_never_become_answers(self):
        for replies, message in [
            ([{}, TOOL, DONE, {"status": "failed"}], "failed"),
            ([{}, TOOL, DONE, {"status": "completed"}, {"content": [{"type": "text", "text": "No"}], "isError": True}],
             "returned an error"),
            ([{}, TOOL, DONE, {"status": "completed"}, {"content": []}], "no text"),
            ([{}, {"tools": []}], "exactly one"),
            ([{}, TOOL, {"error": {"message": "boom"}}], "boom"),
        ]:
            with self.subTest(message=message), self.assertRaisesRegex(ToolboxError, message):
                self.ask(replies)

    def test_times_out_instead_of_waiting_forever(self):
        with self.assertRaisesRegex(ToolboxError, "timed out"):
            self.ask([{}, TOOL, DONE] + [{"taskId": "t", "status": "working"}] * 5, timeout_seconds=0)

    def test_input_required_fails_fast(self):
        with self.assertRaisesRegex(ToolboxError, "needs input"):
            self.ask([{}, TOOL, DONE, {"taskId": "t", "status": "input_required"}])

    def test_parses_json_and_sse_by_request_id_ignoring_notifications(self):
        self.assertEqual(ToolboxClient._parse('{"id": 3, "result": {}}', 3)["id"], 3)
        stream = (
            'event: message\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\n\n'
            'id: 9\nretry: 1000\nevent: message\ndata: {"jsonrpc":"2.0","id":3,"result":{"ok":true}}\n\n'
        )
        self.assertEqual(ToolboxClient._parse(stream, 3)["result"], {"ok": True})
        with self.assertRaises(ValueError):
            ToolboxClient._parse(stream, 4)
        with self.assertRaises(ValueError):
            ToolboxClient._parse("<html>bad gateway</html>", 1)

    def test_requires_https_and_a_question(self):
        async def token():
            return "t"

        with self.assertRaises(ValueError):
            ToolboxClient("http://insecure", token)
        with self.assertRaises(ValueError):
            asyncio.run(FakeToolbox([]).ask("  "))


if __name__ == "__main__":
    unittest.main()
