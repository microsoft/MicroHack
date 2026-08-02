"""
SEV-SNP / TDX runtime attestation web UI for AKS Confidential Computing nodes.

Wraps Azure/cvm-attestation-tools (https://github.com/Azure/cvm-attestation-tools)
to perform a guest attestation against Microsoft Azure Attestation (MAA) and
present the resulting JWT claims with human-readable explanations.

Expected runtime layout (matches Dockerfile and the in-cluster ConfigMap bootstrap):

    /opt/cvm-tools/cvm-attestation/    <- upstream cvm-attestation-tools clone
    /app/app.py                        <- this file
    /app/templates/                    <- index.html / result.html
    /app/config_snp.json               <- MAA SEV-SNP config copied here at startup

The pod must run with access to /dev/tpmrm0 (TPM Resource Manager) so the upstream
client can fetch the HCL report from the vTPM.
"""

import base64
import json
import os
import secrets
import sys
import traceback
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

# Make the upstream cvm-attestation package importable.
CVM_TOOLS_DIR = os.environ.get("CVM_TOOLS_DIR", "/opt/cvm-tools/cvm-attestation")
if CVM_TOOLS_DIR not in sys.path:
    sys.path.insert(0, CVM_TOOLS_DIR)

# The upstream tool reads its endpoint table from the current working dir.
os.chdir(CVM_TOOLS_DIR)

from src.attestation_client import (  # noqa: E402  (import after sys.path tweak)
    AttestationClient,
    AttestationClientParameters,
    Verifier,
)
from src.endpoint_selector import EndpointSelector  # noqa: E402
from src.imds_client import ImdsClient  # noqa: E402
from src.isolation import IsolationType  # noqa: E402
from src.logger import Logger  # noqa: E402


