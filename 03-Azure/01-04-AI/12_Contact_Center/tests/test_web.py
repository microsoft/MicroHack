import importlib.util
import io
import json
import threading
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("chat_page", LAB / "web" / "app.py")
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class FakeFoundry:
    def __init__(self):
        self.calls = []

    def __call__(self, method, path, body=None):
        self.calls.append((method, path, body))
        if path == "conversations":
            return {"id": "conv_1"}
        return {"output": [
            {"type": "reasoning"},
            {"type": "message", "content": [{"type": "output_text", "text": "Hello [KB-KC-005 p1]"}]},
        ]}


def test_first_message_creates_a_conversation_and_calls_the_agent():
    fake = FakeFoundry()
    result = web.chat("Is there an outage?", call=fake, agent="contact-chat-agent")
    assert result == {"reply": "Hello [KB-KC-005 p1]", "conversation": "conv_1"}
    assert fake.calls[0][:2] == ("POST", "conversations")
    method, path, body = fake.calls[1]
    assert (method, path) == ("POST", "responses")
    assert body["conversation"] == "conv_1"
    assert body["agent_reference"] == {"name": "contact-chat-agent", "type": "agent_reference"}


def test_later_messages_reuse_the_conversation():
    fake = FakeFoundry()
    web.chat("Second turn", conversation="conv_9", call=fake)
    assert [c[1] for c in fake.calls] == ["responses"]
    assert fake.calls[0][2]["conversation"] == "conv_9"


def test_agent_name_comes_from_the_environment(monkeypatch):
    monkeypatch.setenv("AGENT_NAME", "agent-assist")
    fake = FakeFoundry()
    web.chat("Next customer, please.", call=fake)
    assert fake.calls[1][2]["agent_reference"]["name"] == "agent-assist"


def test_reply_text_ignores_tool_items():
    response = {"output": [{"type": "openapi_call"}, {"type": "message", "content": [
        {"type": "output_text", "text": "One."}, {"type": "output_text", "text": "Two."}]}]}
    assert web.reply_text(response) == "One.\n\nTwo."


@pytest.fixture
def server(monkeypatch):
    monkeypatch.setenv("FOUNDRY_PROJECT_ENDPOINT", "https://example.services.ai.azure.com/api/projects/contact-center")
    monkeypatch.setattr(web, "chat", lambda message, conversation=None: {"reply": f"echo: {message}", "conversation": conversation or "c1"})
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), web.Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}"
    httpd.shutdown()


def post(url, body):
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as err:
        return err.code, json.loads(err.read())


def test_page_and_api(server):
    with urllib.request.urlopen(server + "/") as response:
        page = response.read().decode()
    assert "/api/chat" in page and "AI assistant" in page
    assert post(server + "/api/chat", {"message": "Hi"}) == (200, {"reply": "echo: Hi", "conversation": "c1"})
    assert post(server + "/api/chat", {"message": "  "})[0] == 400
    assert post(server + "/api/other", {"message": "Hi"})[0] == 404


def test_page_never_handles_tokens():
    page = (LAB / "web" / "static" / "index.html").read_text(encoding="utf-8")
    assert "Bearer" not in page and "token" not in page.lower()
