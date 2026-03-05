# Walkthrough Challenge 5 - Managing and Monitoring Azure NetApp Files Performance

[Previous Challenge Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-06/solution-06.md)



### Task 1: Configure a quick metrics dashboard

1. Open your NetApp acoount

2. On the left side open **Monitoring** and then click on **Metrics**

3. Click on **New chart**. Now you see 2 charts in total

4. On the upper chart, click on **Save to dashboard**, select **Pin to dashboard**, enter a name and hit **OK**

5. Repeat the previous step on the lower chart and pin it the the same dashboard

6. On the upper chart, click on **Scope**, click on your capacity pool and select both volumes. Hit **Apply** 

7. Click on **Metric** and select **Write throughput**

8. On the lower chart chose the same scope and select **Read Throuput** as metric

9. Change to service **Dashboard Hub** and view your new dashboard

### Task 2: NFS Performance monitoring and optimization

1. Logon to your Linux VM and mount your NFS volume

2. Run a couple of load simualations

Read test
```bash
sudo su
cd /netapp-mnt
fio --name=read_test --ioengine=libaio --rw=read --bs=4k --direct=1 --size=100M --numjobs=1 --runtime=60 --group_reporting
```
Write test
```bash
fio --name=write_test --ioengine=libaio --rw=write --bs=4k --direct=1 --size=100M --numjobs=1 --runtime=60 --group_reporting --direct=1

```

3. Go to your metrics dashboard and review achvieved throughput

4. Go to your NetApp account, select your NFS volume, double the size of your volume and save your change

5. Repeat your FIO testing 

6. Return to your metrics dashboard and review achvieved throughput and download speed

### Task 3: AVD/FSLogix user experience 

1. Login to the AVD environment with your user

2. For a quick test, download Google Chrome in offline edition and note the time it took

https://www.google.com/intl/en/chrome/next-steps.html?standalone=1

3. Change to your performance dashboard and review results 

4. Leave the AVD connection open and switch to your Netapp account

5. In your NetApp account, change your AVD volume size to 300 GB and save the change

6. Return to your AVD session and repeat the download test

https://www.google.com/intl/en/chrome/next-steps.html?standalone=1

7. Change to your performance dashboard, review achieved throughput and download speed. Compare this to the first download results

### Task 4: We need more performance

1. Go back to you NetApp account

2. On the left side expand **Storage service** and  select **Capacity pools**

3. Select **Add Pool**, enter a name, select **Ultra** for Service level and make it 1 TB in size and hit **Create** 

4. Once your new pool is ready, select **Volumes** on the left side

5. Click the three dots in column **Actions** on the right side of you SMB volume, select **Change pool**, select your new pool and hit **OK**

6. Repeat the previous steps for your NFS volume

7. Repeat the tests from **Task 2** and **Task 3**

8. Check your monitoring dashboard and compare the results. 

You successfully completed challenge 5! 🚀🚀🚀

