"""
Autonomous Edge Triage & Actuation Agent (Reference Source)
-----------------------------------------------------------
Connects Azure IoT Operations (MQTT Broker) to Foundry Local (/v1/chat/completions)
using Kubernetes Service Account Token (SAT) authentication and local SOP grounding.
"""
import json
import os
import ssl
import time
import urllib.request
from datetime import datetime, timezone
import paho.mqtt.client as mqtt

MQTT_HOST = os.getenv("MQTT_HOST", "aio-broker-internal.azure-iot-operations.svc.cluster.local")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
ANOMALIES_TOPIC = os.getenv("ANOMALIES_TOPIC", "factory/line1/anomalies")
COMMANDS_TOPIC = os.getenv("COMMANDS_TOPIC", "factory/line1/commands")
FOUNDRY_ENDPOINT = os.getenv(
    "FOUNDRY_ENDPOINT",
    "https://inference-internal-gateway-istio.foundry-local-operator.svc.cluster.local:443/phi-4-mini/v1/chat/completions",
)
MODEL_NAME = os.getenv("MODEL_NAME", "Phi-4-mini-instruct-generic-cpu:5")
SAT_TOKEN_PATH = os.getenv("SAT_TOKEN_PATH", "/var/run/secrets/foundry-local/token")
SOP_PATH = os.getenv("SOP_PATH", "/etc/edge-sop/sop.md")


def read_local_sop() -> str:
    with open(SOP_PATH, "r", encoding="utf-8") as f:
        return f.read()


def read_sat_token() -> str:
    """Re-read the projected Kubernetes SAT token on every request to support automatic rotation."""
    with open(SAT_TOKEN_PATH, "r", encoding="utf-8") as f:
        return f.read().strip()


def invoke_foundry_local(telemetry: dict, sop_text: str) -> dict:
    token = read_sat_token()
    system_prompt = (
        "You are an autonomous industrial edge AI agent running inside an air-gapped factory Kubernetes cluster.\n"
        "Analyze the incoming machine anomaly against the following Local SOP Runbook and respond ONLY with a valid JSON object "
        "matching this schema:\n"
        '{"tool_name": "adjust_plc_setpoint" | "trigger_safety_interlock", '
        '"arguments": {"spindle_rpm_delta_pct": int, "enable_coolant_boost": bool, "interlock_mode": str, "priority": str}, '
        '"reasoning": str}\n\n'
        f"--- LOCAL SOP RUNBOOK ---\n{sop_text}"
    )
    request_body = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Telemetry anomaly received: {json.dumps(telemetry)}"},
        ],
        "temperature": 0.0,
        "max_tokens": 256,
    }

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    req = urllib.request.Request(
        FOUNDRY_ENDPOINT,
        data=json.dumps(request_body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        raw = json.loads(resp.read().decode("utf-8"))
    latency_ms = round((time.perf_counter() - start) * 1000, 1)

    content = raw["choices"][0]["message"]["content"].strip()
    if "```" in content:
        content = content.split("```")[1].replace("json", "", 1).strip()
    decision = json.loads(content)
    decision["inferenceLatencyMs"] = latency_ms
    return decision


def evaluate_anomaly(client: mqtt.Client, telemetry: dict) -> None:
    sop_text = read_local_sop()
    decision = invoke_foundry_local(telemetry, sop_text)
    command_event = {
        "commandId": f"cmd-{int(time.time() * 1000)}",
        "machineId": telemetry.get("machineId", "CNC-EXTRUDER-01"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "authMethod": "Kubernetes-SAT (audience: foundry-local)",
        "inferenceEngine": "foundry-local-onnx-genai",
        "decision": decision,
    }
    client.publish(COMMANDS_TOPIC, json.dumps(command_event), qos=1)
    print(f"[EDGE-AGENT] Published autonomous PLC command: {json.dumps(command_event)}", flush=True)


def on_connect(client, userdata, flags, reason_code, properties=None):
    print(f"[EDGE-AGENT] Connected to AIO MQTT Broker at {MQTT_HOST}:{MQTT_PORT}", flush=True)
    client.subscribe(ANOMALIES_TOPIC, qos=1)


def on_message(client, userdata, msg):
    telemetry = json.loads(msg.payload.decode("utf-8"))
    evaluate_anomaly(client, telemetry)


if __name__ == "__main__":
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="autonomous-edge-agent-01")
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    mqtt_client.loop_forever()
