# Azure Copilot MicroHack — E2E Test Suite

Automated end-to-end tests for all 7 MicroHack Azure Copilot challenges using [Playwright](https://playwright.dev).

This guide covers two approaches to running the tests:

1. **Standard Playwright** — `npx playwright test` with saved auth state
2. **GitHub Copilot–assisted** — using GitHub Copilot CLI or VS Code Copilot to run, modify, and extend the tests interactively

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Node.js 18+ | [nodejs.org](https://nodejs.org) |
| Azure account | With MicroHack infrastructure deployed (see parent `Readme.md`) |
| Microsoft Edge | Tests use the `msedge` channel |
| `AZURE_SUBSCRIPTION_ID` | Set as env var for subscription-scoped tests |
| `AZURE_USER_EMAIL` | (Optional) Azure AD email for SSO login |

## Quick Start

```bash
cd tests
npm install
npx playwright install msedge
```

---

## Authentication

Azure portal uses **WAM (Web Account Manager)** for authentication on corporate machines. Playwright automation mode disables WAM, which means FIDO2/passwordless flows won't work headlessly.

### Option A: Interactive session capture

```bash
npm run auth:setup
```

This opens the Azure portal in Edge — sign in manually, then press **Resume** in the Playwright inspector. Your session is saved to `.auth/state.json`.

### Option B: Capture from existing Edge session

If you're already logged into the Azure portal in Edge:

```bash
node capture-auth.mjs
```

This launches Edge with your existing profile and exports the auth state automatically.

### Option C: GitHub Copilot CLI with MCP Browser *(Recommended)*

The **GitHub Copilot CLI MCP Playwright browser** inherits your system's WAM session — no manual auth steps required. See [Testing with GitHub Copilot](#testing-with-github-copilot) below.

---

## Running Tests

### Standard Playwright

```bash
# All challenges
npm test

# Headed (visible browser)
npm run test:headed

# Single challenge
npm run test:challenge1   # Basics
npm run test:challenge2   # Deployment Agent
npm run test:challenge3   # Observability Agent
npm run test:challenge4   # Optimization Agent
npm run test:challenge5   # Resiliency Agent
npm run test:challenge6   # Troubleshooting Agent
npm run test:challenge7   # Capstone

# Debug mode (step through with inspector)
npm run test:debug
```

### Test Reports

After a run, Playwright generates:

- **HTML report** — `npx playwright show-report` (opens in browser)
- **JSON results** — `test-results/results.json`
- **Screenshots/videos** — captured automatically on failure

> **Note:** All test output (screenshots, reports, `test-results/`) is `.gitignore`d and should never be committed.

---

## Testing with GitHub Copilot

GitHub Copilot can assist with the entire testing workflow — from running the test suite to writing new tests, debugging failures, and extending coverage.

### Approach 1: GitHub Copilot CLI (Terminal)

The GitHub Copilot CLI has a built-in **MCP Playwright browser** that can interact with the Azure portal directly. This is the most effective approach because it inherits your system's WAM/SSO authentication automatically.

#### Step 1: Start a testing session

Open a terminal and start GitHub Copilot CLI:

```bash
ghcs   # or: github-copilot-cli
```

#### Step 2: Ask Copilot to run the challenges

Use natural language to instruct Copilot to test specific scenarios:

```
> Navigate to https://portal.azure.com, open Copilot, enable Agent mode,
  and ask: "Deploy a web app with App Service and SQL Database using Terraform."
  Verify the response includes a deployment plan with cost estimates.
```

Copilot will:
1. Open the portal via MCP Playwright browser (auto-authenticated)
2. Navigate to Copilot, toggle Agent mode
3. Send the prompt and wait for the response
4. Validate the response content
5. Capture screenshots as evidence

#### Step 3: Run full challenge workflows

For comprehensive testing, ask Copilot to work through entire challenges:

```
> Test Challenge 7 (Capstone) end-to-end:
  Phase 1: Deploy e-commerce infra (App Service + Cosmos DB + Redis)
  Phase 2: Configure monitoring alerts
  Phase 3: Run cost optimization
  Phase 4: Check zone resiliency
  Phase 5: Troubleshoot a checkout timeout
  Phase 6: Generate an operational runbook
  Take screenshots at each phase.
```

#### Step 4: Generate a test report

```
> Create an HTML test coverage report showing results for all 7 challenges
  with screenshots from the test run.
```

### Approach 2: VS Code with GitHub Copilot Extension

Use Copilot Chat in VS Code to write, modify, and debug Playwright tests.

#### Writing new tests

Open a spec file and use Copilot Chat (`Ctrl+I`):

```
@workspace Write a Playwright test that opens Copilot in Agent mode,
asks it to troubleshoot a Cosmos DB timeout, and verifies the response
includes diagnostic actions like checking firewall rules and connection strings.
Use the CopilotPage helper from helpers/copilot-page.ts.
```

#### Debugging failures

When a test fails, share the error with Copilot:

```
@workspace This test is failing with "Timeout waiting for article count to increase."
The Copilot iframe loads but the response never appears. What could be wrong?
```

Common fixes Copilot may suggest:
- Increase `sendMessage` timeout for agent-mode prompts
- Check if the Copilot iframe name changed (inspect the portal)
- Verify `.auth/state.json` is still valid (tokens expire)

#### Extending coverage

Ask Copilot to generate tests for scenarios not yet covered:

```
@workspace Add a test to challenge-03-observability.spec.ts that
investigates Azure Monitor alerts fired in the last 24 hours with
Copilot in Agent mode and verifies it returns alert details or
a "no alerts" message.
```

### Approach 3: GitHub Copilot in Agent Mode (VS Code)

Use Copilot's Agent Mode (`@terminal`) to run and iterate on tests:

```
@terminal Run the Challenge 2 deployment tests and show me any failures.
```

```
@terminal The test "Task 4: Generate Terraform code" is timing out.
Increase the timeout to 180 seconds and retry.
```

---

## Test Architecture

```
tests/
├── .gitignore                  # Excludes test output from source control
├── capture-auth.mjs            # Auth state capture from existing Edge session
├── helpers/
│   └── copilot-page.ts         # Page Object Model for Copilot UI
├── specs/
│   ├── auth.setup.ts           # Interactive auth setup (run once)
│   ├── challenge-01-basics.spec.ts
│   ├── challenge-02-deployment.spec.ts
│   ├── challenge-03-observability.spec.ts
│   ├── challenge-04-optimization.spec.ts
│   ├── challenge-05-resiliency.spec.ts
│   ├── challenge-06-troubleshooting.spec.ts
│   └── challenge-07-capstone.spec.ts
├── package.json
├── playwright.config.ts
└── README.md                   # This file
```

### CopilotPage — Page Object Model

All Copilot UI renders inside an iframe (`CopilotFluentAI.ReactView`). The `CopilotPage` class abstracts this so tests interact with Copilot as if it were a first-class page.

Key methods:

| Method | Description |
|--------|-------------|
| `goto()` | Navigate to Azure portal, handle SSO login |
| `openCopilot()` | Open the Copilot side pane |
| `enableAgentMode()` | Toggle Agent mode on (required for C2–C7) |
| `switchToFullscreen()` | Switch from sidecar to fullscreen mode |
| `sendMessage(msg, opts)` | Send a prompt and wait for the response article |
| `waitForResponseComplete()` | Wait for reasoning/processing to finish |
| `openContextPicker()` | Open the "Attach context" panel |
| `getLastResponseText()` | Get the text content of the latest response |
| `responseContains(text)` | Check if the response includes specific text |
| `startNewChat()` | Clear conversation and start fresh |
| `navigateToResourceGroup(rg)` | Navigate to a specific resource group |

### Key Design Decisions

- **Sequential execution** (`workers: 1`) — tests share a single Azure portal session
- **Generous timeouts** (90–180s) — Copilot agent processing can take 15–120+ seconds
- **Regex-based assertions** — response content is validated with pattern matching, not exact strings, since AI responses are non-deterministic
- **No retries** — Copilot responses are stateful; retrying mid-conversation would produce inconsistent results

---

## Test Coverage — 37 Tests Across 7 Challenges

| Challenge | Tests | What is Tested |
|-----------|-------|----------------|
| **1 — Basics** | 6 | Open Copilot panel, ask questions, navigate resources, generate scripts, get recommendations, attach context |
| **2 — Deployment** | 5 | Enable Agent mode, request deployment plan, refine plan, generate Terraform, review artifacts |
| **3 — Observability** | 5 | Alert investigation, resource-scoped queries, health metrics, slow response diagnosis, Monitor alerts |
| **4 — Optimization** | 5 | Cost savings discovery, deep-dive recommendations, visualization, optimization scripts, savings summary |
| **5 — Resiliency** | 5 | Zone resiliency assessment, configure resiliency, backup coverage, vault management, improvement plan |
| **6 — Troubleshooting** | 5 | VM connectivity, database timeouts, AKS pod health, one-click fix, support request creation |
| **7 — Capstone** | 6 | Full e-commerce lifecycle: deploy → monitor → optimize → resiliency → troubleshoot → runbook |

---

## Troubleshooting

### Auth token expired
```
Error: storageState: .auth/state.json not found
```
Re-run `npm run auth:setup` to capture a fresh session.

### Copilot iframe not found
```
Error: locator.waitFor: Timeout
```
The Copilot iframe name may have changed. Inspect the portal with DevTools (`F12`) and look for `iframe[name*="Copilot"]`.

### Agent mode timeout
```
Error: expect(copilotArticles).toHaveCount — Timeout
```
Agent responses can take 2+ minutes for complex prompts. Increase the timeout in the test's `sendMessage()` call.

### WAM/FIDO2 login wall
```
Page redirects to login.microsoft.com/common/fido/get
```
Playwright automation disables WAM. Use `node capture-auth.mjs` to capture auth from your existing Edge session, or use the **GitHub Copilot CLI MCP browser** approach which inherits WAM automatically.

### Tests pass locally but fail in CI
Azure Copilot is behind Azure AD — CI pipelines need a valid service principal or managed identity with portal access. Consider running tests in a self-hosted runner with an authenticated Edge session.
