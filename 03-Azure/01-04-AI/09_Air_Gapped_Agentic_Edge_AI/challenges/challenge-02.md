# Challenge 02 — Deploy Azure IoT Operations & Simulated Manufacturing Telemetry

**[Home](../Readme.md)** - [← Previous Challenge](challenge-01.md) - [Next Challenge →](challenge-03.md)

## 🎯 Objective

Deploy **Azure IoT Operations (`Microsoft.IoTOperations`)** onto your Azure Arc-enabled Kubernetes cluster, expose an internal cluster MQTT listener, deploy the **Manufacturing Telemetry Simulator**, and configure an **AIO Dataflow** to filter and route anomalous machine readings to a dedicated anomaly topic.

## 🧭 Context

Contoso Precision Manufacturing's CNC-Extruder line (`CNC-EXTRUDER-01`) emits telemetry every 5 seconds (spindle RPM, bearing temperature in °C, vibration RMS in mm/s, and coolant flow in LPM). Streaming every normal reading to a CPU-based Small Language Model would saturate edge compute.

Instead, you will use **Azure IoT Operations (AIO)** as the unified edge data plane:
1. All raw sensor readings arrive on the AIO MQTT Broker topic `factory/line1/telemetry`.
2. An **AIO Dataflow (`cnc-anomaly-router`)** evaluates readings in real time at the broker level and forwards **only anomalous windows** (`bearingTempC > 85.0` or `vibrationMmPerSec > 7.5`) to `factory/line1/anomalies`.

> [!WARNING]
> **Watch out for AIO Dataflow filter semantics!** In Azure IoT Operations Dataflows, `builtInTransformationSettings.filter` is a **drop filter**: when the boolean expression evaluates to `true`, the message is **dropped**, and when it evaluates to `false`, the message passes through. To keep only anomalies (`temp > 85.0 || vib > 7.5`), your filter expression must drop normal readings (`$1 <= 85.0 && $2 <= 7.5`).

## ✅ Tasks

1. **Create the Schema Registry, Device Registry Namespace & Initialize AIO.** *(~7 min)*
   - Create an **Azure IoT Operations Schema Registry** (`az iot ops schema registry create`) in `$ARC_LOCATION` (`westeurope`) backed by your HNS-enabled Storage Account (`$SCHEMA_STORAGE_ACCOUNT`).
   - Create an **Azure Device Registry Namespace** (`az iot ops ns create`) in `$ARC_LOCATION` (`westeurope`).
   - Run `az iot ops init` on your cluster to install the foundational `cert-manager` (`microsoft.certmanagement`) and `azure-secret-store` Arc extensions.

2. **Deploy the Azure IoT Operations Instance.** *(~8 min)*
   - Run `az iot ops create` in `$ARC_LOCATION` (`westeurope`) referencing both `--sr-resource-id` and `--ns-resource-id`, using the `Low` memory profile (`1` frontend replica, `1` backend partition) so plenty of CPU/RAM remains available for Foundry Local in Challenge 03.
   - Confirm that all pods in the `azure-iot-operations` namespace (`aio-broker-*`, `aio-dataflow-*`, `adr-schema-registry-*`) reach `Running`.

3. **Configure the Internal MQTT `BrokerListener` & Anomaly `Dataflow`.** *(~2 min)*
   - Inspect and apply [`resources/manifests/01-iot-sim/aio-anomaly-dataflow.yaml`](../resources/manifests/01-iot-sim/aio-anomaly-dataflow.yaml).
   - Verify that the `aio-broker-internal` Kubernetes Service (`port: 1883`, `nodePort: 31883`) and the `cnc-anomaly-router` `Dataflow` are created in `azure-iot-operations`.

4. **Deploy the Manufacturing Telemetry Simulator & Verify Anomaly Routing.** *(~3 min)*
   - Apply [`resources/manifests/01-iot-sim/telemetry-simulator.yaml`](../resources/manifests/01-iot-sim/telemetry-simulator.yaml) to start publishing CNC telemetry every 5 seconds to `factory/line1/telemetry` (with a thermal/vibration anomaly injected every 6th tick).
   - Use `mosquitto_sub -h 127.0.0.1 -p 31883 -t "factory/line1/anomalies" -C 1 -v` to confirm that `NOMINAL` ticks are dropped and only `WARNING_THERMAL_VIBRATION_DRIFT` events arrive on `factory/line1/anomalies`.

