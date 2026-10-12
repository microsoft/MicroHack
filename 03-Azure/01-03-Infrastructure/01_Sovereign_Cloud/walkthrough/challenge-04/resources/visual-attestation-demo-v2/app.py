"""
SEV-SNP runtime attestation web UI for ACI Confidential Containers.

This app skips the SKR sidecar and talks to MAA itself:

  1. `get-snp-report` (from microsoft/confidential-sidecar-containers, baked
     into the image) opens /dev/sev-guest and asks the AMD Secure Processor
     for a fresh 1184-byte attestation report bound to a caller-supplied
     REPORT_DATA (sha256 of a per-request runtime data blob).
  2. The app reads the THIM cert chain and UVM reference info that the ACI
     control plane drops into UVM_SECURITY_CONTEXT_DIR (or the equivalent
     environment variables).
  3. The app POSTs report + cert chain + endorsements + runtime data to MAA's
     /attest/SevSnpVm endpoint, which validates the hardware evidence,
     measures the runtime data into REPORT_DATA, and returns a signed JWT.
  4. The app decodes the JWT and renders every claim with a human-readable
     explanation.

  - ACI Confidential SKU -> /dev/sev-guest + UVM context, MAA returns sevsnpvm
  - ACI Standard SKU     -> no /dev/sev-guest, get-snp-report fails by design

References:
  https://github.com/microsoft/confidential-sidecar-containers/tree/main/tools/get-snp-report
  https://learn.microsoft.com/rest/api/attestation/attestation/attest-sev-snp-vm
  AMD SEV-SNP ABI specification (publication 56860)
"""

import base64
import hashlib
import json
import os
import secrets
import struct
import subprocess
import traceback
from datetime import datetime, timezone
from pathlib import Path

import requests
from flask import Flask, jsonify, render_template, request


GET_SNP_REPORT = os.environ.get("GET_SNP_REPORT", "/usr/local/bin/get-snp-report")
DEFAULT_MAA = os.environ.get("MAA_ENDPOINT", "sharedeus.eus.attest.azure.net")
MAA_API_VERSION = os.environ.get("MAA_API_VERSION", "2022-08-01")


