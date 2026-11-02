"""Mock contact-center CRM for the MicroHack. Standard library only (WSGI), so App Service needs no build.

Serves the active industry pack's customers, appointment slots, service notices, cases and handoffs,
and its own OpenAPI document at /openapi.json for the Foundry OpenAPI tool.

State lives in Blob Storage (container "crm-state") through the web app's managed identity:
  active.json            {"pack": "telco"}            written by the Cloud Shell setup tool
  <pack>.json            customers, slots, cases, handoffs, appointments (seeded from packs/<pack>/crm.json)
Without STORAGE_ACCOUNT the state is kept in a local folder (CRM_STATE_DIR), which the tests use.
"""
from __future__ import annotations

import json
import os
import re
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from html import escape
from pathlib import Path
from urllib.parse import parse_qs

HERE = Path(__file__).resolve().parent
PACKS = HERE / "packs"
CONTAINER = "crm-state"
_lock = threading.Lock()
_token_cache: dict = {}


class ApiError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


# ---------------------------------------------------------------- storage

class LocalStore:
    def __init__(self, folder: Path):
        self.folder = folder
        self.folder.mkdir(parents=True, exist_ok=True)

    def read(self, name: str):
        path = self.folder / name
        if not path.is_file():
            return None, None
        text = path.read_text(encoding="utf-8")
        return json.loads(text), str(hash(text))

    def write(self, name: str, value, etag=None) -> None:
        current = self.read(name)[1]
        if current != etag:
            raise ApiError(409, "State changed during the request. Try again.")
        (self.folder / name).write_text(json.dumps(value, indent=1), encoding="utf-8")


class BlobStore:
    def __init__(self, account: str):
        self.base = f"https://{account}.blob.core.windows.net/{CONTAINER}"

    def _token(self) -> str:
        cached = _token_cache.get("storage")
        if cached and cached[1] > time.time() + 300:
            return cached[0]
        endpoint, header = os.environ["IDENTITY_ENDPOINT"], os.environ["IDENTITY_HEADER"]
        url = f"{endpoint}?resource=https://storage.azure.com/&api-version=2019-08-01"
        with urllib.request.urlopen(urllib.request.Request(url, headers={"X-IDENTITY-HEADER": header}), timeout=30) as resp:
            body = json.loads(resp.read())
        _token_cache["storage"] = (body["access_token"], float(body.get("expires_on", time.time() + 3000)))
        return body["access_token"]

    def _request(self, method: str, name: str, data: bytes | None = None, headers: dict | None = None):
        all_headers = {"Authorization": f"Bearer {self._token()}", "x-ms-version": "2023-11-03"}
        all_headers.update(headers or {})
        req = urllib.request.Request(f"{self.base}/{name}", data=data, method=method, headers=all_headers)
        return urllib.request.urlopen(req, timeout=30)

    def read(self, name: str):
        try:
            with self._request("GET", name) as resp:
                return json.loads(resp.read()), resp.headers.get("ETag")
        except urllib.error.HTTPError as err:
            if err.code == 404:
                return None, None
            raise

    def write(self, name: str, value, etag=None) -> None:
        headers = {"x-ms-blob-type": "BlockBlob", "Content-Type": "application/json"}
        if etag:
            headers["If-Match"] = etag
        else:
            headers["If-None-Match"] = "*"
        try:
            self._request("PUT", name, json.dumps(value, indent=1).encode(), headers).close()
        except urllib.error.HTTPError as err:
            if err.code in (409, 412):
                raise ApiError(409, "State changed during the request. Try again.") from err
            raise


def store():
    account = os.environ.get("STORAGE_ACCOUNT")
    if account:
        return BlobStore(account)
    return LocalStore(Path(os.environ.get("CRM_STATE_DIR", HERE / ".state")))


# ---------------------------------------------------------------- pack state

def available_packs() -> list:
    if not PACKS.is_dir():
        return []
    return sorted(p.name for p in PACKS.iterdir() if (p / "crm.json").is_file())


def active_pack(st) -> str:
    value, _ = st.read("active.json")
    pack = (value or {}).get("pack") or os.environ.get("DEFAULT_PACK", "")
    if pack not in available_packs():
        # 409, not 503: the Functions front end replaces 503 responses with an empty error.
        raise ApiError(409, "No industry pack is selected yet. Run the setup command from Challenge 1.")
    return pack


def profile(pack: str) -> dict:
    return json.loads((PACKS / pack / "pack.json").read_text(encoding="utf-8"))


