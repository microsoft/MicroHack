# Walkthrough Challenge 3 - Protect in Azure with Disaster Recovery

Duration: 50 minutes

[Previous Challenge Solution](../challenge-2/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-4/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 2](../../Readme.md#challenge-2) before continuing with this challenge.

In this Challenge, you will learn how to protect Azure VM with Azure Site Recovery, and enable replication to the secondary site. Moreover, you will successfully run the test & production failover and failback between two regions.

Actions

* Set up and enable disaster recovery with Azure Site Recovery and monitor the progress
* Perform a disaster recovery drill, create recovery plan and run a test failover 
* Run a production failover from EU West to EU East region and Failback again to the EU West region (Source environment) and monitor the progress

## Task 1: Enable replication with Azure Site recovery for the Virtual Machine in the West Europe Region to the North Europe Region

Navigate to **Recovery Services Vault** in the North Europe (mh-rsv-neu) which we created in the first Challenge. In the **Protected Items**, select **Replicated Items**. Then select **Replicate** and from the dropdown list select **Azure virtual machines**. The following pan will apprear:

![image](./img/mh-ch-screenshot-01.png)

![image](./img/mh-ch-screenshot-02.png)

![image](./img/mh-ch-screenshot-03.png)

![image](./img/mh-ch-screenshot-04.png)

![image](./img/mh-ch-screenshot-05.png)

In the deployment notification you could navigate to the Site Recovery Jobs which lists all Site Recovery Actions you have created in this task.

![image](./img/mh-ch-screenshot-06.png)

You can select in progress jobs to check the status and progress.

![image](./img/mh-ch-screenshot-07.png)

This Task can take up to 10 minutes to finish.

![image](./img/mh-ch-screenshot-08.png)

## Task 2: Create a recovery plan and Run a disaster recovery drill

### Create a recovery plan
Navigate to **Recovery Services Vault** in the North Europe (mh-rsv-neu). Under **Manage**, select **Recovery Plans (Site Recovery)** and create a recovery plan.

![image](./img/mh-ch-screenshot-09.png)

Select server01 as the protected source machine and create the recovery plan.

![image](./img/mh-ch-screenshot-10.png)

### Run the test failover from the West Europe to the North Europe Region
Navigate to the recovery plan created in the previous task. 

![image](./img/mh-ch-screenshot-11.png)

From the top menu select **Test failover**.

![image](./img/mh-ch-screenshot-12.png)


![image](./img/mh-ch-screenshot-13.png)

### Monitor the progress
Navigate to **Site Recovery Jobs** and select Test failover job which is in progress.

![image](./img/mh-ch-screenshot-14.png)


![image](./img/mh-ch-screenshot-15.png)

After all jobs are finished successully, Navigate to the Virtual Machines list. New Virtual Machine has been created in the North Europe Region.

![image](./img/mh-ch-screenshot-16.png)

### Cleanup test failover
![image](./img/mh-ch-screenshot-17.png)

![image](./img/mh-ch-screenshot-18.png)

![image](./img/mh-ch-screenshot-19.png)


## Task 3: Run a production Failover and Failback again to the Europe West region and monitor the progress
### Run the production failover for server01 from Europe West to North
![image](./img/mh-ch-screenshot-20.png)

![image](./img/mh-ch-screenshot-21.png)

![image](./img/mh-ch-screenshot-22.png)

Check the virtual machine list. There is a new virtual machine "server01" running in North Europe region.
![image](./img/mh-ch-screenshot-23.png)

### Reprotect the virtual machine
![image](./img/mh-ch-screenshot-24.png)

![image](./img/mh-ch-screenshot-25.png)

![image](./img/mh-ch-screenshot-26.png)

### Run the failback for server01 from Europe North to West
You can't fail back the VM until the replication has completed, and synchronization is 100% completed. The synchronization process can take several minutes to complete.
After the Synchronization completes, select **Failover**.

![image](./img/mh-ch-screenshot-27.png)

![image](./img/mh-ch-screenshot-28.png)

Check the Virtual machine list. Server01 is running again in the West Europe region.
![image](./img/mh-ch-screenshot-29.png)

**You successfully completed challenge 3!** 🚀🚀🚀
