### Task 5: Availability rate check

```
let total_expected_heartbeats = toscalar(Heartbeat | summarize count() by bin(TimeGenerated, 1m) | summarize count());
Heartbeat
| summarize actual_heartbeats = dcount(bin(TimeGenerated, 1m)) by Computer
| extend availability_rate = round(actual_heartbeats * 100.0 / total_expected_heartbeats, 2)
| project Computer, availability_rate
```