# ---------------------------------------------------------------------------
# Claim explanations (MAA SEV-SNP and TDX tokens)
# ---------------------------------------------------------------------------
# References:
#   https://learn.microsoft.com/azure/attestation/claim-sets
#   https://learn.microsoft.com/azure/attestation/claim-rule-grammar
#   AMD SEV-SNP ABI specification (publication 56860)
CLAIM_EXPLANATIONS = {
    # Standard JWT
    "iss": "Issuer - the MAA endpoint that signed this token. Verifying the issuer URL pins the token to a specific Azure Attestation provider.",
    "iat": "Issued At (Unix epoch seconds) - when MAA produced the token.",
    "exp": "Expiration (Unix epoch seconds) - after this point the token must not be trusted.",
    "nbf": "Not Before (Unix epoch seconds) - the token is not valid earlier than this time.",
    "jti": "JWT ID - a unique identifier MAA assigns to this token; useful for replay detection.",

    # MAA generic
    "x-ms-ver": "MAA token schema version.",
    "x-ms-attestation-type": "Type of TEE that produced the evidence ('sevsnpvm', 'tdxvm', 'azurevm', 'tpm', etc.). On AMD CC AKS nodes the OUTER token is 'azurevm' (Azure HCL envelope) and the INNER x-ms-isolation-tee block reports 'sevsnpvm'.",
    "x-ms-compliance-status": "MAA's overall verdict against its policy. 'azure-compliant-cvm' means the platform passed all Azure CVM policy checks.",
    "x-ms-policy-hash": "SHA-256 of the MAA policy (base64url) that evaluated this evidence. Pin this in your relying party to detect policy drift.",
    "x-ms-policy-signer": "If a custom JWS-signed MAA policy was used, this is the signer's certificate chain.",
    "x-ms-runtime": "Caller-supplied runtime data that was bound into the hardware report's REPORT_DATA field. For Azure CVMs this also carries the HCL-generated vTPM keys (HCLAkPub, HCLEkPub) and the VM configuration snapshot.",
    "x-ms-inittime": "Init-time data bound into the report (rarely used for IaaS CVMs).",
    "x-ms-isolation-tee": "Nested sub-token containing the hardware TEE evidence MAA verified. For SEV-SNP this holds every x-ms-sevsnpvm-* field plus its own x-ms-attestation-type and x-ms-compliance-status. This is the cryptographic root of trust for the whole token.",
    "nonce": "Caller-supplied nonce echoed back inside x-ms-runtime to prove freshness.",
    "secureboot": "true if UEFI Secure Boot was enabled on the guest at attest time.",

    # SEV-SNP specific
    "x-ms-sevsnpvm-authorkeydigest": "SHA-384 of the SEV-SNP author key (AKD). Zero on Azure-managed CVMs unless you bring your own ID/Author key.",
    "x-ms-sevsnpvm-bootloader-svn": "SVN of the AMD SEV-SNP guest bootloader at launch.",
    "x-ms-sevsnpvm-chip-family": "AMD CPU family that produced this report (e.g. 'Milan' = 3rd-gen EPYC, 'Genoa' = 4th-gen EPYC).",
    "x-ms-sevsnpvm-chipid": "Per-chip unique identifier (CHIP_ID) burned into the AMD SP. Lets you identify the exact physical socket the CVM is running on.",
    "x-ms-sevsnpvm-ciphertext-hiding-dram-enabled": "true if AMD ciphertext-hiding (CT-Hide) DRAM feature is active (mitigates ciphertext side channels).",
    "x-ms-sevsnpvm-cxl-allowed": "Whether CXL.mem devices were permitted for this guest at launch.",
    "x-ms-sevsnpvm-familyId": "Family ID supplied at SNP_LAUNCH_FINISH (16 bytes). On Azure CVMs this identifies the Azure VM family.",
    "x-ms-sevsnpvm-guestsvn": "Guest Security Version Number stamped into the report. Allows monotonic anti-rollback in your policy.",
    "x-ms-sevsnpvm-hostdata": "Host data the hypervisor injected at launch (e.g. a SHA-256 of an external policy). Lets you bind the guest to a specific host configuration.",
    "x-ms-sevsnpvm-idkeydigest": "SHA-384 of the SEV-SNP ID Key (IDK). On Azure CC nodes this is the Azure-managed launch ID key digest.",
    "x-ms-sevsnpvm-imageId": "Image ID supplied at SNP_LAUNCH_FINISH (16 bytes).",
    "x-ms-sevsnpvm-is-debuggable": "true means the guest was launched with the SNP debug policy bit set. For production CVMs this MUST be false.",
    "x-ms-sevsnpvm-launchmeasurement": "SHA-384 of the initial guest memory contents measured by AMD-SP at launch. This is the cryptographic identity of the boot image that came up; a relying party pins expected values here.",
    "x-ms-sevsnpvm-mem-aes256-xts-required": "Whether AES-256-XTS memory encryption was required (vs the older AES-128 mode).",
    "x-ms-sevsnpvm-microcode-svn": "Microcode SVN of the AMD CPU at attestation time.",
    "x-ms-sevsnpvm-migration-allowed": "true if the SNP guest policy permits migration between machines. Azure CVMs report false.",
    "x-ms-sevsnpvm-page-swap-disabled": "Whether host-initiated page swapping of CVM memory is disabled.",
    "x-ms-sevsnpvm-rapl-disabled": "Whether the AMD RAPL (Running Average Power Limit) interface is disabled for this guest (mitigates power side-channels).",
    "x-ms-sevsnpvm-reportdata": "Hex of REPORT_DATA - 64 bytes the guest itself supplied when requesting the report. The Azure HCL stuffs a TPM-backed runtime hash here so you can cryptographically link the MAA token to a vTPM nonce.",
    "x-ms-sevsnpvm-reportid": "Per-launch report ID assigned by AMD-SP. Different across reboots.",
    "x-ms-sevsnpvm-singlesocket": "true if the SNP guest policy required a single-socket host.",
    "x-ms-sevsnpvm-smt-allowed": "true means simultaneous multithreading was allowed at launch (per SNP guest policy).",
    "x-ms-sevsnpvm-snpfw-svn": "SVN of the AMD SEV-SNP firmware (PSP) at attestation time.",
    "x-ms-sevsnpvm-tee-svn": "SVN of the TEE component (always 0 for SEV-SNP today; reserved).",
    "x-ms-sevsnpvm-vmpl": "Virtual Machine Privilege Level the report was generated at. Azure CVMs run the OS at VMPL0; reports about the OS itself therefore come from VMPL0.",

    # vTPM / HCL
    "x-ms-azurevm-attestation-protocol-ver": "Version of the Azure HCL attestation protocol used to build this token.",
    "x-ms-azurevm-attested-pcr-values": "Values of the vTPM PCRs that were quoted and signed inside the HCL report. The relying party can match these against known-good measurements.",
    "x-ms-azurevm-attested-pcrs": "List of vTPM PCR indices that contributed to the quote.",
    "x-ms-azurevm-bootdebug-enabled": "true if the Windows boot debugger was enabled at boot.",
    "x-ms-azurevm-dbvalidated": "true if the UEFI Secure Boot 'db' (allowed signers) database is intact and validated.",
    "x-ms-azurevm-dbxvalidated": "true if the UEFI Secure Boot 'dbx' (revoked signers) database is intact and validated.",
    "x-ms-azurevm-default-securebootkeysvalidated": "MAA confirmed the default Azure Secure Boot keys are present and validated by the HCL.",
    "x-ms-azurevm-debuggersdisabled": "Kernel debuggers are disabled.",
    "x-ms-azurevm-elam-enabled": "Early Launch Anti-Malware was active during boot (Windows guests).",
    "x-ms-azurevm-flightsigning-enabled": "Whether Windows test/flight signing was permitted.",
    "x-ms-azurevm-hvci-policy": "Numeric HVCI (Hypervisor-protected Code Integrity) policy state.",
    "x-ms-azurevm-hypervisordebug-enabled": "Whether the hypervisor debugger was enabled.",
    "x-ms-azurevm-is-windows": "true if the guest was identified as Windows by the HCL.",
    "x-ms-azurevm-kerneldebug-enabled": "Whether kernel debugging was enabled at attest time.",
    "x-ms-azurevm-osbuild": "Reported guest OS build string.",
    "x-ms-azurevm-osdistro": "Reported Linux distribution (e.g. 'Ubuntu', 'Mariner').",
    "x-ms-azurevm-ostype": "Linux or Windows.",
    "x-ms-azurevm-osversion-major": "Guest OS major version.",
    "x-ms-azurevm-osversion-minor": "Guest OS minor version.",
    "x-ms-azurevm-signingdisabled": "Whether driver signing enforcement was disabled.",
    "x-ms-azurevm-testsigning-enabled": "Whether unsigned/test-signed binaries were permitted.",
    "x-ms-azurevm-vmid": "Azure VM ID (GUID) reported by IMDS at attest time. Useful for correlating with control-plane logs.",

    # TDX (in case the workload runs on Intel TDX nodes)
    "x-ms-tdxvm-tdreport": "Raw Intel TD-Report fields measured by Intel TDX Module.",
    "x-ms-tdxvm-mrtd": "Measurement of the initial TD - the TDX equivalent of LAUNCH_MEASUREMENT.",
    "x-ms-tdxvm-rtmrs": "Runtime extendable measurement registers (RTMR0..RTMR3).",
}


