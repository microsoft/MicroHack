import io
import json
import sys
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB / "crm"))
import app as crm  # noqa: E402

PACKS = ["telco", "energy", "bank", "insurance", "retail"]


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(crm, "PACKS", LAB / "data" / "packs")
    monkeypatch.delenv("STORAGE_ACCOUNT", raising=False)
    monkeypatch.setenv("CRM_STATE_DIR", str(tmp_path))

    def call(method, path, body=None, pack="telco"):
        if pack:
            (tmp_path / "active.json").write_text(json.dumps({"pack": pack}), encoding="utf-8")
        raw = json.dumps(body).encode() if body is not None else b""
        path, _, query = path.partition("?")
        environ = {"REQUEST_METHOD": method, "PATH_INFO": path, "QUERY_STRING": query, "HTTP_HOST": "localhost:8000",
                   "CONTENT_LENGTH": str(len(raw)), "wsgi.input": io.BytesIO(raw)}
        status = {}
        out = crm.app(environ, lambda s, h: status.setdefault("code", int(s.split()[0])))
        text = b"".join(out).decode()
        return status["code"], (json.loads(text) if text.startswith(("{", "[")) else text)
    return call


def customer(pack):
    data = json.loads((LAB / "data" / "packs" / pack / "crm.json").read_text(encoding="utf-8"))
    return data["customers"][0]


@pytest.mark.parametrize("pack", PACKS)
def test_verify_book_case_and_handoff_flow(client, pack):
    c = customer(pack)
    code, verified = client("POST", "/verify-caller", {"account_number": c["account_number"].lower(), "postcode": c["postcode"].replace(" ", "")}, pack)
    assert code == 200 and verified["verified"] and verified["customer_id"] == c["customer_id"]
    code, summary = client("GET", f"/customers/{c['customer_id']}", pack=pack)
    assert code == 200 and "account_number" not in summary and summary["account_number_masked"].endswith(c["account_number"][-2:])
    code, slots = client("GET", "/appointment-slots?limit=2", pack=pack)
    assert code == 200 and len(slots["slots"]) == 2
    code, booking = client("POST", "/appointments", {"customer_id": c["customer_id"], "slot_id": slots["slots"][0]["slot_id"]}, pack)
    assert code == 200 and booking["appointment_id"]
    code, again = client("POST", "/appointments", {"customer_id": c["customer_id"], "slot_id": slots["slots"][0]["slot_id"]}, pack)
    assert code == 409
    code, case = client("POST", "/cases", {"customer_id": c["customer_id"], "category": "complaint", "summary": "Test", "priority": "high"}, pack)
    assert code == 200 and case["status"] == "open" and case["priority"] == "high"
    code, handoff = client("POST", "/handoffs", {"customer_id": c["customer_id"], "reason": "Asked for a person", "summary": "Test", "vulnerability": True}, pack)
    assert code == 200 and handoff["priority"] == "high" and handoff["queue_position"] == 1
    code, queue = client("GET", "/handoffs", pack=pack)
    assert code == 200 and queue["handoffs"][0]["customer"]["customer_id"] == c["customer_id"]


def test_wrong_postcode_shares_nothing(client):
    c = customer("telco")
    code, result = client("POST", "/verify-caller", {"account_number": c["account_number"], "postcode": "ZZ9 9ZZ"})
    assert code == 200 and result["verified"] is False and "customer_id" not in result


def test_service_notices_filter_by_area(client):
    code, result = client("GET", "/service-notices?area=ZZ4 2BT")
    assert code == 200 and len(result["notices"]) == 1
    code, result = client("GET", "/service-notices?area=ZZ1")
    assert code == 200 and result["notices"] == []


@pytest.mark.parametrize("method,path,body,status", [
    ("POST", "/verify-caller", {"account_number": "KC100201"}, 400),
    ("GET", "/customers/NOPE", None, 404),
    ("POST", "/cases", {"customer_id": "KC-C01", "category": "x", "summary": "y", "priority": "urgent"}, 400),
    ("POST", "/appointments", {"customer_id": "KC-C01", "slot_id": "KC-S999"}, 404),
    ("DELETE", "/cases", None, 405),
    ("GET", "/nothing", None, 404),
    ("GET", "/appointment-slots?limit=many", None, 400),
])
def test_errors_are_clear_json(client, method, path, body, status):
    code, result = client(method, path, body)
    assert code == status and "error" in result


def test_no_pack_selected_explains_next_step(client, tmp_path):
    code, result = client("GET", "/company", pack=None)
    assert code == 409 and "Challenge 1" in result["error"]


def test_openapi_lists_every_route_with_operation_ids(client):
    code, spec = client("GET", "/openapi.json")
    assert code == 200 and spec["servers"][0]["url"] == "http://localhost:8000"
    ids = {op["operationId"] for path in spec["paths"].values() for op in path.values()}
    assert {"verifyCaller", "getCustomer", "bookAppointment", "openCase", "escalateToHuman", "listHandoffs"} <= ids
    assert len(ids) == len(crm.ROUTES)


def test_status_page_shows_agent_activity(client):
    client("POST", "/cases", {"customer_id": "KC-C01", "category": "fault", "summary": "Router red light"})
    client("POST", "/handoffs", {"reason": "Telecare alarm offline", "summary": "Needs a person", "vulnerability": True})
    code, page = client("GET", "/")
    assert code == 200 and "Kestrel Connect" in page and "Router red light" in page
    assert "HIGH priority (vulnerable): Telecare alarm offline" in page


def test_verify_accepts_what_speech_to_text_writes(client):
    for account, postcode in [("KC100210", "ZZ5 4DJ"), ("kc 100 210", "zz54dj"), ("KC1OO21O", "ZZ5 4DJ"),
                              ("K-C-1-0-0-2-1-0", "Z.Z.5 4.D.J.")]:
        code, body = client("POST", "/verify-caller", {"account_number": account, "postcode": postcode})
        assert code == 200 and body["verified"] and body["customer_id"] == "KC-C10", (account, postcode)


def test_failed_identity_checks_show_why_on_the_activity_page(client):
    client("POST", "/verify-caller", {"account_number": "KC100210", "postcode": "ZZ9 9ZZ"})
    client("POST", "/verify-caller", {"account_number": "KC999999", "postcode": "ZZ5 4DJ"})
    code, page = client("GET", "/")
    assert "postcode ZZ99ZZ: not verified: postcode does not match" in page
    assert "not verified: no account with that number" in page
    assert "KC100210" not in page and "******10" in page
