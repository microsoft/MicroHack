"""Back-office systems for the Frontier Operations MicroHack. Standard library only (WSGI).

Two systems in one app, for the active industry pack:

  /erp/...      The company's ERP: a JSON API protected by an API key (header x-api-key).
                Agents reach it through an OpenAPI tool whose key lives in a Foundry connection.
  /portal/...   The partner portal: plain HTML pages and forms with no API, the kind of system
                agents reach through browser automation.
  /             Activity page: what agents and people did today.

State lives in Blob Storage (container "ops-state") through the app's managed identity:
  active.json   {"pack": "distribution"}   written by the setup tool
  <pack>.json   cases raised in the portal, approvals, activity
Without STORAGE_ACCOUNT the state is kept in a local folder (OPS_STATE_DIR), which the tests use.
"""
from __future__ import annotations

import csv
import hmac
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
CONTAINER = "ops-state"
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
        if self.read(name)[1] != etag:
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
        return urllib.request.urlopen(urllib.request.Request(f"{self.base}/{name}", data=data, method=method, headers=all_headers), timeout=30)

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
        headers["If-Match" if etag else "If-None-Match"] = etag or "*"
        try:
            self._request("PUT", name, json.dumps(value, indent=1).encode(), headers).close()
        except urllib.error.HTTPError as err:
            if err.code in (409, 412):
                raise ApiError(409, "State changed during the request. Try again.") from err
            raise


def store():
    account = os.environ.get("STORAGE_ACCOUNT")
    return BlobStore(account) if account else LocalStore(Path(os.environ.get("OPS_STATE_DIR", HERE / ".state")))


# ---------------------------------------------------------------- pack data

def available_packs() -> list:
    return sorted(p.name for p in PACKS.iterdir() if (p / "pack.json").is_file()) if PACKS.is_dir() else []


def active_pack(st) -> str:
    value, _ = st.read("active.json")
    pack = (value or {}).get("pack") or os.environ.get("DEFAULT_PACK", "")
    if pack not in available_packs():
        # 409, not 503: the Functions front end replaces 503 responses with an empty error.
        raise ApiError(409, "No industry pack is selected yet. Run the setup command from Challenge 1.")
    return pack


def profile(pack: str) -> dict:
    return json.loads((PACKS / pack / "pack.json").read_text(encoding="utf-8"))


def ledger(pack: str) -> list:
    with (PACKS / pack / "ledger.csv").open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        row["amount"] = float(row["amount"])
    return rows


def load_state(st, pack: str):
    value, etag = st.read(f"{pack}.json")
    return (value or {"cases": [], "activity": [], "counter": 100}), etag


def mutate(st, pack: str, change):
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
    raise ApiError(409, "The system is busy. Try again.")


def plural(noun: str) -> str:
    return noun[:-1] + "ies" if noun.endswith("y") else noun + "s"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(state, who: str, what: str, detail: str) -> None:
    state["activity"].append({"at": now(), "who": who, "what": what, "detail": detail[:240]})
    state["activity"] = state["activity"][-60:]


def normalise_ref(value: str, prefix: str) -> str:
    text = re.sub(r"[^A-Z0-9]", "", str(value or "").upper())
    match = re.match(r"^([A-Z]+)0*(\d+)$", text)
    if not match:
        return text
    letters, number = match.groups()
    if prefix.startswith(letters) or letters.startswith(prefix[:2]):
        letters = prefix
    return f"{letters}-{number}"


# ---------------------------------------------------------------- ERP API (x-api-key)

def require_key(environ) -> None:
    expected = os.environ.get("ERP_API_KEY", "")
    given = environ.get("HTTP_X_API_KEY", "")
    if not expected or not hmac.compare_digest(given, expected):
        raise ApiError(401, "Missing or wrong API key. Send it in the x-api-key header.")


def erp_company(st, query, body):
    p = profile(active_pack(st))
    return {k: p[k] for k in ("company", "industry", "process", "partner_type", "currency", "tolerance", "period")}


def erp_partners(st, query, body):
    p = profile(active_pack(st))
    return {"partners": p["partners"]}


def erp_ledger(st, query, body):
    pack = active_pack(st)
    partner = (query.get("partner_id") or [""])[0]
    rows = [r for r in ledger(pack) if not partner or r["partner_id"] == partner]
    if partner and not rows:
        raise ApiError(404, f"No partner '{partner}'. Call listPartners for valid IDs.")
    return {"currency": profile(pack)["currency"], "lines": rows}


