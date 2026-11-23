/* Every number and label on the slides, with the file it comes from.
   Paths are relative to the hack folder (03-Azure/01-04-AI/09_Air_Gapped_Agentic_Edge_AI).
   Nothing here was measured for the talk: it is all taken from the hack's own runs and docs. */
window.TALK = {
  // Readme.md (Edge Simulation Environment, Facilitator Guidance)
  host: { vm: 'Standard_D16s_v5', vcpu: 16, ramGiB: 64, os: 'Ubuntu 24.04', k8s: 'K3s' },
  // Readme.md, "Expected Timing": machine and CLI wait time per challenge, in minutes
  waits: [
    ['01', 'Sovereign edge foundation', 5],
    ['02', 'IoT data plane', 14],
    ['03', 'Local model serving', 11],
    ['04', 'SAT auth and edge agent', 2],
    ['05', 'Cut the cord', 2],
  ],

  // The transfer manifest: what has to be inside before the namespace is sealed.
  // Sources: model-deployment-cpu.yaml, challenge-03.md and solution-03.md (model, 5.15 GB, hash check);
  // edge-agent-deployment.yaml and inject-critical-fault.yaml (images, IfNotPresent, wheel path);
  // cloud-init-k3s.yaml (pip3 download into /opt/edge-wheels); local-sop-configmap.yaml (SOP);
  // challenge-03.md (Gateway API CRDs v1.4.0, Inference Extension CRDs v1.5.0).
  manifest: [
    { name: 'Phi-4-mini-instruct-generic-cpu:5', detail: '5.15 GB, ONNX INT4 weights', check: 'hashes verified by StoreModel', store: 'In-cluster model store', where: 'PVC, PHASE Available' },
    { name: 'Container images', detail: 'python:3.12-slim, eclipse-mosquitto:2.0', check: 'pinned tags', store: 'Node image cache', where: 'imagePullPolicy: IfNotPresent' },
    { name: 'paho-mqtt==2.1.0 wheel', detail: 'downloaded by cloud-init at bootstrap', check: 'pinned version', store: '/opt/edge-wheels', where: 'pip install --no-index' },
    { name: 'Runbook SOP-CNC-042', detail: 'thresholds and mitigation rules', check: 'mounted read-only', store: 'ConfigMap local-sop-runbook', where: 'mounted at /etc/edge-sop' },
    { name: 'Platform charts and CRDs', detail: 'Gateway API v1.4.0, Inference Ext. v1.5.0, Istio', check: 'pinned versions', store: 'Cluster control plane', where: 'Arc extensions, Helm releases' },
  ],
  // edge-agent-deployment.yaml: the start command falls back to the internet when the local wheel is missing
  pipFallback: 'pip install --no-cache-dir paho-mqtt==2.1.0',

  // solution-03.md and challenge-03.md. Challenge 3 also quotes 5.38 GB for the same download.
  model: {
    catalog: 177, alias: 'phi-4-mini', id: 'Phi-4-mini-instruct-generic-cpu:5', sizeGB: 5.15, sizeAltGB: 5.38,
    cacheMin: '6 to 7', compute: 'cpu', runtime: 'onnx-genai',
    store: 'model-store.foundry-local-operator.svc.cluster.local:8443',
    storeRef: 'models/foundry-local/phi-4-mini/cpu-onnx:5',   // img/bastion-challenge-03-storing.png
  },

  // img/bastion-challenge-04-sat-and-inference.png (decoded projected token, then a live completion)
  sat: {
    aud: 'foundry-local', iss: 'https://kubernetes.default.svc.cluster.local',
    sub: ['system:serviceaccount:', 'edge-agents:inference-client'],
    iat: 1792440469, exp: 1792444069,          // exp - iat = 3600 s, matches expirationSeconds: 3600 in edge-agent-deployment.yaml
    pod: 'autonomous-edge-agent-cd45f6667-l57cj',
    role: 'GeneralInferenceUser',               // model-deployment-cpu.yaml
    promptTokens: 54, completionTokens: 29,
  },

  // Recorded telemetry. img/bastion-challenge-02-aio-anomaly.png (ticks 330 to 336) and
  // img/bastion-challenge-05-cut-the-cord.png (ticks 357 to 360). Ticks 334 and 335 were not captured.
  // Dataflow filter in aio-anomaly-dataflow.yaml drops a reading when temp <= 85.0 and vibration <= 7.5.
  ticks: [
    [330, 93.9, 8.68], [331, 68.8, 2.58], [332, 71.7, 3.41], [333, 74.1, 3.02], [336, 103.5, 9.01],
    [357, 64.9, 3.72], [358, 62.3, 3.44], [359, 71.0, 3.07], [360, 95.9, 9.41],
  ],
  filter: { temp: 85.0, vib: 7.5, every: 6, periodS: 5 },   // solution-02.md: every 5 s, an anomaly every 6th tick

  // local-sop-configmap.yaml (SOP-CNC-042)
  sop: { warnTemp: 85, critTemp: 105, warnVib: 7.5, critVib: 13.0, critCoolant: 2.0 },

  // img/bastion-challenge-05-cut-the-cord.png: the probe error and the agent's decisions with the policy applied
  probe: { url: 'https://management.azure.com', timeout: 4, error: ['urllib.error.URLError:', '[Errno 101] Network', 'is unreachable'] },
  warnings: [
    { temp: 95.2, vib: 8.9, tool: 'adjust_plc_setpoint', delta: -25, boost: 'true', mode: 'null', priority: 'null', ms: 8729.4 },
    { temp: 100.1, vib: 9.73, tool: 'adjust_plc_setpoint', delta: -25, boost: 'true', mode: 'null', priority: 'null', ms: 8736.2 },
  ],
  fault: { temp: 114.6, vib: 15.2, coolant: 1.4 },          // inject-critical-fault.yaml
  critical: { tool: 'trigger_safety_interlock', delta: -60, boost: 'true', mode: 'SAFE_HOLD', ms: 8011.3 },
  rpm: { before: 4200, after: 1680 },                       // telemetry-simulator.yaml (4200 baseline) and the simulator log
};