def load_state(st, pack: str):
    value, etag = st.read(f"{pack}.json")
    if value is None:
        seed = json.loads((PACKS / pack / "crm.json").read_text(encoding="utf-8"))
        value = {**seed, "appointments": [], "handoffs": [], "counter": 100}
        etag = None
    return value, etag


def mutate(st, pack: str, change):
    """Read, change and write the pack state with optimistic concurrency; retries on conflict."""
    for _ in range(5):
        state, etag = load_state(st, pack)
        result = change(state)
        try:
            st.write(f"{pack}.json", state, etag)
            return result
        except ApiError as err:
            if err.status != 409:
                raise
            time.sleep(0.2)
    raise ApiError(409, "The CRM is busy. Try again.")


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def next_id(state, prefix: str, kind: str) -> str:
    state["counter"] = state.get("counter", 100) + 1
    return f"{prefix}-{kind}-{state['counter']:04d}"


def mask(account_number: str) -> str:
    return "*" * (len(account_number) - 2) + account_number[-2:]


def normalise(value) -> str:
    return re.sub(r"[^A-Z0-9]", "", str(value or "").upper())


DIGIT_LOOKALIKES = str.maketrans({"O": "0", "I": "1", "L": "1"})


def normalise_account(value) -> str:
    """Account numbers are two letters then digits. Speech-to-text often writes a spoken zero as the letter O."""
    text = normalise(value)
    return text[:2] + text[2:].translate(DIGIT_LOOKALIKES)


def normalise_postcode(value) -> str:
    """UK-style postcodes (ZZ5 4DJ): the third and the fourth-from-last characters are digits."""
    text = normalise(value)
    if len(text) >= 5:
        chars = list(text)
        for i in (2, len(chars) - 3):
            chars[i] = chars[i].translate(DIGIT_LOOKALIKES)
        text = "".join(chars)
    return text


def area_of(value) -> str:
    text = normalise(value)[:3]
    return text[:2] + text[2:].translate(DIGIT_LOOKALIKES)


def public_customer(customer: dict) -> dict:
    result = {k: v for k, v in customer.items() if k != "account_number"}
    result["account_number_masked"] = mask(customer["account_number"])
    return result


def find_customer(state, customer_id: str) -> dict:
    customer = next((c for c in state["customers"] if c["customer_id"] == customer_id), None)
    if not customer:
        raise ApiError(404, f"No customer with ID '{customer_id}'. Verify the caller first to get their customer_id.")
    return customer


def require(body: dict, *fields):
    missing = [f for f in fields if not str(body.get(f, "")).strip()]
    if missing:
        raise ApiError(400, f"Missing required field(s): {', '.join(missing)}.")


def first(query, name, default=""):
    return (query.get(name) or [default])[0]


# ---------------------------------------------------------------- operations

def op_company(st, query, body):
    pack = active_pack(st)
    p = profile(pack)
    result = {k: p[k] for k in ("company", "industry", "tagline", "products", "appointment_type")}
    result["pack"] = pack
    return result


def op_verify(st, query, body):
    require(body, "account_number", "postcode")
    pack = active_pack(st)
    number = normalise_account(body["account_number"])
    postcode = normalise_postcode(body["postcode"])

    def change(state):
        customer = next((c for c in state["customers"] if c["account_number"] == number), None)
        if not customer:
            outcome = "not verified: no account with that number"
        elif normalise_postcode(customer["postcode"]) != postcode:
            outcome = "not verified: postcode does not match"
        else:
            outcome = "verified"
        # Shown on the activity page so you can see what the agent heard. Account numbers stay masked.
        state.setdefault("verifications", []).append(
            {"at": now(), "account": mask(number) if number else "(empty)", "postcode": postcode, "outcome": outcome})
        state["verifications"] = state["verifications"][-20:]
        if outcome != "verified":
            return {"verified": False,
                    "message": "The account number and postcode do not match our records. Do not share any account information."}
        return {"verified": True, "customer_id": customer["customer_id"], "first_name": customer["name"].split()[0],
                "account_number_masked": mask(customer["account_number"])}

    return mutate(st, pack, change)


def op_customer(st, query, body, customer_id):
    state, _ = load_state(st, active_pack(st))
    customer = public_customer(find_customer(state, customer_id))
    customer["open_cases"] = [c for c in state["cases"] if c["customer_id"] == customer_id and c["status"] == "open"]
    customer["upcoming_appointments"] = [a for a in state["appointments"] if a["customer_id"] == customer_id]
    return customer


