$tableParams = @'
{
   "properties": {
       "schema": {
              "name": "MH_MONITORING_CL",
              "columns": [
       {
                               "name": "TimeGenerated",
                               "type": "DateTime"
                       }, 
                      {
                               "name": "RawData",
                               "type": "String"
                      }
             ]
       }
   }
}
'@

Invoke-AzRestMethod -Path "/subscriptions/{subscription id}/resourcegroups/rg-microhack-monitoring/providers/microsoft.operationalinsights/workspaces/law-microhack/tables/MH_MONITORING_CL?api-version=2021-12-01-preview" -Method PUT -payload $tableParams
