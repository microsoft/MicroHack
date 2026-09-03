# Challenge 1 — Onboard a New LLM Backend

**[Home](../README.md)** - [Next Challenge →](challenge-02.md)

## 🎯 Objective

Use the **🏰 Citadel Backend Contracts** notebook to onboard a new AI backend and its
routing logic into the Citadel Governance Hub: configure an LLM backend endpoint and
authentication, generate the Bicep parameter file, deploy the backend pool and policy
fragments, then prove it works through multiple API formats.

## 🧭 Context

This challenge runs entirely against **Hub** resources — the APIM instance and its
backend pools sit in front of every model your governance hub serves. Your lab resources
are already deployed for you, so Part A below is about pointing your machine at them:
sign in to Azure, then write a `.env` file that every workshop notebook reads.

## ✅ Tasks

### Part A — Set up your notebook environment (10 min)

Your lab resources are **already deployed**. You do not run `azd up`. This section
connects your machine to them, and it applies to all nine challenges — do it once.

#### A.1 — Sign in to Azure

Your MicroHack dashboard's **Credentials** tab gives you an Entra username and a
**Temporary Access Pass (TAP)**, which is used instead of a password and expires at the
end of the event.

1. Open the **Azure Portal** in a **private/incognito** window (so it doesn't collide
   with your corporate account) and sign in with the dashboard's *Entra ID Username*,
   entering the *Entra ID TAP* when asked for a password. Complete any prompts.
2. Sign in from your terminal — the notebooks use `DefaultAzureCredential`, so this
   session is what authenticates their Azure calls:

   ```bash
   az login --tenant emea.microhack.cloud
   az account set --subscription <SubscriptionId from the dashboard>
   az account show --output table
   ```

   If the browser handoff misbehaves, use `az login --use-device-code --tenant emea.microhack.cloud`.

> [!WARNING]
> If you are already signed in to another Azure account, `DefaultAzureCredential` may
> pick it up instead. If notebook cells return 401/403, run `az account show` and
> confirm you are the lab user.

#### A.2 — Find your resource token

Every resource in your lab is named with the same random token, and the `.env` values
are built from it. In the portal, open your resource group (`rg-labuser-00XX`) and find
the AI Foundry account named **`aif-hub-<TOKEN>`** — everything after the prefix is your
token. For example `aif-hub-fd79f0b6fee89` means the token is `fd79f0b6fee89`.

From the CLI:

```bash
az cognitiveservices account list -g <your-rg> \
  --query "[?starts_with(name,'aif-hub-')].name" -o tsv
```

#### A.3 — Fill in `.env`

```bash
cd challenges/workshop
cp .env.template .env
```

Open `.env` and set the values below, replacing `<TOKEN>` throughout. The first three
come straight from the dashboard / portal Overview blade; the rest are derived from the
token.

```bash
AZURE_RESOURCE_GROUP=rg-labuser-00XX
AZURE_LOCATION=swedencentral          # compact form, not "Sweden Central"
AZURE_SUBSCRIPTION_ID=<SubscriptionId>

SPOKE_RESOURCE_GROUP=rg-labuser-00XX  # same RG — this lab uses one resource group
SPOKE_KEY_VAULT_NAME=kv-spoke-<TOKEN>
SPOKE_AI_FOUNDRY_ACCOUNT_NAME=aif-spoke-<TOKEN>
SPOKE_AI_FOUNDRY_PROJECT_NAME=citadel-agents-project
SPOKE_ACR_NAME=acrcitadel<TOKEN>
SPOKE_ACR_LOGIN_SERVER=acrcitadel<TOKEN>.azurecr.io
A2A_FOUNDRY_ACCOUNT_NAME=aif-spoke-<TOKEN>
```

Challenges 1-6 need only the first four values plus `LLM_BACKEND_CONFIG`.

#### A.4 — Fill in `LLM_BACKEND_CONFIG`

This one is a single line of JSON describing your gateway's backend and its six models.
Paste the block below as **one line**, with `<TOKEN>` replaced in **both** places:

```
LLM_BACKEND_CONFIG=[{"backendId":"aif-hub-<TOKEN>","backendType":"ai-foundry","endpoint":"https://aif-hub-<TOKEN>.openai.azure.com","authScheme":"managedIdentity","authType":"managed-identity","priority":1,"weight":100,"supportedModels":[{"name":"gpt-4.1","sku":"GlobalStandard","capacity":20,"modelFormat":"OpenAI","modelVersion":"2025-04-14","retirementDate":"2027-04-14"},{"name":"gpt-5.4-mini","sku":"GlobalStandard","capacity":20,"modelFormat":"OpenAI","modelVersion":"2026-03-17","retirementDate":"2027-09-21"},{"name":"gpt-5.2","sku":"GlobalStandard","capacity":20,"modelFormat":"OpenAI","modelVersion":"2025-12-11","retirementDate":"2027-06-08"},{"name":"text-embedding-3-large","sku":"GlobalStandard","capacity":20,"modelFormat":"OpenAI","modelVersion":"1","retirementDate":"2028-02-09"},{"name":"Mistral-Large-3","sku":"GlobalStandard","capacity":20,"modelFormat":"Mistral AI","modelVersion":"1","retirementDate":"2099-12-31"},{"name":"Phi-4","sku":"GlobalStandard","capacity":1,"modelFormat":"Microsoft","modelVersion":"7","retirementDate":"2099-12-31"}]}]
```

