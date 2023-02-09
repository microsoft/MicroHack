# Walkthrough Challenge 3 - Protect in Azure with Disaster Recovery

Duration: 30 minutes

[Previous Challenge Solution](../challenge-2/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-4/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 2](../../Readme.md#challenge-2) before continuing with this challenge.

In this Challenge, you will learn how to protect Azure VM with Azure Site Recovery, and enable replication to the secondary site. Moreover, you will successfully run the test failover and failback to make sure the solution works as expected.

Actions

* Set up and enable disaster recovery with Azure Site Recovery and monitor the progress
* Performing a disaster recovery drill, creating recovery plan and test failover 
* Failback to the Europe West region (Source environment) and monitor the progress

### Task 1: Enable replication with Azure Site recovery for the Virtual Machine in the West Europe Region to the North Europe Region

Navigate to Recovery Services Vault in the North Europe (mh-rsv-neu) which we created in the first Challenge. In the Protected Items, select Replicated Items. Then select Replicate and from the dropdown list select Azure virtual machines. The following pan will apprear:

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

### Task 2: Create a recovery plan and Run a disaster recovery drill

#### Create a recovery plan
Navigate to Recovery Services Vault in the North Europe (mh-rsv-neu). Under Manage, select Recovery Plans (Site Recovery) and create a recovery plan.

![image](./img/mh-ch-screenshot-09.png)

Select server01 as the protected source machine and create the recovery plan.

![image](./img/mh-ch-screenshot-10.png)

#### Run the test failover from the West Europe to the North Europe Region
Navigate to the recovery plan created in the previous task. 

![image](./img/mh-ch-screenshot-11.png)

From the top menu select Test failover.

![image](./img/mh-ch-screenshot-12.png)


![image](./img/mh-ch-screenshot-13.png)

#### Monitor the progress
Navigate to Site Recovery Jobs and select Test failover job which is in progress.

![image](./img/mh-ch-screenshot-14.png)


![image](./img/mh-ch-screenshot-15.png)

After all jobs are finished successully, Navigate to Virtual Machines list. New Virtual Machine has been created in the North Europe Region.

![image](./img/mh-ch-screenshot-16.png)

You successfully completed challenge 3! 🚀🚀🚀
