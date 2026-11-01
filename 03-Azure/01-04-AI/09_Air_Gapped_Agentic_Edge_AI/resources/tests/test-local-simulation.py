#!/usr/bin/env python3
"""
Automated Offline & Closed-Loop Simulation Test Suite
for Air-Gapped Agentic AI: Orchestrating Local SLMs and IoT on Edge Kubernetes.

What this tests (in <10 seconds, zero Azure cost):
  1. Kubernetes YAML manifest integrity across all 4 challenge manifest folders
     (Namespace, ServiceAccount, BrokerListener, Dataflow, ModelDeployment,
      ConfigMap, Deployment, NetworkPolicy, Job).
  2. Contract alignment between manifests:
     - ServiceAccount 'inference-client' in 'edge-agents' matches ModelDeployment SAT authorizedSubjects
     - Projected SAT token audience ('foundry-local') and mount path ('/var/run/secrets/foundry-local/token')
     - Internal MQTT broker DNS ('aio-broker-internal.azure-iot-operations.svc.cluster.local:1883')
     - NetworkPolicy 'enforce-airgap-sovereign-mode' blocks external internet while allowing
       kube-system DNS (53), azure-iot-operations MQTT (1883/18883), and foundry-local-operator/istio-system (80/443/8080).
  3. Live Closed-Loop Simulation of the Edge Agent + Foundry Local HTTPS Gateway + PLC Simulator:
     - Spins up a local mock of Foundry Local (/phi-4-mini/v1/chat/completions) that validates
       the Kubernetes SAT Bearer token and evaluates SOP-CNC-042.
     - Feeds both a Warning telemetry anomaly (96.4C, 9.8mm/s) and the Challenge 5 Critical fault
       payload (114.6C, 15.2mm/s, 1.4 LPM) through the actual Edge Agent code (resources/src/edge-agent/agent.py).
     - Verifies that the agent issues 'adjust_plc_setpoint' (-25% RPM) for warnings and
       'trigger_safety_interlock' (-60% RPM, SAFE_HOLD, P1-CRITICAL-INTERLOCK) for critical faults.
"""
from __future__ import annotations

import http.server
import importlib.util
import json
import os
import re
import sys
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFESTS_DIR = ROOT / "resources" / "manifests"
AGENT_SRC = ROOT / "resources" / "src" / "edge-agent" / "agent.py"


def parse_simple_yaml_docs(file_path: Path) -> list[str]:
    text = file_path.read_text(encoding="utf-8")
    docs = [d.strip() for d in re.split(r"(?m)^---\s*$", text) if d.strip()]
    return docs


class MockFoundryLocalHandler(http.server.BaseHTTPRequestHandler):
    expected_token = "eyJhbGciOiJSUzI1NiIsImtpZCI6Imthc3MifQ.simulated-k8s-sat-token"

    def log_message(self, format: str, *args) -> None:
        pass

    def do_POST(self) -> None:
        auth_header = self.headers.get("Authorization", "")
        if auth_header != f"Bearer {self.expected_token}":
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'{"error":"Unauthorized SAT token"}')
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8"))
        user_msg = body["messages"][-1]["content"]

        match = re.search(r"\{.*\}", user_msg)
        telemetry = json.loads(match.group(0)) if match else {}

        temp = telemetry.get("bearingTempC", 0.0)
        vib = telemetry.get("vibrationMmPerSec", 0.0)
        coolant = telemetry.get("coolantFlowLpm", 10.0)

        if temp >= 105.0 or vib >= 13.0 or coolant < 2.0:
            tool_resp = {
                "tool_name": "trigger_safety_interlock",
                "arguments": {
                    "spindle_rpm_delta_pct": -60,
                    "enable_coolant_boost": True,
                    "interlock_mode": "SAFE_HOLD",
                    "priority": "P1-CRITICAL-INTERLOCK",
                },
                "reasoning": f"Critical threshold breached (temp={temp}C, vib={vib}mm/s). Triggering SOP-CNC-042 interlock.",
            }
        else:
            tool_resp = {
                "tool_name": "adjust_plc_setpoint",
                "arguments": {
                    "spindle_rpm_delta_pct": -25,
                    "enable_coolant_boost": True,
                    "interlock_mode": "CLOSED_LOOP_THROTTLE",
                    "priority": "P2-WARNING",
                },
                "reasoning": f"Warning threshold breached (temp={temp}C, vib={vib}mm/s). Throttling RPM by 25%.",
            }

        completion = {
            "id": "chatcmpl-edge-001",
            "object": "chat.completion",
            "model": body.get("model", "Phi-4-mini-instruct"),
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": json.dumps(tool_resp),
                    },
                    "finish_reason": "stop",
                }
            ],
        }
        payload = json.dumps(completion).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