> [!IMPORTANT]
> Three things break this value, and all three fail with a confusing error pointing
> ~1000 characters away from the real mistake:
>
> - **Line breaks.** It must be one unbroken line. Turn off word wrap before pasting.
> - **Surrounding quotes.** Do not wrap the value in `"` or `'`.
> - **A missing closing bracket.** The value must end with `}]}]` — four closers, for
>   the model, `supportedModels`, the backend object, and the outer array.
>
> If your editor underlines the line as invalid, ignore it: `.env` is not a JSON file,
> and the `LLM_BACKEND_CONFIG=` prefix alone is enough to confuse a JSON linter.

Alternatively, read the exact value straight out of your deployment outputs and skip the
typing entirely:

```bash
az deployment group list -g <your-rg> -o json \
  | python3 -c "
import json,sys
for d in json.load(sys.stdin):
    for k,v in ((d.get('properties') or {}).get('outputs') or {}).items():
        if k.upper() == 'LLM_BACKEND_CONFIG':
            print('LLM_BACKEND_CONFIG=' + v['value']); raise SystemExit
"
```

#### A.5 — Validate before you start

```bash
cd challenges/workshop
python3 -c "
import json
from pathlib import Path
v=[l.partition('=')[2].strip() for l in Path('.env').read_text().splitlines()
   if l.startswith('LLM_BACKEND_CONFIG=') and l.partition('=')[2].strip()][0]
c=json.loads(v)
print('OK -', len(c), 'backend,', len(c[0]['supportedModels']), 'models')"
```

Expect `OK - 1 backend, 6 models`. If it raises instead, re-read the warning above —
a missing final `]` is by far the most common cause.

`.env` is gitignored, so your credentials stay out of source control.

> [!TIP]
> **If you edit `.env` after starting Jupyter, restart the kernel.** The notebook only
> sets a variable if it isn't already present, so a bad value read at startup will
> persist for the whole session no matter what you change on disk. VS Code also injects
> `.env` into the kernel at start, which has the same effect.

> [!NOTE]
> **Using `azd` instead (optional).** If you prefer the original workshop workflow,
> install `azd` and run
> [`setup-notebook-env.ps1`](../labautomation/README.md#notebook-environment-setup).
> It writes a local `azd` environment that the notebooks fall back to for any key not
> already set in `.env`. This is not required.

To confirm you're ready, run the first setup cell of notebook 1. It should print your
resource group, your location, and `LLM Backends: 1 backend(s) configured`.

### Part B — Run the LLM backend onboarding notebook (30 min)

1. Open
   `workshop/1. llm-backend-onboarding-runner.ipynb`
   in VS Code / Jupyter.
2. Run the notebook's sections in order:
   - `0️⃣ Initialize Notebook Variables`
   - `1️⃣ Verify Azure CLI and Connected Subscription`
   - `2️⃣ Initialize APIM Client Tool`
   - `3️⃣ Extract Current APIM Backend-Pools Configuration`
   - `4️⃣ Discover Managed Identity for APIM Authentication`
   - `5️⃣ Generate LLM Backend Parameter File`
   - `6️⃣ Deploy LLM Backend Onboarding Bicep`
   - `7️⃣ Verify Deployed Configuration`
   - `8️⃣ Verify Get Available Models Policy Fragment`
3. Run the test sections: `🧪 Test GET /deployments (Microsoft Foundry Integration)` and
   `🧪 Test Deployed Models` (Universal LLM API, Azure OpenAI API, Azure OpenAI Python
   SDK, streaming).
4. Read the notebook's own `📊 Results Summary` and `Next Steps` cells at the end.

## 🏁 Success criteria

- [ ] The notebook generated a `.bicepparam` file describing your backend, auth type,
      and per-model metadata.
- [ ] The LLM backend onboarding Bicep deployment succeeded and the backend pool +
      `get-available-models` policy fragment are visible in APIM.
- [ ] `GET /deployments` (Foundry integration) returns your onboarded model.
- [ ] The deployed model responds successfully via the Universal LLM API, the Azure
      OpenAI API, the Azure OpenAI Python SDK, and a streaming request.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| Setup cell raises a missing-key error | That key isn't in your `.env` (and no `azd` environment supplied it) — see Part A. The error message tells you which key is missing and whether a `.env` file was found. |
| `LLM_BACKEND_CONFIG` fails to parse | It must be one unbroken line, with no surrounding quotes, ending in `}]}]`. A missing final bracket is the usual cause — run the validation snippet in Part A.5, which reports the exact position. |
| You fixed `.env` but the notebook reports the old error | The kernel caches environment values from startup. Restart the Jupyter kernel and re-run. |
| `ResourceGroupNotFound` for a resource group you can see in the portal | Your `az` CLI is signed in to a *different* tenant (commonly your corporate account). The portal session and the CLI session are independent. Run `az account show` — if the user isn't `labuser-XXXX@emea.microhack.cloud`, redo the `az login` in Part A.1. |
| `AuthorizationFailed` on `Microsoft.Resources/deployments/...` over a **subscription** scope | You're running an older copy of the notebooks. All deployments must be resource-group scoped (`az deployment group create`); you hold Owner on your own resource group but only Reader on the subscription. Re-download the challenge files. |
| Backend deployment succeeds but test calls 401/403 | APIM RBAC / managed-identity propagation can take a minute after a fresh deployment — wait and retry. |
| A model call fails with a region/quota error | Model availability is region-specific; double-check the model/SKU you configured is available in your lab's region. |

## 🚀 Go further

- Add a second backend (a different `backend_type` such as `aws-bedrock` or
  `gemini-openai`) to the same `llm_backends_config` and re-run sections `5️⃣`–`8️⃣`.
- Configure a `model_alias` that routes a friendly client-facing name to more than one
  underlying model.

## 📚 Learning resources

- [Azure API Management policy reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [What is Microsoft Foundry?](https://learn.microsoft.com/azure/ai-foundry/what-is-ai-foundry)
