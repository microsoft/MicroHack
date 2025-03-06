# Walkthrough Challenge 3 - Protect in Azure with Disaster Recovery (Inter-regional)

⏰ Duration: 1 hour 15 minutes

📋  [Challenge 3 Instructions](../../challenges/03_challenge.md)

## Prerequisites

Please ensure that you successfully passed [challenge 2](../../challenges/02_challenge.md) before continuing with this challenge.

In this challenge, you will learn how to protect Azure VM with Azure Site Recovery, and enable replication to the secondary site. Moreover, you will successfully run the test & production failover and failback between two regions.

### Actions

* Task 1: Set up and enable disaster recovery with Azure Site Recovery and monitor the progress.
* Task 2: Perform a disaster recovery drill, create recovery plan and run a test failover.
* Task 3: Run a production failover from Germany West Central to Sweden Central region and failback again from Sweden to Germany.

## Task 1: Enable replication with Azure Site recovery for the Virtual Machine in the Germany West Central Region to the Sweden Central Region

<details close>
<summary>💡 Enable replication with Azure Site recovery for the Virtual Machine in the Germany West Central Region to the Sweden Central Region</summary>
<br>

Navigate to **Recovery Services Vault** in the Sweden Central (mh-swedencentral-asrvault) which we created in the first Challenge. In the **Protected Items**, select **Replicated Items**. Then select **Replicate** and from the dropdown list select **Azure virtual machines**. The following pane will apprear:

![image](./img/001.png)

![image](./img/002.png)

![image](./img/003.png)

![image](./img/004.png)

![image](./img/005.png)

![image](./img/006.png)

In the deployment notification you could navigate to the Site Recovery Jobs which lists all Site Recovery Actions you have created in this task.

![image](./img/007.png)

You can select in progress jobs to check the status and progress.

![image](./img/008.png)

This Task can take up to 10 minutes to finish.

![image](./img/009.png)

![image](./img/011.png)

![image](./img/010.png)

### Alternative: Disaster recovery can be set also under Virtual Machine | Disaster Recovery

![image](./img/100.png)

</details>

## Task 2: Create a recovery plan and Run a disaster recovery drill

### Create a recovery plan
Navigate to **Recovery Services Vault** in the Sweden Central (mh-swedencentral-asrvault). Under **Manage**, select **Recovery Plans (Site Recovery)** and create a recovery plan.

![image](./img/09.png)

Select `mh-web1` and `mh-web2` as the protected source machine and create the recovery plan.

![image](./img/10.png)

### Run the test failover from Germany West Central to the Sweden Central Region
Navigate to the recovery plan created in the previous task. 

![image](./img/11.png)

From the top menu select **Test failover**.

![image](./img/12.png)


![image](./img/13.png)

### Monitor the progress
Navigate to **Site Recovery Jobs** and select Test failover job which is in progress.

![image](./img/14.png)


![image](./img/15.png)

![image](./img/16.png)

After all jobs are finished successully, Navigate to the Virtual Machines list. New Virtual Machine has been created in the Sweden Central Region.

![image](./img/17.png)

### Cleanup test failover
![image](./img/18.png)

![image](./img/19.png)

![image](./img/20.png)

![image](./img/21.png)

![image](./img/22.png)

## Task 3: Run a production failover from Germany West Central to Sweden Central and failback again from Sweden to Germany region (Source environment) and monitor the progress
### Run the production failover for the web application from Germany West Central to Sweden Central
![image](./img/23.png)

![image](./img/24.png)

![image](./img/25.png)

![image](./img/26.png)

Check the virtual machine list. There is a new virtual machine running in Sweden Central region.

![image](./img/27.png)

### Reprotect the virtual machine
![image](./img/28.png)

![image](./img/29.png)

![image](./img/30.png)

![image](./img/31.png)

![image](./img/32.png)

![image](./img/33.png)

**You successfully completed challenge 3!** 🚀🚀🚀

[➡️ Next Challenge 4 Instructions](../../challenges/04_challenge.md)