# ---------------------------------------------------------------------------
# Claim explanations for MAA SEV-SNP tokens.
# ---------------------------------------------------------------------------
CLAIM_EXPLANATIONS = {
    "iss": "Issuer - the MAA endpoint that signed this token. Verifying the issuer URL pins the token to a specific Azure Attestation provider.",
    "iat": "Issued At (Unix epoch seconds) - when MAA produced the token.",
    "exp": "Expiration (Unix epoch seconds) - after this point the token must not be trusted.",
    "nbf": "Not Before (Unix epoch seconds) - the token is not valid earlier than this time.",
    "jti": "JWT ID - a unique identifier MAA assigns to this token; useful for replay detection.",

    "x-ms-ver": "MAA token schema version.",
    "x-ms-attestation-type": "Type of TEE that produced the evidence ('sevsnpvm', 'tdxvm', 'azurevm', 'tpm', etc.).",
    "x-ms-compliance-status": "MAA's overall verdict against its policy. 'azure-compliant-uvm' means the platform passed all Azure CC UVM policy checks.",
    "x-ms-policy-hash": "SHA-256 of the MAA policy (base64url) that evaluated this evidence. Pin this in your relying party to detect policy drift.",
    "x-ms-policy-signer": "If a custom JWS-signed MAA policy was used, this is the signer's certificate chain.",
    "x-ms-runtime": "Caller-supplied runtime data that was bound into the hardware report's REPORT_DATA field.",
    "x-ms-inittime": "Init-time data bound into the report (the CCE policy hash on ACI CC).",
    "nonce": "Caller-supplied nonce echoed back inside x-ms-runtime to prove freshness.",

    "x-ms-sevsnpvm-authorkeydigest": "SHA-384 of the SEV-SNP author key (AKD). Zero on Azure-managed CVMs unless you bring your own ID/Author key.",
    "x-ms-sevsnpvm-bootloader-svn": "SVN of the AMD SEV-SNP guest bootloader at launch.",
    "x-ms-sevsnpvm-familyId": "Family ID supplied at SNP_LAUNCH_FINISH (16 bytes). On Azure CVMs this identifies the Azure VM family.",
    "x-ms-sevsnpvm-guestsvn": "Guest Security Version Number stamped into the report. Allows monotonic anti-rollback in your policy.",
    "x-ms-sevsnpvm-hostdata": "Host data the hypervisor injected at launch (sha256 of the CCE policy on ACI CC). Lets you bind the guest to a specific host configuration.",
    "x-ms-sevsnpvm-idkeydigest": "SHA-384 of the SEV-SNP ID Key (IDK). On Azure CC nodes this is the Azure-managed launch ID key digest.",
    "x-ms-sevsnpvm-imageId": "Image ID supplied at SNP_LAUNCH_FINISH (16 bytes).",
    "x-ms-sevsnpvm-is-debuggable": "true means the guest was launched with the SNP debug policy bit set. For production CVMs this MUST be false.",
    "x-ms-sevsnpvm-launchmeasurement": "SHA-384 of the initial guest memory contents measured by AMD-SP at launch. This is the cryptographic identity of the boot image.",
    "x-ms-sevsnpvm-microcode-svn": "Microcode SVN of the AMD CPU at attestation time.",
    "x-ms-sevsnpvm-migration-allowed": "true if the SNP guest policy permits migration between machines. Azure CVMs report false.",
    "x-ms-sevsnpvm-reportdata": "Hex of REPORT_DATA - 64 bytes the guest itself supplied when requesting the report. MAA stuffs the SHA-256 of x-ms-runtime here so you can cryptographically link the token to caller-supplied data.",
    "x-ms-sevsnpvm-reportid": "Per-launch report ID assigned by AMD-SP. Different across reboots.",
    "x-ms-sevsnpvm-smt-allowed": "true means simultaneous multithreading was allowed at launch (per SNP guest policy).",
    "x-ms-sevsnpvm-snpfw-svn": "SVN of the AMD SEV-SNP firmware (PSP) at attestation time.",
    "x-ms-sevsnpvm-tee-svn": "SVN of the TEE component (always 0 for SEV-SNP today; reserved).",
    "x-ms-sevsnpvm-vmpl": "Virtual Machine Privilege Level the report was generated at. Azure CVMs run the OS at VMPL0.",
}


def _explain(key: str) -> str:
    if key in CLAIM_EXPLANATIONS:
        return CLAIM_EXPLANATIONS[key]
    if key.startswith("x-ms-sevsnpvm-"):
        return "SEV-SNP attestation report field surfaced by MAA. See AMD SEV-SNP ABI spec for the underlying bit layout."
    if key.startswith("x-ms-"):
        return "MAA-issued claim. Refer to the Microsoft Azure Attestation claim-set documentation."
    return "Standard JWT or caller-supplied claim."


# ---------------------------------------------------------------------------
# JWT helpers (display only).
# ---------------------------------------------------------------------------
def _b64url_decode(segment: str) -> bytes:
    pad = "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(segment + pad)


def decode_jwt(token: str):
    if isinstance(token, bytes):
        token = token.decode("utf-8")
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError(f"Token does not have 3 segments (got {len(parts)})")
    return json.loads(_b64url_decode(parts[0])), json.loads(_b64url_decode(parts[1]))


def _format_timestamp(value):
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc).isoformat()
    except Exception:
        return None


def annotate_claims(payload: dict):
    rows = []
    for key, value in payload.items():
        row = {"key": key, "value": value, "explanation": _explain(key)}
        if key in {"iat", "exp", "nbf"}:
            row["timestamp"] = _format_timestamp(value)
        rows.append(row)
    rows.sort(key=lambda r: (not r["key"].startswith("x-ms-"), r["key"]))
    return rows