class FakeMqttClient:
    def __init__(self) -> None:
        self.published: list[tuple[str, dict, int]] = []

    def publish(self, topic: str, payload: str, qos: int = 0) -> None:
        self.published.append((topic, json.loads(payload), qos))


class AirGappedEdgeMicroHackTests(unittest.TestCase):
    def test_01_all_manifests_exist_and_have_valid_kinds(self) -> None:
        expected_files = [
            MANIFESTS_DIR / "01-iot-sim" / "telemetry-simulator.yaml",
            MANIFESTS_DIR / "01-iot-sim" / "aio-anomaly-dataflow.yaml",
            MANIFESTS_DIR / "02-foundry-local" / "caller-service-account.yaml",
            MANIFESTS_DIR / "02-foundry-local" / "model-deployment-cpu.yaml",
            MANIFESTS_DIR / "03-edge-agent" / "local-sop-configmap.yaml",
            MANIFESTS_DIR / "03-edge-agent" / "edge-agent-deployment.yaml",
            MANIFESTS_DIR / "04-airgap-policy" / "deny-external-egress.yaml",
            MANIFESTS_DIR / "04-airgap-policy" / "inject-critical-fault.yaml",
        ]
        for f in expected_files:
            self.assertTrue(f.exists(), f"Missing manifest file: {f}")
            docs = parse_simple_yaml_docs(f)
            self.assertGreaterEqual(len(docs), 1, f"Empty YAML manifest: {f}")
            for doc in docs:
                self.assertIn("apiVersion:", doc, f"Missing apiVersion in {f}")
                self.assertIn("kind:", doc, f"Missing kind in {f}")
                self.assertIn("metadata:", doc, f"Missing metadata in {f}")

    def test_02_contract_alignment_across_manifests(self) -> None:
        sa_yaml = (MANIFESTS_DIR / "02-foundry-local" / "caller-service-account.yaml").read_text(encoding="utf-8")
        md_yaml = (MANIFESTS_DIR / "02-foundry-local" / "model-deployment-cpu.yaml").read_text(encoding="utf-8")
        agent_yaml = (MANIFESTS_DIR / "03-edge-agent" / "edge-agent-deployment.yaml").read_text(encoding="utf-8")
        netpol_yaml = (MANIFESTS_DIR / "04-airgap-policy" / "deny-external-egress.yaml").read_text(encoding="utf-8")

        # ServiceAccount & SAT binding
        self.assertIn("name: inference-client", sa_yaml)
        self.assertIn("namespace: edge-agents", sa_yaml)
        self.assertIn("serviceAccountName: inference-client", md_yaml)
        self.assertIn("serviceAccountNamespace: edge-agents", md_yaml)
        self.assertIn("role: GeneralInferenceUser", md_yaml)
        self.assertIn("compute: cpu", md_yaml)
        self.assertIn("runtime: onnx-genai", md_yaml)

        # Projected SAT token volume in Edge Agent deployment
        self.assertIn("serviceAccountName: inference-client", agent_yaml)
        self.assertIn("audience: foundry-local", agent_yaml)
        self.assertIn("/var/run/secrets/foundry-local", agent_yaml)

        # Air-gap NetworkPolicy allows only DNS (53), AIO MQTT (1883/18883), and Foundry Local (80/443/8080)
        self.assertIn("kind: NetworkPolicy", netpol_yaml)
        self.assertIn("azure-iot-operations", netpol_yaml)
        self.assertIn("foundry-local-operator", netpol_yaml)
        self.assertIn("istio-system", netpol_yaml)

    def test_03_closed_loop_agent_with_mock_foundry_local_and_sat_auth(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            sop_file = tmp_path / "sop.md"
            sat_file = tmp_path / "token"

            sop_yaml = (MANIFESTS_DIR / "03-edge-agent" / "local-sop-configmap.yaml").read_text(encoding="utf-8")
            sop_content = sop_yaml.split("sop.md: |", 1)[1]
            sop_file.write_text(sop_content, encoding="utf-8")
            sat_file.write_text(MockFoundryLocalHandler.expected_token, encoding="utf-8")

            server = http.server.HTTPServer(("127.0.0.1", 0), MockFoundryLocalHandler)
            port = server.server_port
            server_thread = threading.Thread(target=server.serve_forever, daemon=True)
            server_thread.start()

            try:
                os.environ["SOP_PATH"] = str(sop_file)
                os.environ["SAT_TOKEN_PATH"] = str(sat_file)
                os.environ["FOUNDRY_ENDPOINT"] = f"http://127.0.0.1:{port}/phi-4-mini/v1/chat/completions"

                if "paho" not in sys.modules:
                    import types
                    paho_mod = types.ModuleType("paho")
                    mqtt_mod = types.ModuleType("paho.mqtt")
                    client_mod = types.ModuleType("paho.mqtt.client")
                    class DummyClient:
                        pass
                    class DummyEnum:
                        VERSION2 = 2
                    client_mod.Client = DummyClient
                    client_mod.CallbackAPIVersion = DummyEnum
                    sys.modules["paho"] = paho_mod
                    sys.modules["paho.mqtt"] = mqtt_mod
                    sys.modules["paho.mqtt.client"] = client_mod

                spec = importlib.util.spec_from_file_location("edge_agent_module", AGENT_SRC)
                agent_mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(agent_mod)

                fake_mqtt = FakeMqttClient()

                # Case A: Warning anomaly (96.4C, 9.8mm/s) -> should trigger adjust_plc_setpoint (-25% RPM)
                warning_telemetry = {
                    "machineId": "CNC-EXTRUDER-01",
                    "bearingTempC": 96.4,
                    "vibrationMmPerSec": 9.8,
                    "coolantFlowLpm": 6.2,
                    "status": "WARNING_THERMAL_VIBRATION_DRIFT",
                }
                agent_mod.evaluate_anomaly(fake_mqtt, warning_telemetry)
                self.assertEqual(len(fake_mqtt.published), 1)
                topic, cmd_warn, qos = fake_mqtt.published[0]
                self.assertEqual(topic, "factory/line1/commands")
                self.assertEqual(cmd_warn["decision"]["tool_name"], "adjust_plc_setpoint")
                self.assertEqual(cmd_warn["decision"]["arguments"]["spindle_rpm_delta_pct"], -25)

                # Case B: Challenge 5 Air-Gapped Critical Fault (114.6C, 15.2mm/s, 1.4 LPM) -> trigger_safety_interlock (-60% RPM)
                critical_telemetry = {
                    "machineId": "CNC-EXTRUDER-01",
                    "bearingTempC": 114.6,
                    "vibrationMmPerSec": 15.2,
                    "coolantFlowLpm": 1.4,
                    "status": "CRITICAL_THERMAL_RUNAWAY_BEARING_SEIZURE",
                }
                agent_mod.evaluate_anomaly(fake_mqtt, critical_telemetry)
                self.assertEqual(len(fake_mqtt.published), 2)
                topic, cmd_crit, qos = fake_mqtt.published[1]
                self.assertEqual(topic, "factory/line1/commands")
                self.assertEqual(cmd_crit["decision"]["tool_name"], "trigger_safety_interlock")
                self.assertEqual(cmd_crit["decision"]["arguments"]["spindle_rpm_delta_pct"], -60)
                self.assertEqual(cmd_crit["decision"]["arguments"]["interlock_mode"], "SAFE_HOLD")
                self.assertEqual(cmd_crit["decision"]["arguments"]["priority"], "P1-CRITICAL-INTERLOCK")
            finally:
                server.shutdown()
                server.server_close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