def erp_lookup(st, query, body):
    pack = active_pack(st)
    p = profile(pack)
    ref = normalise_ref((query.get("reference") or [""])[0], p["ref_prefix"])
    match = next((r for r in ledger(pack) if r["reference"] == ref), None)
    if not match:
        return {"found": False, "reference": ref}
    return {"found": True, **match}


def erp_note(st, query, body):
    pack = active_pack(st)
    for field in ("reference", "note"):
        if not str(body.get(field, "")).strip():
            raise ApiError(400, f"Missing required field: {field}.")

    def change(state):
        state["note_counter"] = state.get("note_counter", 0) + 1
        note = {"note_id": f"NOTE-{state['note_counter']}", "reference": str(body["reference"])[:40],
                "note": str(body["note"])[:500], "created": now()}
        state.setdefault("notes", []).append(note)
        log(state, "agent (ERP API)", "ledger note", f"{note['reference']}: {note['note']}")
        return note

    return mutate(st, pack, change)


ERP_ROUTES = [
    ("GET", r"/erp/company", erp_company),
    ("GET", r"/erp/partners", erp_partners),
    ("GET", r"/erp/ledger", erp_ledger),
    ("GET", r"/erp/lookup", erp_lookup),
    ("POST", r"/erp/notes", erp_note),
]


def openapi(base_url: str, p: dict | None) -> dict:
    company = p["company"] if p else "the company"
    string = {"type": "string"}

    def op(op_id, summary, params=None, body=None):
        operation = {"operationId": op_id, "summary": summary, "responses": {"200": {"description": "OK"}}}
        if params:
            operation["parameters"] = params
        if body:
            operation["requestBody"] = {"required": True, "content": {"application/json": {"schema": {
                "type": "object", "required": list(body), "properties": body}}}}
        return operation

    def q(name, desc, required=False):
        return {"name": name, "in": "query", "required": required, "description": desc, "schema": string}

    return {
        "openapi": "3.0.1",
        "info": {"title": f"{company} ERP", "version": "1.0",
                 "description": f"System of record for {company}: partners and the ledger lines we have booked."},
        "servers": [{"url": base_url}],
        "components": {"securitySchemes": {"apiKey": {"type": "apiKey", "in": "header", "name": "x-api-key"}}},
        "security": [{"apiKey": []}],
        "paths": {
            "/erp/company": {"get": op("getCompany", "Company profile, currency, tolerance and the period being closed.")},
            "/erp/partners": {"get": op("listPartners", "List the partners (suppliers, carriers, brokers...) with their IDs.")},
            "/erp/ledger": {"get": op("getLedger", "Ledger lines we have booked, optionally for one partner.",
                                      [q("partner_id", "Partner ID from listPartners")])},
            "/erp/lookup": {"get": op("lookupReference", "Find one ledger line by reference. References are normalised (case, spaces, prefixes).",
                                      [q("reference", "The reference as written on a statement", True)])},
            "/erp/notes": {"post": op("addLedgerNote", "Attach a note to a ledger line, for example the reconciliation outcome.",
                                      body={"reference": string, "note": string})},
        },
    }


# ---------------------------------------------------------------- partner portal (HTML only)

PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{title}</title>
<style>body{{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f8;color:#1f2933}}
header{{background:#334e68;color:#fff;padding:14px 24px}}header b{{font-size:20px}}main{{padding:20px 24px;max-width:980px}}
table{{border-collapse:collapse;background:#fff;width:100%}}td,th{{border:1px solid #cbd2d9;padding:6px 8px;text-align:left;font-size:14px}}
th{{background:#e4e7eb}}label{{display:block;margin:12px 0 4px;font-weight:600}}input,select,textarea{{width:100%;max-width:520px;padding:6px;font-size:14px}}
button{{margin-top:14px;padding:8px 18px;background:#2680c2;color:#fff;border:0;font-size:15px}}.note{{color:#52606d;font-size:13px}}
.ok{{background:#e3f9e5;padding:10px;border:1px solid #57ae5b}}</style></head>
<body><header><b>{portal}</b> &nbsp; {tagline}</header><main>{body}</main></body></html>"""


def page(p, title, body):
    return PAGE.format(title=escape(title), portal=escape(p["portal"]["name"]), tagline=escape(p["portal"]["tagline"]), body=body)


def portal_home(st, p, pack, form):
    state, _ = load_state(st, pack)
    rows = "".join(
        f"<tr><td>{escape(c['case_id'])}</td><td>{escape(c['partner'])}</td><td>{escape(c['case_type'])}</td>"
        f"<td>{escape(c['reference'])}</td><td>{escape(c['amount'])}</td><td>{escape(c['status'])}</td></tr>"
        for c in reversed(state["cases"][-25:]))
    noun = p["portal"]["case_noun"]
    return page(p, p["portal"]["name"], f"""
<h1>{escape(p['company'])}: open {escape(plural(noun))}</h1>
<p><a href="/portal/new">Raise a new {escape(noun)}</a></p>
<table><tr><th>ID</th><th>{escape(p['partner_type'].capitalize())}</th><th>Type</th><th>Reference</th><th>Amount ({escape(p['currency'])})</th><th>Status</th></tr>
{rows or '<tr><td colspan=6>Nothing raised yet.</td></tr>'}</table>""")


def portal_new(st, p, pack, form):
    partners = "".join(f"<option value=\"{escape(x['id'])}\">{escape(x['name'])}</option>" for x in p["partners"])
    types = "".join(f"<option>{escape(t)}</option>" for t in p["portal"]["case_types"])
    noun = p["portal"]["case_noun"]
    return page(p, f"New {noun}", f"""
<h1>Raise a new {escape(noun)}</h1>
<form method="post" action="/portal/submit">
<label for="partner">{escape(p['partner_type'].capitalize())}</label><select id="partner" name="partner">{partners}</select>
<label for="case_type">Type of {escape(noun)}</label><select id="case_type" name="case_type">{types}</select>
<label for="reference">Reference</label><input id="reference" name="reference" placeholder="for example {escape(p['ref_prefix'])}-12345">
<label for="amount">Amount in dispute ({escape(p['currency'])})</label><input id="amount" name="amount" placeholder="0.00">
<label for="details">Details</label><textarea id="details" name="details" rows="4"></textarea>
<label for="approved_by">Approved by</label><input id="approved_by" name="approved_by" placeholder="Name of the person who approved this {escape(noun)}">
<p class="note">Every {escape(noun)} must be approved by a named person before it is submitted.</p>
<button type="submit">Submit {escape(noun)}</button></form>""")


def portal_submit(st, p, pack, form):
    def field(name):
        return (form.get(name) or [""])[0].strip()

    missing = [n for n in ("partner", "case_type", "reference", "details", "approved_by") if not field(n)]
    if missing:
        return page(p, "Missing information", f"<h1>Missing information</h1><p>Please fill in: {escape(', '.join(missing))}.</p>"
                                              "<p><a href=\"/portal/new\">Back</a></p>")
    partner = next((x for x in p["partners"] if x["id"] == field("partner")), None)
    if not partner:
        return page(p, "Unknown partner", "<h1>Unknown partner</h1><p><a href=\"/portal/new\">Back</a></p>")

    def change(state):
        state["counter"] += 1
        case = {"case_id": f"{p['ref_prefix'][:2]}Q-{state['counter']}", "partner": partner["name"], "partner_id": partner["id"],
                "case_type": field("case_type")[:60], "reference": field("reference")[:40], "amount": field("amount")[:20],
                "details": field("details")[:600], "approved_by": field("approved_by")[:80], "status": "Submitted", "created": now()}
        state["cases"].append(case)
        log(state, "portal", f"{p['portal']['case_noun']} raised", f"{case['case_id']} {case['partner']} {case['reference']}: {case['case_type']} (approved by {case['approved_by']})")
        return case

    case = mutate(st, pack, change)
    noun = p["portal"]["case_noun"]
    return page(p, f"{noun.capitalize()} submitted", f"""
<div class="ok"><h1>{escape(noun.capitalize())} submitted</h1>
<p>Reference number: <b id="case-id">{escape(case['case_id'])}</b></p>
<p>{escape(case['partner'])} will reply within 5 working days.</p></div>
<p><a href="/portal">Back to {escape(plural(noun))}</a></p>""")


PORTAL_ROUTES = {"/portal": portal_home, "/portal/new": portal_new, "/portal/submit": portal_submit}


# ---------------------------------------------------------------- WSGI

REASONS = {200: "OK", 400: "Bad Request", 401: "Unauthorized", 404: "Not Found", 405: "Method Not Allowed",
           409: "Conflict", 500: "Internal Server Error"}


def status_page(st) -> str:
    try:
        pack = active_pack(st)
        p = profile(pack)
        state, _ = load_state(st, pack)
        rows = "".join(f"<tr><td>{escape(a['at'])}</td><td>{escape(a['who'])}</td><td>{escape(a['what'])}</td><td>{escape(a['detail'])}</td></tr>"
                       for a in reversed(state["activity"][-30:]))
        body = (f"<h1>{escape(p['company'])}: back office</h1><p>Industry pack: <b>{escape(pack)}</b>. Fictional training data.</p>"
                f"<p><a href=\"/portal\">{escape(p['portal']['name'])}</a> &middot; <a href=\"/openapi.json\">ERP OpenAPI document</a></p>"
                "<h2>What happened today</h2><table border=1 cellpadding=4><tr><th>When (UTC)</th><th>Who</th><th>What</th><th>Detail</th></tr>"
                f"{rows or '<tr><td colspan=4>Nothing yet</td></tr>'}</table>")
    except ApiError as err:
        body = f"<h1>Back office</h1><p>{escape(err.message)}</p>"
    return f"<!doctype html><html><head><meta charset=utf-8><title>Back office</title></head><body style=\"font-family:Segoe UI,Arial\">{body}</body></html>"


def app(environ, start_response):
    method = environ.get("REQUEST_METHOD", "GET")
    path = environ.get("PATH_INFO", "/").rstrip("/") or "/"
    query = parse_qs(environ.get("QUERY_STRING", ""))
    st = store()
    try:
        if path == "/health":
            return _json(start_response, 200, {"status": "ok", "packs": available_packs()})
        if path == "/openapi.json":
            try:
                p = profile(active_pack(st))
            except ApiError:
                p = None
            scheme = environ.get("HTTP_X_FORWARDED_PROTO", environ.get("wsgi.url_scheme", "https"))
            host = environ.get("HTTP_X_FORWARDED_HOST") or environ.get("HTTP_HOST", "localhost")
            return _json(start_response, 200, openapi(f"{scheme}://{host}", p))
        if path == "/":
            return _html(start_response, 200, status_page(st))
        if path.startswith("/portal"):
            handler = PORTAL_ROUTES.get(path)
            if not handler:
                raise ApiError(404, "Page not found.")
            if path == "/portal/submit" and method != "POST":
                raise ApiError(405, "Use the form to submit.")
            pack = active_pack(st)
            form = parse_qs(_body(environ).decode("utf-8")) if method == "POST" else {}
            with _lock:
                return _html(start_response, 200, handler(st, profile(pack), pack, form))
        for verb, pattern, handler in ERP_ROUTES:
            if re.fullmatch(pattern, path):
                if method != verb:
                    raise ApiError(405, f"Use {verb} for {path}.")
                require_key(environ)
                body = json.loads(_body(environ) or b"{}") if method == "POST" else {}
                with _lock:
                    return _json(start_response, 200, handler(st, query, body))
        raise ApiError(404, f"No route for {method} {path}.")
    except ApiError as err:
        if path.startswith("/portal"):
            return _html(start_response, err.status, f"<h1>{escape(err.message)}</h1>")
        return _json(start_response, err.status, {"error": err.message})
    except json.JSONDecodeError:
        return _json(start_response, 400, {"error": "Request body must be JSON."})


def _body(environ) -> bytes:
    length = int(environ.get("CONTENT_LENGTH") or 0)
    return environ["wsgi.input"].read(length) if length else b""


def _json(start_response, status, payload):
    data = json.dumps(payload, indent=1, ensure_ascii=False).encode()
    start_response(f"{status} {REASONS.get(status, 'OK')}", [("Content-Type", "application/json; charset=utf-8"), ("Content-Length", str(len(data)))])
    return [data]


def _html(start_response, status, text):
    data = text.encode()
    start_response(f"{status} {REASONS.get(status, 'OK')}", [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(data)))])
    return [data]
