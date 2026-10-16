# Challenge 5 walkthrough - Multi-Agent Orchestration with Aspire

**[Back to challenge](../../challenges/challenge-05.md)**

This walkthrough adds prerequisites, exact commands, expected output, and a validation checklist for [Challenge 5](../../challenges/challenge-05.md). It does not repeat the background, scenario, or objective — see the challenge file for that.

## Prerequisites

* Challenges 1-4 completed. In particular, the **Anomaly Classification** and **Fault Diagnosis** agents from Challenge 2 must be registered in Foundry Agent Service (running `aspire run` does not create them for you).
* `.env` populated and exported in the shell you'll run `aspire run` from — Aspire reads environment variables from the shell that launches it, not from a `.env` file automatically.
* The Aspire CLI installed (see [Troubleshooting](#troubleshooting) if `aspire` is not found).

## Task 1: Start Aspire

```bash
export $(grep -v '^#' .env | xargs)   # from the hack root, if not already exported
cd src/agent-workflow
aspire run
```

Expected result: Aspire prints a resource table listing each service (`app` / `frontend` / others) with a `Starting`/`Running` state, followed by clickable `dashboard` and `frontend` links in the terminal output.

## Task 2: Make the workflow API port public (Codespaces)

After forwarding port `5231` as **Public**, confirm it by opening `https://<your-codespace-name>-5231.app.github.dev/` (the exact hostname is shown in the *Ports* tab) in a new browser tab — you should get a JSON or plain-text response rather than a connection error.

## Task 3: Open the frontend

If Alt+Click doesn't open the link in your terminal, copy the URL shown next to `frontend` in the Aspire output and paste it into a new browser tab manually.

## Task 4: Run the workflow

Expected step order and terminal states as the workflow runs:

1. **Anomaly Classification Agent** — `queued` → `working` → `done`
2. **Fault Diagnosis Agent** — `queued` → `working` → `done`
3. **Repair Planner Agent** — `queued` → `working` → `done`
4. **Maintenance Scheduler Agent** — `queued` → `working` → `done`
5. **Parts Ordering Agent** — `queued` → `working` → `done`

If any step shows `error`, expand its details panel for the tool-call output and exception message, then see [Troubleshooting](#troubleshooting).

## Task 5: View the dashboard

In the **Console** view, you should see log lines from each Python agent process (`app`) and the .NET workflow host, interleaved by timestamp. In the **Traces** view, selecting a trace for the workflow run shows a waterfall with one span per agent invocation — the total duration is the sum of all five agent calls plus orchestration overhead.

## Troubleshooting

* **`aspire` / `aspire run` is not found:**

  ```bash
  curl -fsSL https://aspire.dev/install.sh | bash -s
  ```

  Restart your shell (or open a new terminal) afterwards so the updated `PATH` takes effect.

* **`aspire run` starts but agent calls fail with 401/`PermissionDenied`:** your identity is likely missing the `Cognitive Services OpenAI Contributor` (or `Cognitive Services OpenAI User`) role on the Azure OpenAI resource. Confirm with:

  ```bash
  az role assignment list --assignee "$(az ad signed-in-user show --query id -o tsv)" --scope "$AZURE_AI_PROJECT_RESOURCE_ID" -o table
  ```

* **The frontend loads but calls to `/api` fail:** re-check that port `5231` is forwarded and set to **Public**, and check the Aspire dashboard's **Console** view for CORS or connection errors from the `frontend` resource.
* **The workflow can't find your Foundry project endpoint:** confirm `AZURE_AI_PROJECT_ENDPOINT` is set in the exact shell session that ran `aspire run` (`echo "$AZURE_AI_PROJECT_ENDPOINT"`) — if you exported `.env` in a different terminal tab, `aspire run` won't see it.
* **A step fails immediately with "agent not found":** confirm the corresponding agent from Challenge 2 (or 3/4) was actually run at least once so it's registered in Foundry Agent Service — the Aspire workflow calls existing agents, it does not create them.

## Validation checklist

* [ ] `aspire run` starts all resources without errors.
* [ ] Port `5231` is forwarded and set to **Public**.
* [ ] The frontend loads in the browser and shows the Factory Workflow UI.
* [ ] Triggering the workflow runs all five agent steps through to `done`.
* [ ] The Aspire dashboard's **Console** view shows interleaved logs from all resources.
* [ ] The Aspire dashboard's **Traces** view shows a waterfall with one span per agent call for the triggered run.

**Next:** [Finish](../../challenges/finish.md)