def _explain(claim_key: str) -> str:
    """Return a human explanation for a claim key, or a generic fallback."""
    if claim_key in CLAIM_EXPLANATIONS:
        return CLAIM_EXPLANATIONS[claim_key]
    if claim_key.startswith("x-ms-sevsnpvm-"):
        return "SEV-SNP attestation report field surfaced by MAA. See AMD SEV-SNP ABI spec for the underlying bit layout."
    if claim_key.startswith("x-ms-tdxvm-"):
        return "Intel TDX attestation field surfaced by MAA."
    if claim_key.startswith("x-ms-azurevm-"):
        return "Azure HCL / VM-level claim derived from the vTPM-anchored runtime report."
    if claim_key.startswith("x-ms-"):
        return "MAA-issued claim. Refer to the Microsoft Azure Attestation claim-set documentation."
    return "Standard JWT or caller-supplied claim."


# ---------------------------------------------------------------------------
# JWT helpers (display only - no signature verification here; MAA already
# verified the hardware evidence and signed the token)
# ---------------------------------------------------------------------------
def _b64url_decode(segment: str) -> bytes:
    pad = "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(segment + pad)


def decode_jwt(token):
    if isinstance(token, bytes):
        token = token.decode("utf-8")
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError(f"Token does not have 3 segments (got {len(parts)})")
    header = json.loads(_b64url_decode(parts[0]))
    payload = json.loads(_b64url_decode(parts[1]))
    return header, payload


def _format_timestamp(value):
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc).isoformat()
    except Exception:
        return None


