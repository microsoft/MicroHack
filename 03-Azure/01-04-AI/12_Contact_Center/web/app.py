"""A small chat page for your contact center agent (Challenge 8).

Run it in Codespaces after `az login`:

    export FOUNDRY_PROJECT_ENDPOINT=<your FoundryProjectEndpoint>
    python3 web/app.py

The browser never sees a token: the page calls /api/chat on this server, and the server
calls the Foundry Responses API with your Azure CLI sign-in.
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

STATIC = Path(__file__).resolve().parent / "static"
_token = {"value": None, "expires": 0.0}


def get_token():
    if _token["value"] and time.time() < _token["expires"] - 300:
        return _token["value"]
    out = subprocess.run(
        ["az", "account", "get-access-token", "--resource", "https://ai.azure.com", "--output", "json"],
        capture_output=True, text=True, check=True, shell=sys.platform == "win32")
    data = json.loads(out.stdout)
    _token["value"] = data["accessToken"]
    _token["expires"] = float(data.get("expires_on") or time.time() + 1800)
    return _token["value"]


def foundry(method, path, body=None, endpoint=None, token_fn=get_token):
    endpoint = (endpoint or os.environ["FOUNDRY_PROJECT_ENDPOINT"]).rstrip("/")
    request = urllib.request.Request(
        f"{endpoint}/openai/v1/{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {token_fn()}", "Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read() or b"{}")


def reply_text(response):
    parts = []
    for item in response.get("output", []):
        if item.get("type") == "message":
            parts += [c.get("text", "") for c in item.get("content", []) if c.get("type") == "output_text"]
    return "\n\n".join(p for p in parts if p).strip()


def chat(message, conversation=None, agent=None, call=foundry):
    agent = agent or os.environ.get("AGENT_NAME", "contact-chat-agent")
    if not conversation:
        conversation = call("POST", "conversations", {})["id"]
    response = call("POST", "responses", {
        "input": message, "conversation": conversation,
        "agent_reference": {"name": agent, "type": "agent_reference"}})
    return {"reply": reply_text(response), "conversation": conversation}


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, (STATIC / "index.html").read_bytes(), "text/html; charset=utf-8")
        elif self.path == "/health":
            self._send(200, {"agent": os.environ.get("AGENT_NAME", "contact-chat-agent"),
                             "endpoint_set": bool(os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/chat":
            self._send(404, {"error": "not found"})
            return
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
            message = (body.get("message") or "").strip()
            if not message:
                self._send(400, {"error": "message is required"})
                return
            self._send(200, chat(message, body.get("conversation")))
        except urllib.error.HTTPError as err:
            self._send(502, {"error": f"Foundry returned {err.code}: {err.read().decode(errors='replace')[:300]}"})
        except subprocess.CalledProcessError:
            self._send(401, {"error": "Could not get a token. Run az login in the terminal."})
        except KeyError:
            self._send(500, {"error": "Set FOUNDRY_PROJECT_ENDPOINT before starting the server."})

    def log_message(self, *args):
        pass


def main():
    if not os.environ.get("FOUNDRY_PROJECT_ENDPOINT"):
        sys.exit("Set FOUNDRY_PROJECT_ENDPOINT to the value from your lab dashboard first.")
    port = int(os.environ.get("PORT", "8000"))
    print(f"Chat page on http://localhost:{port} (agent: {os.environ.get('AGENT_NAME', 'contact-chat-agent')})")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