def op_notices(st, query, body):
    state, _ = load_state(st, active_pack(st))
    area = area_of(first(query, "area"))
    notices = state.get("service_notices", [])
    if area:
        notices = [n for n in notices if n["area"] in (area, "all")]
    return {"notices": notices}


def op_slots(st, query, body):
    pack = active_pack(st)
    state, _ = load_state(st, pack)
    area = area_of(first(query, "area"))
    try:
        limit = max(1, min(10, int(first(query, "limit", "3") or 3)))
    except ValueError:
        raise ApiError(400, "limit must be a number from 1 to 10.")
    booked = {a["slot_id"] for a in state["appointments"]}
    slots = [s for s in state["slots"] if s["slot_id"] not in booked and (not area or s["area"] == area)]
    return {"appointment_type": profile(pack)["appointment_type"], "slots": slots[:limit]}


def op_book(st, query, body):
    require(body, "customer_id", "slot_id")
    pack = active_pack(st)

    def change(state):
        find_customer(state, body["customer_id"])
        slot = next((s for s in state["slots"] if s["slot_id"] == body["slot_id"]), None)
        if not slot:
            raise ApiError(404, f"No slot '{body['slot_id']}'. List available slots first.")
        if any(a["slot_id"] == slot["slot_id"] for a in state["appointments"]):
            raise ApiError(409, "That slot has just been taken. Offer another slot.")
        appointment = {"appointment_id": next_id(state, profile(pack)["prefix"], "APT"),
                       "customer_id": body["customer_id"], "slot_id": slot["slot_id"], "type": slot["type"],
                       "start": slot["start"], "area": slot["area"], "notes": str(body.get("notes", ""))[:500],
                       "booked_at": now()}
        state["appointments"].append(appointment)
        return appointment

    return mutate(st, pack, change)


def op_open_case(st, query, body):
    require(body, "customer_id", "category", "summary")
    pack = active_pack(st)
    priority = str(body.get("priority", "normal")).lower()
    if priority not in ("normal", "high"):
        raise ApiError(400, "priority must be 'normal' or 'high'.")

    def change(state):
        find_customer(state, body["customer_id"])
        case = {"case_id": next_id(state, profile(pack)["prefix"], "CASE"), "customer_id": body["customer_id"],
                "category": str(body["category"])[:60], "summary": str(body["summary"])[:1500],
                "preferred_outcome": str(body.get("preferred_outcome", ""))[:500], "status": "open",
                "priority": priority, "opened": now(), "source": "virtual agent"}
        state["cases"].append(case)
        return case

    return mutate(st, pack, change)


def op_handoff(st, query, body):
    require(body, "reason", "summary")
    pack = active_pack(st)
    vulnerability = body.get("vulnerability") in (True, "true", "True", 1)
    priority = str(body.get("priority", "normal")).lower()
    if priority not in ("normal", "high"):
        raise ApiError(400, "priority must be 'normal' or 'high'.")

    def change(state):
        customer_id = str(body.get("customer_id") or "")
        if customer_id:
            find_customer(state, customer_id)
        waiting = sum(1 for h in state["handoffs"] if h["status"] == "waiting")
        handoff = {"handoff_id": next_id(state, profile(pack)["prefix"], "HO"), "customer_id": customer_id or None,
                   "reason": str(body["reason"])[:300], "summary": str(body["summary"])[:2000],
                   "sentiment": str(body.get("sentiment", ""))[:20], "vulnerability": vulnerability,
                   "priority": "high" if vulnerability else priority, "status": "waiting",
                   "queue_position": waiting + 1, "created": now()}
        state["handoffs"].append(handoff)
        result = dict(handoff)
        result["message"] = "A human adviser has the summary and will take over. The customer does not need to repeat anything."
        return result

    return mutate(st, pack, change)


def op_case(st, query, body, case_id):
    state, _ = load_state(st, active_pack(st))
    case = next((c for c in state["cases"] if c["case_id"] == case_id), None)
    if not case:
        raise ApiError(404, f"No case '{case_id}'.")
    return case


def op_cases(st, query, body):
    state, _ = load_state(st, active_pack(st))
    customer_id, status = first(query, "customer_id"), first(query, "status")
    cases = [c for c in state["cases"]
             if (not customer_id or c["customer_id"] == customer_id) and (not status or c["status"] == status)]
    return {"cases": cases[-20:]}


