# Walkthrough Challenge 5 - Managing and Monitoring Azure NetApp Files

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

8k block size 100% random read test
```bash
fio --name=fio-8krandomreads --rw=randread --direct=1 --ioengine=libaio --bs=8k --numjobs=4 --iodepth=128 --size=5G --runtime=600 --group_reporting
```

8k block size 100% random writes
```bash
fio --name=fio-8krandomwrites --rw=randwrite --direct=1 --ioengine=libaio --bs=8k --numjobs=4 --iodepth=128 --size=5G --runtime=600 --group_reporting
```

3. Go to your metrics dashboard and review achvieved throughput

4. Go to your NetApp account, select your NFS volume, double the size of your volume and save your change

5. Repeat your FIO testing 

6. Return to your metrics dashboard and review achvieved throughput and download speed

### Task 3: AVD/FSLogix user experience 

1. Login to the AVD environment with your user

2. For a quick test, download Google Chrome in offline edition and note the time it took

https://www.google.com/intl/en/chrome/next-steps.html?standalone=1

3. Change to your performance dashboard and review achieved 

4. Leave the AVD connection open and switch to your Netapp account

5. In your NetApp account, change your AVD volume size to 300 GB and save the change

6. Return to your AVD session and repeat the download test

https://www.google.com/intl/en/chrome/next-steps.html?standalone=1

7. Change to your performance dashboard, review achieved throughput and download speed. Compare this to the first download results


You successfully completed challenge 5! 🚀🚀🚀

