# Challenge 2 walkthrough - Anomaly Detection and Fault Diagnosis Agents

**[Back to challenge](../../challenges/challenge-02.md)**

This walkthrough adds the exact commands, expected output, and a validation checklist for [Challenge 2](../../challenges/challenge-02.md). It does not repeat the background, scenario, or objective — see the challenge file for that.

## Prerequisites

* Challenge 1 completed: `.env` populated and exported in your current shell.
* You are working from the repository root inside the Codespace, with `.venv` activated.

## Task 1: Create and test the initial Anomaly Classification Agent

### Task 1.2: Run the code

```bash
python src/agents/anomaly_classification_agent.py
```

<details>
<summary>Expected output</summary>

```text
✅ Created Anomaly Classification Agent: fc0eed0f-923e-4be7-8a28-916f8b85ed79

🧪 Testing the agent with a sample query...
✅ Agent response: {
  "status": "medium",
  "alerts": [
    {
      "name": "curing_temperature",
      "severity": "warning",
      "description": "curing_temperature value of 179.2°C exceeds warning threshold of 178°C."
    },
    {
      "name": "cycle_time",
      "severity": "warning",
      "description": "cycle_time value of 14.5 minutes exceeds warning threshold of 14 minutes."
    }
  ],
  "summary": {
    "totalRecordsProcessed": 2,
    "violations": { "critical": 0, "warning": 2 }
  }
}

Summary:
Both anomalies for machine-001 indicate warning-level threshold violations:
- The curing_temperature (179.2°C) is above the warning threshold, which could affect tire quality.
- The cycle_time (14.5 min) is also above its warning threshold, indicating curing process deviation.
Immediate maintenance review is recommended to prevent escalation to critical levels.
```

</details>

## Task 2: Equip the agent with MCP tools

### Task 2.1: Test the Machine API

Expected output for each `curl` command is a JSON array or object (not an empty body or an HTML error page). For example, `curl .../machine/machine-001` returns:

```json
{
  "id": "machine-001",
  "type": "tire_curing_press",
  "status": "operational",
  "operatingHours": 12450
}
```

If you get `401`/`403`, double-check `APIM_SUBSCRIPTION_KEY` was exported correctly from `.env`.

### Task 2.2: Expose APIs as MCP servers

After creating both MCP servers, your `.env` file should contain two new lines:

```text
MACHINE_MCP_SERVER_ENDPOINT="https://<your-apim-name>.azure-api.net/machine-mcp/sse"
MAINTENANCE_MCP_SERVER_ENDPOINT="https://<your-apim-name>.azure-api.net/maintenance-mcp/sse"
```

(the exact path segment after your APIM hostname depends on the **Name** you gave each MCP server).

### Task 2.4: Test the agent with MCP tools

```bash
python src/agents/anomaly_classification_agent_mcp.py
```

<details>
<summary>Expected output</summary>

```text
✅ Connection 'machine-data-connection' created successfully.
✅ Connection 'maintenance-data-connection' created successfully.
✅ Created Anomaly Classification Agent: AnomalyClassificationAgent:2

🧪 Testing the agent with a sample query...
✅ Agent response: {
  "status": "medium",
  "alerts": [
    {
      "name": "curing_temperature",
      "severity": "warning",
      "description": "curing_temperature exceeded warning threshold with value 179.2°C; warning threshold is 178°C."
    }
  ],
  "summary": {
    "totalRecordsProcessed": 2,
    "violations": {
      "critical": 0,
      "warning": 1
    }
  }
}

Summary:
Out of 2 anomaly records reviewed for machine-001 (Tire Curing Press A1), one violation was found. The curing_temperature metric exceeded the warning threshold (value: 179.2°C, threshold: 178°C), which may affect tire quality. No critical alerts were detected. Cycle time did not have available threshold data and was not evaluated for violations. Maintenance attention is advised for the elevated curing temperature.
```

</details>

If the script instead raises `Connection 'xxx-connection' not found`, see [Troubleshooting](#troubleshooting) below.

## Task 3: Understand root cause with the Fault Diagnosis Agent and Foundry IQ

### Task 3.3: Create the Fault Diagnosis Agent

```bash
python src/agents/fault_diagnosis_agent.py
```

<details>
<summary>Expected output</summary>

```text
✅ Agent response: {
    "MachineId": "machine-001",
    "FaultType": "curing_temperature_excessive",
    "RootCause": "Heating element malfunction",
    "Severity": "High",
    "DetectedAt": "2024-06-14T00:00:00Z",
    "Metadata": {
        "MostLikelyRootCauses": [
            "Heating element malfunction",
            "Temperature sensor drift",
            "Steam pressure set too high",
            "Thermostat failure",
            "Inadequate cooling water flow"
        ],
        "ObservedCuringTemperature": 179.2,
        "ThresholdTemperature": 178,
        "machineType": "tire_curing_press",
        "maintenanceHistory": [
            {
                "date": "2024-11-01",
                "type": "preventive",
                "description": "Bladder inspection and heating element check",
                "technician": "John Smith"
            }
        ],
        "KBReference": "Tire Curing Press - Curing Temperature Excessive",
        "KBArticleId": "a19e61459ea9_..."
    }
}
```

</details>

## Troubleshooting

* **`Connection 'xxx-connection' not found` when running an MCP-enabled agent:** the MCP server endpoint or connection wasn't created yet, or `.env` wasn't reloaded after adding the MCP endpoint entries. Re-run `export $(grep -v '^#' .env | xargs)` and confirm `echo "$MACHINE_MCP_SERVER_ENDPOINT"` prints a URL.
* **The agent doesn't show up in the new Foundry portal:** confirm the portal toggle in the upper-right corner is switched to the new experience, and that you're viewing the same Foundry project referenced by `AZURE_AI_PROJECT_ENDPOINT` in `.env`.
* **`PermissionDenied` when running the agent creation scripts:** your account may still be missing the `Azure AI Developer` / `Foundry User` role assignments from Challenge 1. Check with your coach, then re-run `az login --use-device-code` after roles are assigned.
* **`create_knowledge_base.ipynb` fails to find a kernel:** when prompted to select an environment, pick the user-installed Python environment (the one created by `uv sync`), not a system Python.

## Validation checklist

* [ ] `anomaly_classification_agent.py` runs and classifies the sample anomaly with a warning-level summary.
* [ ] Machine API and Maintenance API respond successfully to direct `curl` calls.
* [ ] `MACHINE_MCP_SERVER_ENDPOINT` and `MAINTENANCE_MCP_SERVER_ENDPOINT` are set in `.env` and exported.
* [ ] `anomaly_classification_agent_mcp.py` runs and produces the same classification using the MCP tools.
* [ ] Both agent versions are visible under the **Build** tab in the Foundry portal.
* [ ] `create_knowledge_base.ipynb` completes and creates a knowledge source and knowledge base for the machine wiki.
* [ ] `fault_diagnosis_agent.py` runs after the `MCPTool` placeholder is filled in, and the response includes a root cause, severity, and a `KBReference`/`KBArticleId` from the machine wiki.

**Next:** [Challenge 3 walkthrough](../challenge-03/solution-03.md)