def op_handoffs(st, query, body):
    state, _ = load_state(st, active_pack(st))
    status = first(query, "status", "waiting")
    items = [h for h in state["handoffs"] if not status or h["status"] == status]
    enriched = []
    for handoff in items[-20:]:
        customer = next((public_customer(c) for c in state["customers"] if c["customer_id"] == handoff.get("customer_id")), None)
        enriched.append({**handoff, "customer": customer})
    return {"handoffs": enriched}


ROUTES = [
    ("GET", r"/company", op_company),
    ("POST", r"/verify-caller", op_verify),
    ("GET", r"/customers/(?P<customer_id>[\w-]+)", op_customer),
    ("GET", r"/service-notices", op_notices),
    ("GET", r"/appointment-slots", op_slots),
    ("POST", r"/appointments", op_book),
    ("POST", r"/cases", op_open_case),
    ("GET", r"/cases", op_cases),
    ("GET", r"/cases/(?P<case_id>[\w-]+)", op_case),
    ("POST", r"/handoffs", op_handoff),
    ("GET", r"/handoffs", op_handoffs),
]


# ---------------------------------------------------------------- OpenAPI

STRING = {"type": "string"}


def openapi(server: str) -> dict:
    def operation(op_id, summary, params=None, body=None, required=()):
        spec = {"operationId": op_id, "summary": summary, "description": summary,
                "responses": {"200": {"description": "OK",
                                      "content": {"application/json": {"schema": {"type": "object"}}}}}}
        if params:
            spec["parameters"] = params
        if body:
            spec["requestBody"] = {"required": True, "content": {"application/json": {
                "schema": {"type": "object", "properties": body, "required": list(required)}}}}
        return spec

    def query(name, desc):
        return {"name": name, "in": "query", "required": False, "description": desc, "schema": STRING}

    def path(name, desc):
        return {"name": name, "in": "path", "required": True, "description": desc, "schema": STRING}

    level = {"type": "string", "enum": ["normal", "high"]}
    return {
        "openapi": "3.0.3",
        "info": {"title": "Contact center CRM (fictional training data)", "version": "1.0.0",
                 "description": "Customer records, appointments, cases and handoffs for the selected company."},
        "servers": [{"url": server}],
        "paths": {
            "/company": {"get": operation("getCompany", "Get the company profile, products and appointment type.")},
            "/verify-caller": {"post": operation(
                "verifyCaller", "Check the caller's identity with their account number and postcode. Call this before sharing or changing anything on an account.",
                body={"account_number": {**STRING, "description": "Account number the caller gives"},
                      "postcode": {**STRING, "description": "Postcode the caller gives"}},
                required=("account_number", "postcode"))},
            "/customers/{customer_id}": {"get": operation(
                "getCustomer", "Get a verified customer's account summary, open cases and appointments.",
                params=[path("customer_id", "customer_id returned by verifyCaller")])},
            "/service-notices": {"get": operation(
                "getServiceNotices", "List known outages, delays or alerts, optionally for a postcode area such as ZZ4.",
                params=[query("area", "Postcode or postcode area, for example ZZ4")])},
            "/appointment-slots": {"get": operation(
                "listAppointmentSlots", "List the next available appointment slots, optionally for a postcode area.",
                params=[query("area", "Postcode or postcode area, for example ZZ4"), query("limit", "How many slots, 1 to 10")])},
            "/appointments": {"post": operation(
                "bookAppointment", "Book an appointment slot for a verified customer.",
                body={"customer_id": STRING, "slot_id": STRING, "notes": STRING}, required=("customer_id", "slot_id"))},
            "/cases": {
                "post": operation(
                    "openCase", "Open a case for a verified customer, for example a complaint, fault or payment arrangement.",
                    body={"customer_id": STRING, "category": STRING, "summary": STRING, "priority": level,
                          "preferred_outcome": STRING},
                    required=("customer_id", "category", "summary")),
                "get": operation("listCases", "List cases, optionally for one customer or status.",
                                 params=[query("customer_id", "Filter by customer"), query("status", "open or closed")]),
            },
            "/cases/{case_id}": {"get": operation("getCase", "Get one case.", params=[path("case_id", "Case ID")])},
            "/handoffs": {
                "post": operation(
                    "escalateToHuman", "Hand the customer to a human adviser with a summary, so they do not have to repeat themselves.",
                    body={"customer_id": {**STRING, "description": "Only if the caller was verified"}, "reason": STRING,
                          "summary": {**STRING, "description": "What happened so far and what the customer needs"},
                          "sentiment": {"type": "string", "enum": ["positive", "neutral", "negative"]},
                          "vulnerability": {"type": "boolean", "description": "True if the customer may be vulnerable"},
                          "priority": level},
                    required=("reason", "summary")),
                "get": operation("listHandoffs", "List handoffs waiting for a human adviser, with each customer's summary.",
                                 params=[query("status", "waiting (default)")]),
            },
        },
    }


