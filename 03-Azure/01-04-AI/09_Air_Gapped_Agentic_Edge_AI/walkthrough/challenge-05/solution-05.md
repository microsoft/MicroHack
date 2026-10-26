# Solution 05 — "Cut the Cord": Air-Gapped Fault Simulation & Verification

**[Home](../../Readme.md)** - [← Previous Solution](../challenge-04/solution-04.md) - [Back to Challenge 05](../../challenges/challenge-05.md) - [Finish →](../../challenges/finish.md)

**Duration:** 30 minutes

## Step 1: Apply the Sovereign Air-Gap `NetworkPolicy`

Apply [`resources/manifests/04-airgap-policy/deny-external-egress.yaml`](../../resources/manifests/04-airgap-policy/deny-external-egress.yaml) to block all external internet and public Azure cloud egress from the `edge-agents` namespace while allowing only:
- In-cluster DNS (`kube-system` UDP/TCP 53)
- Local Azure IoT Operations MQTT (`azure-iot-operations` TCP 1883/18883)
- Local Foundry Local & Istio Internal Gateway (`foundry-local-operator` & `istio-system` TCP 80/443/8080)

```bash
source ~/edge-env.sh
cd ~/MicroHack/03-Azure/01-04-AI/09_Air_Gapped_Agentic_Edge_AI

kubectl apply -f resources/manifests/04-airgap-policy/deny-external-egress.yaml
kubectl describe networkpolicy enforce-airgap-sovereign-mode -n edge-agents
```

---

## Step 2: Prove That Public Cloud / Internet Egress Is Blocked

Run an outbound connectivity check from inside the `autonomous-edge-agent` pod to `https://management.azure.com`:

```bash
kubectl exec -n edge-agents deploy/autonomous-edge-agent -- \
  python -c "import urllib.request; urllib.request.urlopen('https://management.azure.com', timeout=5)"
```

Expected result: **Connection timed out / URLError**, confirming that the `edge-agents` namespace cannot reach Azure Resource Manager or public cloud APIs.

Now verify that internal cluster resolution to the Azure IoT Operations MQTT Broker still succeeds:

```bash
kubectl exec -n edge-agents deploy/autonomous-edge-agent -- \
  python -c "import socket; print('AIO Broker IP:', socket.gethostbyname('aio-broker-internal.azure-iot-operations.svc.cluster.local'))"
```

---

## Step 3: Inject a Critical Bearing Thermal-Runaway Fault While Air-Gapped

Trigger the `inject-critical-bearing-fault` Kubernetes Job ([`resources/manifests/04-airgap-policy/inject-critical-fault.yaml`](../../resources/manifests/04-airgap-policy/inject-critical-fault.yaml)), which publishes a critical emergency reading (`bearingTempC: 114.6`, `vibrationMmPerSec: 15.2`, `coolantFlowLpm: 1.4`) to `factory/line1/telemetry`:

```bash
kubectl delete job inject-critical-bearing-fault -n edge-agents --ignore-not-found
kubectl apply -f resources/manifests/04-airgap-policy/inject-critical-fault.yaml
kubectl logs -n edge-agents job/inject-critical-bearing-fault -f
```

---

## Step 4: Verify Autonomous Emergency Interlock Execution

Inspect the `autonomous-edge-agent` logs to confirm that it processed the critical anomaly using **SOP-CNC-042** and **Foundry Local** (`trigger_safety_interlock`, `-60%` RPM, `P1-CRITICAL-INTERLOCK`):

```bash
kubectl logs -n edge-agents deploy/autonomous-edge-agent --tail=20
```

Expected output:

```text
[EDGE-AGENT] <<< Anomaly received on factory/line1/anomalies: machine=CNC-EXTRUDER-01 temp=114.6C vib=15.2mm/s
[EDGE-AGENT] >>> Published autonomous actuation to factory/line1/commands: tool=trigger_safety_interlock latency=... args={"spindle_rpm_delta_pct": -60, "enable_coolant_boost": true, "interlock_mode": "SAFE_HOLD", "priority": "P1-CRITICAL-INTERLOCK"}
```

Inspect the `manufacturing-telemetry-simulator` logs to confirm that the spindle RPM was immediately reduced by 60% (`4200 RPM` -> `1680 RPM`) and coolant boost was engaged:

```bash
kubectl logs -n edge-agents deploy/manufacturing-telemetry-simulator --tail=15
```

Expected output:

```text
[SIMULATOR] <<< RECEIVED AUTONOMOUS PLC COMMAND on factory/line1/commands: action=trigger_safety_interlock args={"spindle_rpm_delta_pct": -60, "enable_coolant_boost": true, "interlock_mode": "SAFE_HOLD", "priority": "P1-CRITICAL-INTERLOCK"}
[SIMULATOR] === PLC ACTUATED: spindleRpm=1680, coolantBoost=True ===
```

![Challenge 05 — Live Azure Bastion Terminal: "Cut the Cord" NetworkPolicy & Autonomous PLC Interlock](../../img/bastion-challenge-05-cut-the-cord.png)

![Challenge 05 — Air-Gapped NetworkPolicy & Emergency PLC Interlock Execution](../../img/challenge-05-airgap-interlock.png)

---

## Troubleshooting

| Symptom | Cause | Resolution |
| :--- | :--- | :--- |
| `ModelDeployment` stuck in `Pending` | Insufficient allocatable CPU/memory on the K3s node | Ensure the Edge Host VM is at least `Standard_D8s_v5` (`Standard_D16s_v5` default) or reduce `resources.requests.cpu` in `model-deployment-cpu.yaml` to `2`. |
| `401 Unauthorized` or `403 Forbidden` calling Foundry Local | Projected SAT token audience mismatch or missing `authorizedSubjects` | Verify `audience: foundry-local` in `edge-agent-deployment.yaml` and `serviceAccountName: inference-client` in `model-deployment-cpu.yaml`. |
| No messages arriving on `factory/line1/anomalies` | AIO Dataflow not bound to default Broker | Run `kubectl get dataflow cnc-anomaly-router -n azure-iot-operations -o yaml` and verify `status.conditions`. |

---

## Grounding Questions — Suggested Answers

**1. Why must the `NetworkPolicy` explicitly permit UDP/TCP port `53` to `kube-system` even when all services are inside the same Kubernetes cluster?**
In Kubernetes, once any `Egress` `NetworkPolicy` selects a pod, **all** egress traffic from that pod is denied unless explicitly allowed by a rule—including DNS lookups to `CoreDNS` in the `kube-system` namespace. Without allowing UDP/TCP 53 to `kube-system`, the Edge Agent could not resolve `aio-broker-internal.azure-iot-operations.svc.cluster.local` or `inference-internal-gateway-istio.foundry-local-operator.svc.cluster.local`.

**2. In `agent.py`, why do we include a deterministic SOP safety guard (`local-sop-deterministic-guard`) alongside the SLM call for critical industrial equipment?**
In industrial control systems (OT), AI agents provide contextual reasoning and multi-signal diagnosis, but safety-critical interlocks must never have a single point of failure if a model pod is restarting or times out. Pairing local SLM reasoning with a deterministic SOP fallback guarantees bounded-time safety actuation under all operating conditions.

[← Previous Solution](../challenge-04/solution-04.md) | [Back to Challenge 05](../../challenges/challenge-05.md) | [Finish →](../../challenges/finish.md)
