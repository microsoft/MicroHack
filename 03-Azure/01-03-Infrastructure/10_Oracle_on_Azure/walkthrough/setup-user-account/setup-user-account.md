# Setup your User Account on Azure

[Back to workspace README](../../README.md)

<b><font color=red>IMPORTANT due to time restrictions </b>
<br>
Before you start with the Microhack download the Microsoft Authenticator App on your mobile phone. The App is required for the multi factor authentication.
</font>
<br>
<br>

In the following section you will cover two task.
1. To access via Multi factor authentication
2. First check resource groups and roles are available
3. Troubleshooting
<br>
<br>
<br>

<hr>

# To access via Multi factor authentication

1. Open a Browser with a new Incognito/Private window or Profile.

* Method 1 - Use your preferred browser
   * a. EDGE - Open a new private window 
   * b. Chrome - Open a new incognito window

* Method 2 - Create a new user profile in your browser

  * Example with EDGE

Open your browser and click on your work icon in the upper right corner.

![Create browser profile](../../media/create_browser_profile.png)

<B>Important</B> If you are working with an existing browser profile please clear the browser cache.

2. Login the Azure portal by calling the URL https://portal.azure.com in the browser window of the new created profile and use the provided credentials you got at the beginning of the Microhack. Following an example of the credential you should got: <br>

~~~json
         "user01": [
        {
          "user_principal_name": "user01@cptazure.org",
          "display_name": "Bruce Wayne",
          "initial_password": <"Assigned Password">
        }
      ],
~~~

3. Create MFA authentication when prompted.

<b>Important:</b> For the Multi-Factor Authentication you have to download first the Microsoft Authenticator if you don't have the App yet on your mobile phone.

Following you see the step of a MFA authentication. If you have any additional question check the available online resources under [MFA](https://learn.microsoft.com/en-us/entra/identity/authentication/tutorial-enable-azure-mfa)

1. After you have open the first time the URL [Azure Portal](https://portal.azure.com/) you are forwarded to enable the MFA to access your Azure subscription. The following picutures will guide you through the process visually.

    1. Press next to follow the authentication process.

       ![MFA setup start](../../media/MFA.png)
    
    2. Press in the opened Authenticator app on the upper right + symbol and choose a new "work or school account". In the following menue choose "Scan QR code".

       ![Authenticator app setup](../../media/MFA1.png)

    3. After you have registered the new account you will asked to verify the registration by a sent random number to typ in the authenticator app.

       ![Verify registration](../../media/MFA3.png)

    4. The registration process for the MFA should be successful done.

       ![Registration successful](../../media/MFA4.png)

    5. Congratulations you have an established MFA authentication

       ![MFA established](../../media/MFA5.png)

    6. Finally you have to update the pre assigned password.

       ![Update password](../../media/MFA6.png)

    7. Now, you are logged in the Azure Portal

       ![Logged in](../../media/ENDE%20MFA.png)

A first important step is successfully finished!

<br>
<br>
<br>

<hr>

## First check resource groups and roles are available

After you successfully logged into the Azure portal a first check could be the verification of the required resource groups for the Microhack.

### Move to the resource group in the Azure portal or search for the name in the upper available search bar

![find azure resource group](media/image.png)

### Two resource group are in interest for the microhack and should be created "aks-user[your user number]" and "odaa-user[your user number]"

![see your azure resource group](media/image%20copy.png)

### Your Resources

Should look simiar to this one for Resource Group aks-user[your user number]

![see your azure resource group](media/image%20copy%202.png)

Should look simiar to this one for Resource Group odaa-user[your user number]

![see your azure resource group](media/image%20copy%203.png)

## Azure Cloud Shell

Select the cloud shell icon in the portal

![click on azure cloud shell icon](media/image%20copy%204.png)

Select Powershell as the preferred shell

![select powershell](media/image%20copy%205.png)

Select without storage account and press apply

![select without storage account](media/image%20copy%206.png)

Your final cloud shell should look similar to this one

![final cloud shell](media/image%20copy%207.png)




## Troubleshooting

1. Where to find the user credential file?
    <br>
    The generated user and password file after can be found in the project in the main directory called 
    ~~~text
    user_credentialed.json
    ~~~
<br>

1. If the user the first time runs in a conditional error during the authentication. See the following snapshot.

   ![Conditional access issue](../../media/conditional_access_issue/conditional%20access%20issue%200.png)

  To avoid to many picture the snapshot to guide you to solve the issues can be found by adding the following steps and if required view the snapshots behind each added URL.

  * Login the Azure portal as the tutor with the appropriate rights.
  * Move in the Azure Portal to the Conditional 
    ~~~text
    Conditional Access Policies
    ~~~

  * Press the link "Security info registration for Microsoft partners and vendors" - [see](../../media/conditional_access_issue/conditional%20access%20issue%201.png)
  * Press the link "All users included and specific users excluded" link - [see](../../media/conditional_access_issue/conditional%20access%20issue%202.png)
  * Press in the open window with the title "Security info registration for Microsoft partners and vendors" the link "numbers of users" und the section "Select excluded users and groups" (in the snapshot you choose the linke "2 users") - [see](../../media/conditional_access_issue/conditional%20access%20issue%204.png)
  * Find the goup "mh-odaa-user-grp" and add the group to the excluded users - [see](../../media/conditional_access_issue/conditional%20access%20issue%205.png)
  * Finally press the Save button
 
[Back to workspace README](../../README.md)