## 📊 Key Parameters & Technical Reference

| Parameter / Resource | Value / Hint | Why It Matters |
| :--- | :--- | :--- |
| **Schema Registry & Device Registry Region** | `--location westeurope` (`$ARC_LOCATION`) | Must match the `location` of your Azure Arc `connectedClusters` resource from Challenge 01 to avoid `HostResourceRegionMismatch`. |
| **Device Registry Namespace (`--ns-resource-id`)** | `az iot ops ns create` | Required alongside `--sr-resource-id` by `az iot ops create` (`v1.4+`). |
| **MQTT Broker Memory Profile** | `--broker-mem-profile Low` (1 frontend, 1 backend partition) | Leaves ample CPU and memory headroom on the 16-vCPU/64-GiB node for Foundry Local and `Phi-4-mini` in Challenge 03. |
| **AIO `BrokerListener` Service Type** | `serviceType: NodePort` (`port: 1883`, `nodePort: 31883`) | The `default` listener already claims `serviceType: ClusterIp`. Using `NodePort` creates `aio-broker-internal.azure-iot-operations.svc.cluster.local:1883` internally AND exposes `127.0.0.1:31883` on the host for quick `mosquitto_sub` verification. |
| **AIO Dataflow Filter Semantics** | `expression: "$1 <= 85.0 && $2 <= 7.5"` | In Azure IoT Operations Dataflows, `filter` is a **drop filter**: messages where `expression` evaluates to `true` are **dropped**, and `false` passes through. |

## 🤔 Grounding & Architecture Questions

1. **Why do we filter normal sensor ticks inside an Azure IoT Operations Dataflow rather than forwarding every 5-second MQTT message to the Edge AI Agent?**
2. **Why did `aio-broker-webhook` reject creating a second `BrokerListener` with `serviceType: ClusterIp`, and how does a `NodePort` service still provide an internal cluster DNS name (`aio-broker-internal.azure-iot-operations.svc.cluster.local:1883`)?**

## ✅ Success Criteria

* `kubectl get pods -n azure-iot-operations` shows all broker, dataflow, and schema-registry pods `Running`.
* `kubectl get brokerlistener,dataflow -n azure-iot-operations` lists `aio-broker-internal` and `cnc-anomaly-router`.
* `kubectl logs -n edge-agents deploy/manufacturing-telemetry-simulator` shows telemetry published every 5 seconds.
* Subscribing to `factory/line1/anomalies` prints only readings with `bearingTempC > 85.0` or `vibrationMmPerSec > 7.5`.

![Challenge 02 — Azure Portal Azure IoT Operations Instance Overview](../img/portal-aio-instance-overview.png)

![Challenge 02 — Live Azure Bastion Terminal: Broker, Dataflow & Anomaly Stream](../img/bastion-challenge-02-aio-anomaly.png)

![Challenge 02 — Azure IoT Operations & Anomaly Dataflow Filtering](../img/challenge-02-aio-and-dataflow.png)

## 📚 Learning Resources

* [Deploy Azure IoT Operations to an Arc-enabled Kubernetes cluster](https://learn.microsoft.com/azure/iot-operations/deploy-iot-ops/howto-deploy-iot-operations)
* [Configure MQTT Broker listeners in Azure IoT Operations](https://learn.microsoft.com/azure/iot-operations/manage-mqtt-broker/howto-configure-brokerlistener)
* [Filter data in an Azure IoT Operations Dataflow](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-dataflow-filter)

## 🔓 Solution — Spoiler Warning

[Solution Steps](../walkthrough/challenge-02/solution-02.md)

[← Previous Challenge](challenge-01.md) | [Next Challenge →](challenge-03.md) | [Back to Overview](../Readme.md)
