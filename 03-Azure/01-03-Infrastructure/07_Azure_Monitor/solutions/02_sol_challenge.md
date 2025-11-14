### *[Optional]* Task 3: Enable VM Insights for `vmss-linux-nginx` automatically

Use following initiative: [link](https://portal.azure.com/#view/Microsoft_Azure_Policy/InitiativeDetail.ReactView/id/%2Fproviders%2FMicrosoft.Authorization%2FpolicySetDefinitions%2Ff5bf694c-cca7-4033-b883-3a23327d5485/version/1.2.0/scopes~/%5B%22%2Fsubscriptions%2F794194cd-a4b7-4024-970c-9533c4babff0%22%5D). 

Note: make sure to provide the resource ID of the DCR for Linux VMs.


### Task 4: Log search and visualize

- Create a chart with CPU usage trends by computer. Calculate CPU usage patterns over the last hour, chart by percentiles.

```
InsightsMetrics
| where TimeGenerated > ago(1h)
| where Name == "UtilizationPercentage"
| summarize 
    p50 = percentile(Val, 50),
    p75 = percentile(Val, 75),
    p90 = percentile(Val, 90)
  by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated asc
```