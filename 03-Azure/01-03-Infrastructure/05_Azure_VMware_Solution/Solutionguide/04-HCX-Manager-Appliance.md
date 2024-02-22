# Exercise 4: Prepare the On Prem environment - Configure HCX Appliance

[Previous Challenge Solution](./03-NSX-Add-DNS-Forwarder.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./05-HCX-Site-Pair.md)


## Deploy  HCX Manager Appliance On-Prem

1.	Log in to the On Prem SDDC by login to your Azure jumpbox and by navigating to portal.azure.com. Log on to the jumpbox using the Bastion host and key in the username and password provided  within the Azure Key Vault for your team.

2. Log into the portal and create a License Key for HCX Manager.

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA1.png)

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA3.png)

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA4.png)


2. Log into the HCX Manager of the AVS SDDC and get a download link for the HCX Manager Appliance

   ![](./Images/04-HCX-Manager-Appliance/HCX_OVA5.png)

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA6.png)

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA7.png)

3. Import the link into you onprem SDDC and download the HCX Manager OVA file

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA8.png)

4. Deploy the HCX Manager OVA file into your On-Prem vCenter

![](./Images/04-HCX-Manager-Appliance/HCX_OVA9.png)
![](./Images/04-HCX-Manager-Appliance/HCX_OVA10.png)

Make sure to select the correct network for the HCX Manager Appliance
 
![](./Images/04-HCX-Manager-Appliance/HCX_OVA11.png)

Set the password for the HCX Manager Appliance

![](./Images/04-HCX-Manager-Appliance/HCX_OVA12.png)

Make sure to set the correct IP for the HCX Manager Appliance: 10.1.1.9
Prefix Length: 27

Set the correct DNS and Gateway for the HCX Manager Appliance: 

Gateway: 1.1.1.3
DNS: 1.1.1.1

![](./Images/04-HCX-Manager-Appliance/HCX_OVA13.png)

5. Power on the HCX Manager Appliance
 
![](./Images/04-HCX-Manager-Appliance/HCX_OVA14.png)

![](./Images/04-HCX-Manager-Appliance/HCX_OVA15.png)

![](./Images/04-HCX-Manager-Appliance/HCX_OVA16.png)

## Configure HCX Manager Appliance On-Prem

1.	Log on to the AVS private Cloud for your team in Azure Portal from where you will need to get a activation key for the HCX manager On-Prem

![](./Images/04-HCX-Manager-Appliance/HCX_OVA17.png)

2.	In the Azure VMware Solution portal, go to Manage > Add-ons > Migration using HCX > Connect with on-premise using HCX keys > Add > , specify the HCX Key Name (example as shown in the screenshot), and then select Add.

![](./Images/04-HCX-Manager-Appliance/HCX_OVA18.png)

3.	Use the admin credentials to sign in to the on-premises VMware HCX Manager at https://10.1.1.9:9443. 

![](./Images/04-HCX-Manager-Appliance/HCX_OVA19.png)


### TIP
The admin user password is set during the VMware HCX Manager OVA file deployment.

4.	In Licensing, enter your key for HCX Advanced Key and select Activate.

![](./Images/04-HCX-Manager-Appliance/HCX_OVA20.png)

![](./Images/04-HCX-Manager-Appliance/HCX_OVA21.png)

### Important TIP
VMware HCX Manager must have open internet access or a proxy configured.

5.	In Datacentre Location, specify New York, Unted States of America and press continue

![](./Images/04-HCX-Manager-Appliance/HCX_OVA22.png)

![](./Images/04-HCX-Manager-Appliance/HCX_OVA23.png)

6.	In System Name, modify the name or accept the default and select Continue.

![](./Images/04-HCX-Manager-Appliance/HCX_OVA24.png)

7.	Select Yes, Continue.

 ![](./Images/04-HCX-Manager-Appliance/HCX_OVA25.png)

8.	In Connect your vCenter, provide the FQDN or IP address of your vCenter server and the appropriate credentials, and then select Continue. Use the Azure Key Vault for this.

![](./Images/04-HCX-Manager-Appliance/HCX_OVA26.png)

![](./Images/04-HCX-Manager-Appliance/HCX_OVA27.png)

9. In Configure SSO/PSC, provide the FQDN or IP address of your Platform Services Controller (PSC), and then select Continue. In this case the the PSC is the same as the On-Prem vCenter server. The URL is : https://10.1.1.2

![](./Images/04-HCX-Manager-Appliance/HCX_OVA28.png)

10. Verify that the information entered is correct and select Restart.

!![](./Images/04-HCX-Manager-Appliance/HCX_OVA29.png)

### Note
You'll experience a delay after restarting before being prompted for the next step.

After the services restart, you'll see vCenter showing as green on the screen that appears. Both vCenter and SSO must have the appropriate configuration parameters, which should be the same as the previous screen.

14.	Once HCX Appliance is restarted, log on to the HCX Manager UI – https://10.1.1.9:9443

15.	Go to Configuration -> vSphere Role Mapping -> replace System Administrator and Enterprise Administrator user groups with the following custom domain (instead of vsphere.local). 

Replace the domain name with **avs.lab**

 ![](./Images/04-HCX-Manager-Appliance/HCX_image14.png)