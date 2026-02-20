# Register and set up


## Register for NetApp Resource Provider 

1. Log in to the [Azure portal](https://portal.azure.com/#home). 

2. In the Azure portal's search box, enter **Subscriptions** and then select your subscription. 

3. On the left menu under **Settings**, select **Resource providers**. 

4. Find the provider Microsoft.NetApp. 

5. Select **Microsoft.NetApp** and select **Register**. 

![image](./img/ressource_provider.png)


## Create a NetApp account in Azure NetApp Files 

1. In the Azure portal's search box, enter **Azure NetApp Files** and then select **Azure NetApp Files** from the list that appears. 

![image](./img/search-azure-netapp-files.png)

2. Select + **Create** to create a new NetApp account. 

3. In the New NetApp Account window, provide the following information:
   
* Enter **myaccount1** for the account name. 
* Select your subscription. 
* Select **Create new** to create new resource group. Enter **myRG1** for the resource group name. Select OK. 
* Select your account location.

![image](./img/azure-netapp-files-new-netapp-account.png)

4. Select **Create** to create your new NetApp account.


## Create a capacity pool 

1. From the Azure NetApp Files management sidebar, select your NetApp account, e.g. myaccount1

![image](./img/azure-netapp-files-select-netapp-account.png)

2. From the Azure NetApp Files management sidebar, select **Capacity pools**.

![image](./img/azure-netapp-files-click-capacity-pools.png)

3. Select + **Add pools**. 

![image](./img/azure-netapp-files-new-capacity-pool.png)

4. Provide information for the capacity pool: 

* Enter **mypool1** as the pool name. 
* Select **Premium** for the service level. 
* Specify **1 (TiB)** as the pool size. 
* Use the **Auto** QoS type. 

5. Select **Create**.

   
## Create an NFS volume for Azure NetApp Files

1. From the Azure NetApp Files sidebar of your NetApp account, select Volumes.

![image](./img/nfs_1.png)

2. Select + Add volume.

![image](./img/nfs_2.png)

3. In the Create a Volume window, provide information for the volume:

a. Enter myvol1 as the volume name.
b. Select your capacity pool (mypool1).
c. Use the default value for quota.
d. Under virtual network, select Create new to create a new Azure virtual network (VNet). Then fill in the following information:

* Enter **myvnet1** as the VNet name.
* Specify an address space for your setting, for example, 10.7.0.0/16
* Enter **myANFsubnet** as the subnet name.
* Specify the subnet address range, for example, 10.7.0.0/24. You can't share the dedicated subnet with other resources.
* Select **Microsoft.NetApp/volumes** for subnet delegation.
* Select **OK** to create the VNet.

e. In subnet, select the newly created VNet (myvnet1) as the delegate subnet.

![image](./img/nfs_3.png)
![image](./img/nfs_4.png)

4. Select Protocol, and then complete the following actions:

* Select NFS as the protocol type for the volume.
* Enter myfilepath1 for the file path used to create the export path for the volume.
* Select the NFS version (NFSv3 or NFSv4.1) for the volume. See considerations and best practice about NFS versions.
* Select Disabled for Kerberos and LDAP (for the quickstart).
* Optionally, configure Unix permissions. For information, see Configure UNIX permissions.
* Leave Azure VMware Solution DataStore unchecked.
  
![image](./img/nfs_5.png)

5. Select Review + create to display information for the volume you're creating.

6. Select Create to create the volume. The created volume appears in the Volumes menu.

![image](./img/nfs_6.png)
