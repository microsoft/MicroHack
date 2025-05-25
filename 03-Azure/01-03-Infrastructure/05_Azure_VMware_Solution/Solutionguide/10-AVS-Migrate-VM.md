# Exercise 10: YAY - Its Migration Time - Finally!!!

[Previous Challenge Solution](./09-HCX-Network-Extension.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./11-NSX-Firewall.md)

## Migrate a VM

1.	To migrate a virtual machine from and On Prem Environment to AVS, sign in to your on-premises HCX.

2.	Under Services, select Migration, and then select Migrate

![](./Images/10-AVS-Migrate-VM/HCX_image46.png)

3.	Once the Workload Mobility window is opened, ensure your site pairing is available from On Prem to AVS. 

4.	Select Workload-1-1-1 as a VM that will be migrated from On-Prem to AVS and press Add 

![](./Images/10-AVS-Migrate-VM/HCX_image47.png)

5.	Once the virtual machine is added, select the transfer and placement parameters for the virtual machine post migration to AVS and then press validate
 
![](./Images/10-AVS-Migrate-VM/HCX_image48.png)

6.	Once the transfer and placement validation of the virtual machine has gone through, press go for the migration of the virtual machine


![](./Images/10-AVS-Migrate-VM/HCX_image49.png)

![](./Images/10-AVS-Migrate-VM/HCX_image50.png)
 
7.	Once the VM is migrated into AVS, check the IP address of the VM. 

Note : 

As the VM that was migrated was on a extended network, the IP address of the VM has not changed; however if the VM that was migrated was not on an extended network, then the IP address of the VM would have changed. 

8. Optionally if time permits please also try out the reverse migration.

9. Try to ping Workload-1-1-2 from Workload-1-1-2.
> [!NOTE]
> The login details can be found in the Azure Key Vault or [Visit AVS Hub](https://www.avshub.io/workshop-guide/#credentials-for-the-workload-vms) for VM Credentials



11. Move the second VM accordingly to AVS.
