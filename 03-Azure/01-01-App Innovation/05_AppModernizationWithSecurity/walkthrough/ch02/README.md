# ch02: Test autoscaling under load

Azure offers two complementary approaches to application load and functional testing:

1. **Azure Load Testing** — supports simple URL tests, JMeter scripts, and (via open
   source) Locust scenarios for complex API sequences. As of September 2025 it does **not**
   support WebSockets. So it can exercise the scaling of Azure Container Apps, but it will
   not drive Blazor Server's real-time WebSocket channel on the .NET stack.
2. **Playwright Testing (Workspaces)** — designed for browser automation and end-to-end
   functional flows. It establishes WebSocket connections happily, but it is not optimized
   for sustained high-throughput load.

Because both applications expose a dedicated performance-testing endpoint that queries the
database over plain HTTP, a simple URL-based load test is enough to drive representative
database and serialization load without WebSocket support.

Some performance frameworks are adding WebSocket support through plugins. At the time of
writing, the relevant Locust WebSocket plugins are not supported inside the Azure Load
Testing managed service, but this may change.

## Step 1: Deploy Azure Load Testing

Create the resource from the Azure Portal, or extend your Bicep template. Example Copilot
prompt:

```
Extend main.bicep to create an Azure Load Testing resource.
- As name must be unique add some unique string with full resource group ID as seed
- Use location derived from the resource group location
- See #fetch https://learn.microsoft.com/en-us/azure/templates/microsoft.loadtestservice/loadtests?pivots=deployment-language-bicep
```

## Step 2: Create a URL-based test

Configure two request types against your Container App ingress URL:

| Request | Notes |
| --- | --- |
| `GET /` | The catalog main page |
| `GET /perftest/catalog` | Add header `x-api-key: <your PERFTEST_API_KEY value>` |

The second one is the interesting one: it runs a bounded query against the database, so it
produces load on the data tier rather than only on the web tier.

Start with something like 50–80 virtual users for 5 minutes, then adjust. If you would
rather script it, `tests/load/catalog-load.jmx` in this repository is a JMeter plan you can
upload directly, and `tests/load/load-test.yaml` is an Azure Load Testing configuration you
can adapt.

You can also drive the whole thing from the CLI:

```bash
az load test create \
  --load-test-resource <your-load-test-resource> \
  --resource-group rg-userNNN \
  --test-id catalog-load \
  --load-test-config-file tests/load/load-test.yaml
```

## Step 3: Watch the application scale

While the test runs, open the Container App in the portal and go to **Metrics**. Pin
`Replicas` split by revision. You should see the replica count climb as concurrency rises
and fall back afterwards.

If it does not scale, check the scale rule under **Container App → Scale**. An HTTP rule
divides observed concurrent requests by `concurrentRequests` and keeps the result between
the minimum and maximum replicas. A maximum of 1, or a `concurrentRequests` value far
above your load, will hold it flat.

Useful CLI check:

```bash
az containerapp revision list \
  --name lego-catalog-app \
  --resource-group rg-userNNN \
  --query "[].{revision:name, replicas:properties.replicas, active:properties.active}" -o table
```

## Step 4: Watch the database

Scaling the web tier pushes work onto the database, so watch it too.

| Stack | Metric to watch | How to read it |
| --- | --- | --- |
| Azure SQL Database (serverless) | **App CPU billed** | vCore-seconds. At 1-minute granularity, 30 ≈ 0.5 vCore, 60 ≈ 1 vCore, 120 ≈ 2 vCores |
| Azure Database for PostgreSQL | **CPU percent**, **Active connections** | Connections rise roughly with replica count, since each replica keeps its own pool |

More replicas means more concurrent database connections. On the VM the app and the
database shared a box, so this pressure had nowhere to go — now it does, and it is worth
knowing where your next bottleneck will be.

## Step 5 (optional): Experience the cold start

Set the Container App minimum replicas to 0 with a short cooldown, and set the database to
auto-pause after 15 minutes. Wait, then open the application in a browser and time it.

You will typically wait a few seconds for the container and considerably longer for the
database to resume. That is the honest cost of scale-to-zero — excellent for dev, test,
and internal tools, painful for a customer-facing storefront. Deciding which of your own
workloads can accept it is the point of the exercise.

## Verify

- The replica count went above 1 during the run and returned to its minimum afterwards.
- The database metric shows compute above the idle baseline during the run.
- The load test reports no failed requests.

---

**Challenge:** [ch02](../../challenges/ch02.md) ·
**Previous:** [ch01-A](../ch01-A/README.md) ·
**Next:** [ch03](../ch03/README.md)