# ---------------------------------------------------------------------------
# UVM information - THIM certs and reference info supplied by the ACI control
# plane. Same lookup order as the SKR sidecar:
#   1. UVM_SECURITY_CONTEXT_DIR (or auto-discovered /security-context-*)
#   2. UVM_HOST_AMD_CERTIFICATE / UVM_REFERENCE_INFO env vars (legacy).
# ---------------------------------------------------------------------------
def _find_security_context_dir() -> str | None:
    explicit = os.environ.get("UVM_SECURITY_CONTEXT_DIR")
    if explicit and os.path.isdir(explicit):
        return explicit
    try:
        for entry in os.listdir("/"):
            if entry.startswith("security-context-"):
                full = os.path.join("/", entry)
                if os.path.isdir(full):
                    return full
    except OSError:
        pass
    return None


def load_uvm_information() -> dict:
    """Returns dict with keys: host_amd_cert_b64, reference_info_b64, source."""
    ctx_dir = _find_security_context_dir()
    if ctx_dir:
        def _read(name):
            p = Path(ctx_dir) / name
            return p.read_text().strip() if p.exists() else ""
        return {
            "host_amd_cert_b64": _read("host-amd-cert-base64"),
            "reference_info_b64": _read("reference-info-base64"),
            "source": ctx_dir,
        }
    return {
        "host_amd_cert_b64": os.environ.get("UVM_HOST_AMD_CERTIFICATE", ""),
        "reference_info_b64": os.environ.get("UVM_REFERENCE_INFO", ""),
        "source": "env",
    }


def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode("ascii")


def _build_maa_report(snp_report: bytes, vcek_cert_chain: bytes, endorsements_json: bytes | None) -> str:
    """Pack hardware report + cert chain + endorsements into MAA's `report` blob."""
    inner = {
        "SnpReport": _b64url(snp_report),
        "VcekCertChain": _b64url(vcek_cert_chain),
    }
    if endorsements_json:
        inner["Endorsements"] = _b64url(endorsements_json)
    return _b64url(json.dumps(inner, separators=(",", ":")).encode("utf-8"))


# ---------------------------------------------------------------------------
# get-snp-report invocation.
# ---------------------------------------------------------------------------
REPORT_LEN = 0x4A0  # 1184 bytes


def fetch_snp_report(report_data: bytes) -> bytes:
    if not (os.path.exists("/dev/sev-guest") or os.path.exists("/dev/sev")):
        raise RuntimeError(
            "Neither /dev/sev-guest nor /dev/sev is present in this container. "
            "On ACI Standard SKU there is no AMD SEV-SNP hardware - this is the "
            "expected failure mode for the demo."
        )
    proc = subprocess.run(
        [GET_SNP_REPORT, report_data.hex()],
        capture_output=True,
        timeout=15,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"get-snp-report exited {proc.returncode}. "
            f"stdout: {proc.stdout.decode('utf-8', 'replace')[:500]} "
            f"stderr: {proc.stderr.decode('utf-8', 'replace')[:500]}"
        )
    hex_output = "".join(c for c in proc.stdout.decode("ascii", "replace") if c in "0123456789abcdefABCDEF")
    report = bytes.fromhex(hex_output)
    if len(report) < REPORT_LEN:
        raise RuntimeError(f"SNP report too short: {len(report)} bytes")
    return report[:REPORT_LEN]


def parse_snp_report_summary(buf: bytes) -> dict:
    """Just enough fields for a side-panel summary; MAA does the real validation."""
    version = struct.unpack_from("<I", buf, 0x000)[0]
    guest_svn = struct.unpack_from("<I", buf, 0x004)[0]
    vmpl = struct.unpack_from("<I", buf, 0x030)[0]
    measurement = buf[0x090:0x0C0].hex()
    host_data = buf[0x0C0:0x0E0].hex()
    report_data = buf[0x050:0x090].hex()
    chip_id = buf[0x1A0:0x1E0].hex()
    return {
        "version": version,
        "guest_svn": guest_svn,
        "vmpl": vmpl,
        "measurement": measurement,
        "host_data": host_data,
        "report_data": report_data,
        "chip_id": chip_id,
    }


