# Ways to access metrics and monitoring performance:

Azure NetApp Files metrics are natively integrated into Azure monitor. From within the Azure portal, you can find metrics for Azure NetApp Files capacity pools and volumes from two locations:

* From [Azure monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/monitor-azure-resource), select **Metrics** then choose a capacity pool or volume. Select **Metric** to view the available metrics:

![image](./img/1-metrics-select-pool-volume.png)

* From the Azure NetApp Files capacity pool or volume, select **Metrics**. Then select **Metric** to view the available metrics:
  
![image](./img/2-metrics-navigate-volume.png)


## Challenge:

# AVD environment 

1. Logon to your AVD client 

2. Copy some data to your user profile share 


## Azure Portal: 

1. Open **Azure Monitor** 

2. Click on **Metrics** 

3. In “Select a scope” select **Resource** type “Capacity Pools” 

4. Select the AVD capability pool being used and hit **Apply** 

5. Under “Metric” select **Pool allocated throughput**

6. Set “Local Time” to 30 minutes 

7. Watch the graph 

8. Copy more data in AVD client 

9. Check out the other capacity pool metrics 

10. Open you NetApp account and click on your volume 

11. Click on **Metrics** and check out the available volume-level metrics

