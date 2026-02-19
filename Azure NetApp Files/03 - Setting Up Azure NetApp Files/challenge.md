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
