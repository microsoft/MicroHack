# Solution 04 — Wire the Autonomous Edge Agent with Zero-Cloud SAT Authentication

**[Home](../../Readme.md)** - [← Previous Solution](../challenge-03/solution-03.md) - [Back to Challenge 04](../../challenges/challenge-04.md) - [Next Solution →](../challenge-05/solution-05.md)

**Duration:** 35 minutes

## Step 1: Verify Kubernetes Service Account Token (SAT) Authentication

Before deploying the Autonomous Edge Agent pod, verify that a short-lived Kubernetes Service Account Token minted for `inference-client` (`--audience foundry-local`) is accepted by the `phi-4-mini` `ModelDeployment`.

```bash
source ~/edge-env.sh
cd ~/MicroHack/03-Azure/01-04-AI/09_Air_Gapped_Agentic_Edge_AI

# 1. Mint a 10-minute SAT token from the local Kubernetes API server
TOKEN=$(kubectl create token inference-client \
  -n edge-agents \
  --audience foundry-local \
  --duration 10m)

# 2. Retrieve the internal Gateway endpoint for phi-4-mini
ENDPOINT=$(kubectl get modeldeployment phi-4-mini \
  -n foundry-local-operator \
  -o jsonpath='{.status.endpoints.internal}')

# 3. Call /v1/models and /v1/chat/completions from inside the cluster with the SAT token
kubectl exec -n edge-agents deploy/manufacturing-telemetry-simulator -- \
  python -c "import json, ssl, urllib.request
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
body=json.dumps({'model':'Phi-4-mini-instruct-generic-cpu:5','messages':[{'role':'user','content':'Reply with READY.'}],'max_tokens':16}).encode()
req=urllib.request.Request('${ENDPOINT}/v1/chat/completions', data=body, headers={'Authorization': 'Bearer ${TOKEN}', 'Content-Type': 'application/json'}, method='POST')
print(urllib.request.urlopen(req, context=ctx, timeout=60).read().decode())"
```

You should receive a JSON chat completion response (`"content":"READY"`) from `Phi-4-mini-instruct-generic-cpu:5`.

---

## Step 2: Deploy the Local SOP Runbook (`SOP-CNC-042`)

Apply [`resources/manifests/03-edge-agent/local-sop-configmap.yaml`](../../resources/manifests/03-edge-agent/local-sop-configmap.yaml) so the Edge Agent has local access to the CNC-Extruder operating thresholds and mitigation rules without querying any external database:

```bash
kubectl apply -f resources/manifests/03-edge-agent/local-sop-configmap.yaml
kubectl describe configmap local-sop-runbook -n edge-agents
```

---

## Step 3: Deploy the Autonomous Edge Triage & Actuation Agent

Apply [`resources/manifests/03-edge-agent/edge-agent-deployment.yaml`](../../resources/manifests/03-edge-agent/edge-agent-deployment.yaml):

```bash
kubectl apply -f resources/manifests/03-edge-agent/edge-agent-deployment.yaml
kubectl rollout status deployment/autonomous-edge-agent -n edge-agents
```

Verify that the projected Service Account Token volume is mounted inside the pod at `/var/run/secrets/foundry-local/token`:

```bash
kubectl exec -n edge-agents deploy/autonomous-edge-agent -- ls -l /var/run/secrets/foundry-local/token
```

---

## Step 4: Observe the Closed-Loop Edge Workflow

Follow the logs of the `autonomous-edge-agent` deployment:

```bash
kubectl logs -n edge-agents deploy/autonomous-edge-agent --tail=30 -f
```

When the simulator emits its periodic warning anomaly (`bearingTempC > 85.0` or `vibrationMmPerSec > 7.5`), the AIO Dataflow routes it to `factory/line1/anomalies` and you will see:

```text
[EDGE-AGENT] <<< Anomaly received on factory/line1/anomalies: machine=CNC-EXTRUDER-01 temp=95.4C vib=9.82mm/s
[EDGE-AGENT] >>> Published autonomous actuation to factory/line1/commands: tool=adjust_plc_setpoint latency=1420.5ms args={"spindle_rpm_delta_pct": -25, "enable_coolant_boost": true, "interlock_mode": "CLOSED_LOOP_THROTTLE", "priority": "P2-WARNING"}
```

Check the simulator logs to verify that the simulated PLC received the command on `factory/line1/commands` and throttled the spindle RPM:

```bash
kubectl logs -n edge-agents deploy/manufacturing-telemetry-simulator --tail=15
```

Expected output:

```text
[SIMULATOR] <<< RECEIVED AUTONOMOUS PLC COMMAND on factory/line1/commands: action=adjust_plc_setpoint args={"spindle_rpm_delta_pct": -25, "enable_coolant_boost": true, ...}
[SIMULATOR] === PLC ACTUATED: spindleRpm=3150, coolantBoost=True ===
```

![Challenge 04 — Live Azure Bastion Terminal: Projected Kubernetes SAT JWT & Live Phi-4-mini Completion](../../img/bastion-challenge-04-sat-and-inference.png)

![Challenge 04 — Closed-Loop Edge Agent & PLC Actuation](../../img/challenge-05-airgap-interlock.png)

**Common stumbles:** `401 Unauthorized` when calling `/v1/chat/completions` (ensure `--audience foundry-local` was passed to `kubectl create token` and matches `satAuth.audience`) · `404 Not Found` on model name (pass `"model": "Phi-4-mini-instruct-generic-cpu:5"`, the exact ID returned by `/v1/models`).

---

## Grounding Questions — Suggested Answers

**1. Why does `caller-service-account.yaml` set `automountServiceAccountToken: false` on the `inference-client` ServiceAccount when the pod still needs a Service Account Token?**
By default, Kubernetes mounts a general-purpose token targeted at the Kubernetes API server audience into every pod. Setting `automountServiceAccountToken: false` follows least-privilege security by disabling the default Kubernetes API token and mounting **only** a dedicated projected token bound strictly to `audience: foundry-local` with a 1-hour expiry.

**2. How does the Foundry Local auth sidecar verify a Kubernetes Service Account Token without calling out to Microsoft Entra ID?**
Each `ModelDeployment` pod runs an authentication sidecar that validates the incoming `Bearer` JWT against the local Kubernetes API server's `TokenReview` / OIDC discovery keys, checks that `aud` equals `foundry-local`, and verifies that the caller's `sub` (`system:serviceaccount:edge-agents:inference-client`) is listed under `authorizedSubjects` with role `GeneralInferenceUser`.

[← Previous Solution](../challenge-03/solution-03.md) | [Back to Challenge 04](../../challenges/challenge-04.md) | [Next Solution →](../challenge-05/solution-05.md)