# ---------------------------------------------------------------------------
# Top-level attestation flow.
# ---------------------------------------------------------------------------
def perform_attestation(user_nonce: str | None) -> dict:
    nonce = user_nonce or secrets.token_hex(16)

    # Runtime data: arbitrary JSON the caller wants bound into REPORT_DATA.
    runtime_obj = {"nonce": nonce, "client": "visual-attestation-demo-v2"}
    runtime_bytes = json.dumps(runtime_obj, separators=(",", ":")).encode("utf-8")

    # MAA hashes runtime data into REPORT_DATA, but only after we hand it the
    # report. So we must fetch the report with REPORT_DATA = sha256(runtime).
    report_data = hashlib.sha256(runtime_bytes).digest() + b"\x00" * 32

    snp_report = fetch_snp_report(report_data)
    summary = parse_snp_report_summary(snp_report)

    # Load THIM cert chain + UVM endorsements from the security context dir.
    uvm = load_uvm_information()
    if not uvm["host_amd_cert_b64"]:
        raise RuntimeError(
            "UVM host AMD certificate not found. Expected security-context-*/host-amd-cert-base64 "
            "or UVM_HOST_AMD_CERTIFICATE env var. ACI control plane usually injects this on Confidential SKU."
        )
    thim_certs_raw = base64.b64decode(uvm["host_amd_cert_b64"])
    thim_certs = json.loads(thim_certs_raw)
    vcek_chain = (thim_certs.get("vcekCert", "") + thim_certs.get("certificateChain", "")).encode("utf-8")

    endorsements_json: bytes | None = None
    if uvm["reference_info_b64"]:
        ref_info = base64.b64decode(uvm["reference_info_b64"])
        endorsements_json = json.dumps(
            {"Uvm": [_b64url(ref_info)]}, separators=(",", ":")
        ).encode("utf-8")

    body = {
        "report": _build_maa_report(snp_report, vcek_chain, endorsements_json),
        "runtimeData": {"data": _b64url(runtime_bytes), "dataType": "JSON"},
        "nonce": secrets.randbits(63),
    }

    url = f"https://{DEFAULT_MAA}/attest/SevSnpVm?api-version={MAA_API_VERSION}"
    resp = requests.post(url, json=body, timeout=30, headers={"User-Agent": "visual-attestation-demo-v2"})
    if resp.status_code != 200:
        raise RuntimeError(f"MAA POST {url} returned HTTP {resp.status_code}: {resp.text[:600]}")
    token = resp.json().get("token")
    if not token:
        raise RuntimeError(f"MAA response missing 'token': {resp.text[:600]}")

    header, payload = decode_jwt(token)

    return {
        "endpoint": f"https://{DEFAULT_MAA}",
        "region": DEFAULT_MAA.split(".")[0],
        "isolation_type": "SEV_SNP",
        "nonce": nonce,
        "token": token,
        "header": header,
        "payload": payload,
        "claims": annotate_claims(payload),
        "hardware_evidence": {
            "maa_endpoint": DEFAULT_MAA,
            "uvm_source": uvm["source"],
            "snp_report_size": len(snp_report),
            "snp_report_hex": snp_report.hex(),
            "snp_summary": summary,
            "runtime_data": runtime_obj,
            "runtime_data_sha256": hashlib.sha256(runtime_bytes).hexdigest(),
        },
    }


# ---------------------------------------------------------------------------
# Flask app
# ---------------------------------------------------------------------------
app = Flask(__name__)


@app.route("/", methods=["GET"])
def index():
    is_confidential = os.environ.get("ACI_SKU", "").lower() == "confidential"
    return render_template("index.html", is_confidential=is_confidential)


@app.route("/healthz", methods=["GET"])
def healthz():
    return "ok", 200


@app.route("/api/attest", methods=["POST"])
def api_attest():
    user_nonce = (request.json or {}).get("nonce") if request.is_json else request.form.get("nonce")
    try:
        result = perform_attestation(user_nonce or None)
    except Exception as exc:
        return (
            jsonify({"ok": False, "error": str(exc), "trace": traceback.format_exc()}),
            500,
        )
    return jsonify({"ok": True, **result})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "80")))
