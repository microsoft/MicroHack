### **Task 3: Create and manage Active Directory connections for Azure NetApp Files**

1. From your NetApp account, select **Active Directory connections** then **Join**.

![image](../img/solution-03-azure-netapp-files-active-directory-connections.png)

2. In the Join Active Directory window, provide the following information, based on the Domain Services you want to use:

![image](../img/solution-03-azure-netapp-files-join-active-directory.png)

* Primary DNS
* AD DNS Domain Name: **microhack.test**
* AD Site Name: **Default-First-Site-Name**
* SMB Server (computer account) prefix: **MH**
* AES Encryption: **enable**
* Username: **microhack**
* Password: **NetApp12345!!**

3. Select **Join**.
