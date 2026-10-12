# Challenge 4 walkthrough - Maintenance Scheduler & Parts Ordering Agents

**[Back to challenge](../../challenges/challenge-04.md)**

This walkthrough adds the exact commands, expected output, and a validation checklist for [Challenge 4](../../challenges/challenge-04.md). It does not repeat the background, scenario, or objective — see the challenge file for that.

## Prerequisites

* Challenges 1-3 completed: `.env` populated, all prior agents working.
* Working directory: `src/` (all commands below assume you're already there).

## Task 1: Maintenance Scheduler Agent

### Task 1.1: Run the agent

```bash
cd src
python agents/maintenance_scheduler_agent.py wo-2024-456
```

<details>
<summary>Expected output</summary>

```text
📊 Agent Framework tracing enabled (Azure Monitor)
   Traces sent to: InstrumentationKey=...
   View in Azure AI Foundry portal: https://ai.azure.com -> Your Project -> Tracing

   Checking existing agent versions in portal...
   Found 0 existing versions
   Creating new version (will be version #1)...
   Registering MaintenanceSchedulerAgent in Azure AI Foundry portal...
   ✅ New version created!
      Agent ID: MaintenanceSchedulerAgent:1

1. Retrieving work order...
   ✓ Work Order: wo-2024-456
   Machine: machine-004
   Priority: high

2. Analyzing historical maintenance data...
   ✓ Found 2 historical maintenance records

3. Checking available maintenance windows...
   ✓ Found 14 available windows in next 14 days

4. Running AI predictive analysis...
   Using persistent chat history for machine: machine-004
   ✓ Analysis complete!

=== Predictive Maintenance Schedule ===
Schedule ID: sched-1769021150.421991
Machine: machine-004
Scheduled Date: 2026-01-22 22:00
Window: 22:00 - 06:00
Production Impact: Low
Risk Score: 82/100
Failure Probability: 67.0%
Recommended Action: URGENT

Reasoning:
The work order is marked as high priority... [full reasoning text explaining the risk score]

5. Saving maintenance schedule...
   ✓ Schedule saved to Cosmos DB

6. Updating work order status...
   ✓ Work order status updated to 'Scheduled'

✓ Predictive Maintenance Agent completed successfully!
```

</details>

Run the same work order ID a second time and confirm the log line `Using persistent chat history for machine: machine-004` appears (agent memory recalling the prior run).

## Task 2: Parts Ordering Agent

### Task 2.1: Run the agent

```bash
python agents/parts_ordering_agent.py wo-2024-456
```

<details>
<summary>Expected output (parts need ordering)</summary>

```text
1. Retrieving work order...
   ✓ Work Order: wo-2024-456
   Machine: machine-004
   Required Parts: 2
   Priority: high

2. Checking inventory status...
   ✓ Found 2 inventory records

⚠️  2 part(s) need to be ordered:
   - Load Cell 2kN (Qty: 1)
   - Rotary Encoder 5000ppr (Qty: 1)

3. Finding suppliers...
   ✓ Found 2 potential suppliers

4. Running AI parts ordering analysis...
   Using persistent chat history for work order: wo-2024-456
   ✓ Parts order generated!

=== Parts Order ===
Order ID: PO-58689c01
Work Order: wo-2024-456
Supplier: Industrial Parts Co (ID: SUP-001)
Expected Delivery: 2024-06-17
Total Cost: $505.00
Status: Pending

Order Items:
  - Load Cell 2kN (#TUM-LC-2KN)
    Qty: 1 @ $320.00 = $320.00
  - Rotary Encoder 5000ppr (#TUM-ENC-5000)
    Qty: 1 @ $185.00 = $185.00

5. Saving parts order...
   ✓ Order saved to SCM system

6. Updating work order status...
   ✓ Work order status updated to 'PartsOrdered'
```

</details>

```bash
python agents/parts_ordering_agent.py wo-2024-468
```

<details>
<summary>Expected output (parts are available)</summary>

```text
1. Retrieving work order...
   ✓ Work Order: wo-2024-468
   Machine: machine-005
   Required Parts: 2
   Priority: medium

2. Checking inventory status...
   ✓ Found 2 inventory records

✓ All required parts are available in stock!
No parts order needed.

3. Updating work order status...
   ✓ Work order status updated to 'Ready'

✓ Parts Ordering Agent completed successfully!
```

</details>

## Task 3: Azure AI tracing and observability

### Task 3.1: Generate traces

```bash
python run-batch.py
```

Expected result: the script processes five work orders through both agents (ten total agent runs) and prints a per-work-order summary with no unhandled exceptions.

### Task 3.2-3.3: View traces

There can be a delay of **2-5 minutes** before metrics and traces appear in the Foundry portal — this is normal, since telemetry data is batched before being displayed.

## Troubleshooting

* **I don't see my traces in the Foundry portal:**
  1. Wait a few minutes and refresh the portal.
  2. Check Application Insights directly — traces often appear there faster. Go to your Application Insights resource in the Azure portal and use **Transaction search** or **Logs** to query traces immediately.
  3. Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is set correctly in `.env` and exported in your shell.
* **`run-batch.py` fails partway through:** re-run it — it's safe to re-run against the same sample work orders since each agent invocation reads current state from Cosmos DB rather than assuming a specific starting point.
* **Chat history doesn't seem to persist between runs:** confirm you're using the same work order ID (for the Parts Ordering Agent) or machine ID (for the Maintenance Scheduler Agent) across runs — memory is keyed per machine/work order, not globally.

## Validation checklist

* [ ] `maintenance_scheduler_agent.py wo-2024-456` produces a schedule with a risk score, failure probability, and recommended action, and updates the work order status to `Scheduled`.
* [ ] Running the same command again shows the agent recalling prior chat history for that machine.
* [ ] `parts_ordering_agent.py wo-2024-456` generates a parts order with a supplier, total cost, and delivery date, and updates the work order status to `PartsOrdered`.
* [ ] `parts_ordering_agent.py wo-2024-468` finds all parts in stock and updates the work order status to `Ready` instead.
* [ ] `run-batch.py` completes and generates ten agent runs.
* [ ] Traces for both agents are visible in the Foundry portal's **Monitor** tab, and in Application Insights via **Open in Azure Monitor**.

**Next:** [Challenge 5 walkthrough](../challenge-05/solution-05.md)