def annotate_claims(payload: dict):
    """Flatten the payload into [{key, value, explanation, timestamp?, section}] rows.

    The MAA 'guest' attestation token for AMD CC AKS nodes nests every SEV-SNP claim
    under x-ms-isolation-tee. We surface that subtree as its own section so each
    sevsnpvm-* field gets its own explained row instead of being one giant JSON blob.
    """
    rows = []

    def add_row(key, value, section):
        row = {
            "key": key,
            "value": value,
            "explanation": _explain(key),
            "section": section,
        }
        if key in {"iat", "exp", "nbf"}:
            row["timestamp"] = _format_timestamp(value)
        rows.append(row)

    isolation_tee = None
    for key, value in payload.items():
        if key == "x-ms-isolation-tee" and isinstance(value, dict):
            isolation_tee = value
            # Still surface the parent so its purpose is explained.
            add_row(key, "(see SEV-SNP / Hardware TEE section below)", "Outer MAA token")
            continue
        add_row(key, value, "Outer MAA token")

    if isolation_tee is not None:
        for key, value in isolation_tee.items():
            add_row(key, value, "x-ms-isolation-tee (SEV-SNP hardware TEE evidence)")

    # Sort: hardware TEE block first, then outer; within each, x-ms-* first.
    section_order = {
        "x-ms-isolation-tee (SEV-SNP hardware TEE evidence)": 0,
        "Outer MAA token": 1,
    }
    rows.sort(key=lambda r: (section_order.get(r["section"], 2), not r["key"].startswith("x-ms-"), r["key"]))
    return rows


# ---------------------------------------------------------------------------
# Attestation invocation
# ---------------------------------------------------------------------------
def perform_attestation(user_nonce: str | None):
    """Run a guest attestation and return (jwt_token, header, payload, hw_evidence_summary)."""
    logger = Logger("cc-attestation-web").get_logger()

    config_path = os.environ.get("ATTEST_CONFIG", "/app/config_snp.json")
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    nonce = user_nonce or secrets.token_hex(16)
    config.setdefault("claims", {}).setdefault("user-claims", {})["nonce"] = nonce

    isolation_type = {
        "maa_snp": IsolationType.SEV_SNP,
        "maa_tdx": IsolationType.TDX,
        "maa_trusted_launch": IsolationType.TRUSTED_LAUNCH,
    }.get(config.get("attestation_provider"), IsolationType.UNDEFINED)

    # Resolve the regional MAA endpoint from IMDS (matches the upstream CLI).
    imds_client = ImdsClient(logger)
    region = imds_client.get_region_from_compute_metadata()
    if not region:
        raise RuntimeError("Unable to read Azure region from IMDS - is this pod on an Azure VM?")
    region = region.replace(" ", "").lower()
    table = "attestation_uri_table_usgov.json" if "usgov" in region else "attestation_uri_table.json"
    endpoint = EndpointSelector(os.path.join(CVM_TOOLS_DIR, table), logger).get_attestation_endpoint(
        isolation_type, "guest", region
    )

    params = AttestationClientParameters(
        endpoint=endpoint,
        verifier=Verifier.MAA,
        isolation_type=isolation_type,
        claims=config.get("claims"),
        api_key=config.get("api_key", ""),
    )
    client = AttestationClient(logger, params)
    token = client.attest_guest()
    if isinstance(token, bytes):
        token = token.decode("utf-8")

    header, payload = decode_jwt(token)

    hw_summary = {}
    try:
        evidence = client.get_hardware_evidence()
        if evidence is not None and getattr(evidence, "hardware_report", None):
            hw_summary["hardware_report_bytes"] = len(evidence.hardware_report)
            hw_summary["hardware_report_sha256"] = __import__("hashlib").sha256(
                evidence.hardware_report
            ).hexdigest()
        if evidence is not None and getattr(evidence, "runtime_data", None):
            try:
                hw_summary["runtime_data"] = json.loads(evidence.runtime_data)
            except Exception:
                hw_summary["runtime_data_raw_bytes"] = len(evidence.runtime_data)
    except Exception:
        # Hardware evidence is best-effort; the token is the source of truth.
        pass

    return {
        "endpoint": endpoint,
        "region": region,
        "isolation_type": isolation_type.name if hasattr(isolation_type, "name") else str(isolation_type),
        "nonce": nonce,
        "token": token,
        "header": header,
        "payload": payload,
        "claims": annotate_claims(payload),
        "hardware_evidence": hw_summary,
    }


# ---------------------------------------------------------------------------
# Flask app
# ---------------------------------------------------------------------------
app = Flask(__name__)


@app.route("/", methods=["GET"])
def index():
    return render_template(
        "index.html",
        node_name=os.environ.get("NODE_NAME", ""),
        pod_name=os.environ.get("POD_NAME", ""),
    )


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
            jsonify(
                {
                    "ok": False,
                    "error": str(exc),
                    "trace": traceback.format_exc(),
                }
            ),
            500,
        )
    return jsonify({"ok": True, **result})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "80")))
