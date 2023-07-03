Heartbeat
| where TimeGenerated >= ago(2h) and ResourceType == "virtualMachines"
| summarize count() by Computer , Category , bin(TimeGenerated, 1h)