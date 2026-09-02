# Financial Evidence MCP

Read-only MCP tools hosted by the Python v2 Azure Functions runtime and backed
by Azure Cosmos DB for NoSQL.

## Tools

| Tool | Purpose |
|---|---|
| `get_bank_information` | Point-read a bank by `bank_id`. |
| `list_account_transactions` | Find transactions where a bank/account pair is the originator or destination. |
| `get_transaction` | Find one transaction by document id or transaction surrogate key. |
| `get_laundering_attempt` | Return the ordered steps for one laundering attempt. |

Bank and account identifiers are strings. Do not coerce them to numbers because
leading zeroes are significant.

## Configuration

Create `local.settings.json` from `local.settings.json.example`. The service
uses these settings:

| Setting | Required | Description |
|---|---|---|
| `COSMOS_ENDPOINT` | Yes in Azure | Cosmos DB account endpoint used with `DefaultAzureCredential`. |
| `COSMOS_CONNECTION_STRING` | Local alternative | Optional local-only connection string. Do not set this in the Function App. |
| `COSMOS_DATABASE_NAME` | Yes | Database containing the evidence containers. |
| `COSMOS_BANK_CONTAINER` | No | Defaults to `dim-bank`. |
| `COSMOS_TRANSACTION_CONTAINER` | No | Defaults to `fact-laundering-pattern-txn`. |

Assign the Function App's managed identity the **Cosmos DB Built-in Data
Reader** data-plane role on the account or database. The identity also needs
permission to read Cosmos account metadata.

## Run locally

Prerequisites are Python 3.13 or newer, Azure Functions Core Tools 4.8 or newer,
Azurite, and an Azure identity with Cosmos read access.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp local.settings.json.example local.settings.json
az login
azurite --silent --location .azurite &
func start
```

The MCP endpoint is `http://localhost:7071/runtime/webhooks/mcp`.

## Deploy

The deployment script creates a Python 3.13 Flex Consumption Function App and
host storage, enables system-assigned managed identity, and publishes the code.
It grants the identity **Cosmos DB Built-in Data Reader** on the specified
existing database; it does not retrieve or store Cosmos keys.

```bash
./deploy.sh \
	-g <function-resource-group> \
	-a <cosmos-account-name> \
	-d <cosmos-database-name>
```

Use `-c <cosmos-resource-group>` when Cosmos DB is in a different resource
group. Run `./deploy.sh -h` for naming, location, subscription, and container
options. The caller needs permission to create Function resources, assign Azure
storage roles, and create Cosmos DB SQL data-plane role assignments.

For a remote endpoint, enable App Service Authentication with Microsoft Entra ID
or place the endpoint behind API Management. The MCP extension's webhook is
anonymous so the platform authentication layer must enforce remote access.

## Cosmos indexing

The account transaction tool performs a bounded cross-partition query. Keep
range indexes for these transaction paths:

- `/from_bank_id/?`, `/from_account/?`
- `/to_bank_id/?`, `/to_account/?`
- `/txn_ts/?`, `/id/?`
- `/attempt_id/?`, `/step_in_attempt/?`

For production-scale evidence, consider a materialized account-transaction
container partitioned by a normalized `bank_id|account_id` key. That avoids the
cross-partition `OR` query while preserving the source transaction container.