# ---------------------------------------------------------------- HTTP

def status_page(st) -> str:
    try:
        pack = active_pack(st)
        state, _ = load_state(st, pack)
        rows = []
        for v in state.get("verifications", [])[-10:]:
            rows.append((v["at"], "identity check", v["account"], f"postcode {v['postcode']}: {v['outcome']}"))
        for h in state["handoffs"][-10:]:
            flag = " (vulnerable)" if h.get("vulnerability") else ""
            rows.append((h["created"], "handoff", h["handoff_id"], f"{h.get('priority', 'normal').upper()} priority{flag}: {h['reason']}"))
        for c in state["cases"]:
            if c.get("source") == "virtual agent":
                rows.append((c["opened"], "case", c["case_id"], f"{c['category']}: {c['summary'][:80]}"))
        for a in state["appointments"][-10:]:
            rows.append((a["booked_at"], "appointment", a["appointment_id"], f"{a['type']} {a['start']}"))
        rows.sort(reverse=True)
        table = "".join(f"<tr>{''.join(f'<td>{escape(str(v))}</td>' for v in row)}</tr>" for row in rows[:20])
        body = (f"<h1>{escape(profile(pack)['company'])} CRM</h1><p>Industry pack: <b>{escape(pack)}</b>. Fictional training data.</p>"
                "<h2>What your agents did</h2><table border=1 cellpadding=4><tr><th>When (UTC)</th><th>Type</th><th>ID</th><th>Detail</th></tr>"
                f"{table or '<tr><td colspan=4>Nothing yet</td></tr>'}</table>")
    except ApiError as err:
        body = f"<h1>Contact center CRM</h1><p>{escape(err.message)}</p>"
    return ("<!doctype html><html><head><meta charset=utf-8><title>CRM</title></head>"
            f"<body style='font-family:sans-serif'>{body}<p><a href='/openapi.json'>OpenAPI document</a></p></body></html>")


REASONS = {200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed", 409: "Conflict",
           500: "Internal Server Error"}


def app(environ, start_response):
    method = environ.get("REQUEST_METHOD", "GET")
    path = environ.get("PATH_INFO", "/") or "/"
    query = parse_qs(environ.get("QUERY_STRING", ""))
    host = environ.get("HTTP_X_FORWARDED_HOST") or environ.get("HTTP_HOST", "localhost")
    scheme = "http" if host.startswith(("localhost", "127.0.0.1")) else "https"

    def respond(status: int, payload, content_type="application/json"):
        text = payload if isinstance(payload, str) else json.dumps(payload, indent=1)
        start_response(f"{status} {REASONS[status]}", [("Content-Type", f"{content_type}; charset=utf-8")])
        return [text.encode("utf-8")]

    try:
        if path == "/health":
            return respond(200, {"status": "ok", "packs": available_packs()})
        if path == "/openapi.json":
            return respond(200, openapi(f"{scheme}://{host}"))
        st = store()
        if path == "/" and method == "GET":
            return respond(200, status_page(st), "text/html")
        body = {}
        if method == "POST":
            length = int(environ.get("CONTENT_LENGTH") or 0)
            raw = environ["wsgi.input"].read(length) if length else b""
            try:
                body = json.loads(raw or b"{}")
            except json.JSONDecodeError:
                raise ApiError(400, "Body must be JSON.")
            if not isinstance(body, dict):
                raise ApiError(400, "Body must be a JSON object.")
        matched_path = False
        for route_method, pattern, handler in ROUTES:
            match = re.fullmatch(pattern, path)
            if not match:
                continue
            matched_path = True
            if route_method == method:
                with _lock:
                    return respond(200, handler(st, query, body, **match.groupdict()))
        if matched_path:
            raise ApiError(405, f"{method} is not supported on {path}.")
        raise ApiError(404, f"No endpoint {path}. See /openapi.json.")
    except ApiError as err:
        return respond(err.status, {"error": err.message})
    except Exception as err:  # noqa: BLE001 - always answer the agent with JSON
        return respond(500, {"error": f"CRM error: {type(err).__name__}"})


if __name__ == "__main__":
    from wsgiref.simple_server import make_server
    print("CRM on http://localhost:8000")
    make_server("", 8000, app).serve_forever()
