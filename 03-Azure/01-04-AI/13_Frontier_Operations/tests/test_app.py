import io
import json
import sys
from pathlib import Path
from urllib.parse import urlencode

import pytest

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB / "app"))
import app as backoffice  # noqa: E402

KEY = "test-key-123"


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(backoffice, "PACKS", LAB / "data" / "packs")
    monkeypatch.delenv("STORAGE_ACCOUNT", raising=False)
    monkeypatch.setenv("OPS_STATE_DIR", str(tmp_path))
    monkeypatch.setenv("ERP_API_KEY", KEY)

    def call(method, path, body=None, key=KEY, form=None, pack="distribution"):
        if pack:
            (tmp_path / "active.json").write_text(json.dumps({"pack": pack}), encoding="utf-8")
        if form is not None:
            raw, ctype = urlencode(form).encode(), "application/x-www-form-urlencoded"
        else:
            raw, ctype = (json.dumps(body).encode() if body is not None else b""), "application/json"
        path, _, query = path.partition("?")
        environ = {"REQUEST_METHOD": method, "PATH_INFO": path, "QUERY_STRING": query, "CONTENT_LENGTH": str(len(raw)),
                   "CONTENT_TYPE": ctype, "wsgi.input": io.BytesIO(raw), "HTTP_HOST": "ops.example", "wsgi.url_scheme": "https"}
        if key is not None:
            environ["HTTP_X_API_KEY"] = key
        result = {}
        data = b"".join(backoffice.app(environ, lambda status, headers: result.update(status=int(status.split()[0]),
                                                                                          type=dict(headers)["Content-Type"])))
        return result["status"], (json.loads(data) if "json" in result["type"] else data.decode())

    return call


def test_erp_requires_the_api_key(client):
    assert client("GET", "/erp/company", key=None)[0] == 401
    assert client("GET", "/erp/company", key="wrong")[0] == 401
    code, body = client("GET", "/erp/company")
    assert code == 200 and body["company"] == "Ashgrove Supply" and body["tolerance"] == 2.0


def test_openapi_document_declares_the_api_key_and_needs_no_key(client):
    code, spec = client("GET", "/openapi.json", key=None)
    assert code == 200
    assert spec["components"]["securitySchemes"]["apiKey"] == {"type": "apiKey", "in": "header", "name": "x-api-key"}
    assert spec["servers"] == [{"url": "https://ops.example"}]
    assert {"getCompany", "listPartners", "getLedger", "lookupReference", "addLedgerNote"} == {
        op["operationId"] for item in spec["paths"].values() for op in item.values()}


def test_ledger_by_partner_and_lookup_normalises_references(client):
    code, body = client("GET", "/erp/ledger?partner_id=northgate")
    assert code == 200 and len(body["lines"]) == 12 and {l["partner_id"] for l in body["lines"]} == {"northgate"}
    assert client("GET", "/erp/ledger?partner_id=nobody")[0] == 404
    for written in ["inv 41003", "IN-41003", "INV41003", "INV-041003"]:
        code, found = client("GET", f"/erp/lookup?reference={written.replace(' ', '%20')}")
        assert found["found"] and found["reference"] == "INV-41003", written


def test_every_pack_serves_its_own_company(client):
    for pack, company in [("telco", "Kestrel Connect"), ("energy", "Lumora Energy"), ("insurance", "Northmere Insurance"), ("retail", "Parcelpine")]:
        assert client("GET", "/erp/company", pack=pack)[1]["company"] == company


def test_no_pack_selected_returns_409(client):
    assert client("GET", "/erp/company", pack=None)[0] == 409


def test_portal_is_html_only_and_needs_no_key(client):
    code, html = client("GET", "/portal", key=None)
    assert code == 200 and "Supplier Hub" in html and "Nothing raised yet" in html
    code, html = client("GET", "/portal/new", key=None)
    assert '<form method="post" action="/portal/submit">' in html and "Brightwell Packaging" in html and "Price dispute" in html


def test_portal_case_needs_an_approver_and_shows_on_the_activity_page(client):
    form = {"partner": "northgate", "case_type": "Price dispute", "reference": "INV-41022", "amount": "11.00",
            "details": "Statement 1942.94 vs ledger 1931.94", "approved_by": ""}
    code, html = client("POST", "/portal/submit", form=form, key=None)
    assert "Missing information" in html and "approved_by" in html
    form["approved_by"] = "Dana Okoro"
    code, html = client("POST", "/portal/submit", form=form, key=None)
    assert code == 200 and 'id="case-id"' in html and "Northgate Freight" in html
    code, html = client("GET", "/portal", key=None)
    assert "INV-41022" in html and "Submitted" in html
    code, page = client("GET", "/", key=None)
    assert "query raised" in page and "approved by Dana Okoro" in page


def test_notes_do_not_use_up_query_numbers(client):
    for _ in range(3):
        assert client("POST", "/erp/notes", {"reference": "INV-41007", "note": "checked"})[0] == 200
    form = {"partner": "brightwell", "case_type": "Price dispute", "reference": "INV-41007", "amount": "12.50",
            "details": "x", "approved_by": "Dana Okoro"}
    code, html = client("POST", "/portal/submit", form=form, key=None)
    assert 'id="case-id">INQ-101<' in html


def test_ledger_note_via_api(client):
    code, note = client("POST", "/erp/notes", {"reference": "INV-41022", "note": "Price dispute raised"})
    assert code == 200 and note["note_id"].startswith("NOTE-")
    assert client("POST", "/erp/notes", {"reference": "INV-41022"})[0] == 400
    code, page = client("GET", "/", key=None)
    assert "ledger note" in page


def test_health_lists_all_packs(client):
    code, body = client("GET", "/health", key=None)
    assert body == {"status": "ok", "packs": ["distribution", "energy", "insurance", "retail", "telco"]}
