![image](Images/AVD-Header.png)

# Azure Virtual Desktop - MicroHack

## Introduction

This hack is designed to help you get hands-on experience with Nerdio Manager for Enterprise and Azure Virtual Desktop (AVD).

Nerdio is a Nerdio is a premier software solution provider that specializes in deploying, managing, and optimizing native Microsoft technologies. They offer a platform that simplifies and enhances the deployment and management of Microsoft cloud technologies such as Azure Virtual Desktop, Windows 365, and Microsoft Intune, aiming to reduce costs, improve security, and enhance user experience for enterprise IT professionals and Managed Service Providers

AVD – is a born-in-the-cloud desktop-as-a-service platform service offered entirely on our Microsoft Intelligent Cloud. 
All traditional infrastructure services such as brokering, web access, load balancer, management and monitoring are part of the AVD control plane and can be configured from the Azure portal or via the Azure Resource Manager (ARM)

This hack covers all essential artifacts of AVD and starts off by covering the basics and then digs deep into the different componets. You will encounter different types of solutions that is or could be needed in a AVD environment. 

## Exercise 1: Model a multi-Session environment for 1000 users 
### Introduction
This first challenges focusses on “modeling” a 1000 user multi-session Azure Virtual Desktop environment using the Modeler service as part our “Advisor” in Nerdio Manager for Enterprise. The Nerdio Advisor Modeler provides cost modelling and optimization recommendations to ensure your environment is configured with the right settings to meet your needs. The Modeler lets you create detailed models for new host pools. These models provide anticipated costs, so you know beforehand what to expect before implementing. 

### Challenge
- Region: UK South Region
- 1000 users multi-Session, based on medium user
- Select any VM type you find appropriate
- Use a P10 Premium SSD 126 GB Running Disk, a Standard HDD Stopped Disk
- Work hours are 08:30AM – 5PM. 25% Absence
- Use a Marketplace Standard Image 
- Azure Files Premium at 5 GB
- Save and close.
- Export as .JSON file

### Success Criteria
- You should see a complete filled-in overview including all associated costs. Nerdio Compute cost savings should be close to 80%. Per User costs should be around $5 monthly.

### Learning Resources
- [Nerdio Advisor “Modeler”](https://nmehelp.getnerdio.com/hc/en-us/articles/26124356019981-Nerdio-Advisor-Modeler)


## Exercise 2: Create a Nerdio Resource Rule
### Introduction
Nerdio Manager allows you to create recommendation and filtering rules to assist with the selection of VM sizes and OS disks when creating host pools or adding session host VMs.
Resource selection rules can be used to suggest the best VM for a specific AVD use-case, while taking into account core availability. They can also be used to limit the types of VMs and OS disks that can be used globally in a workspace, or even at the host pool level.
The VMs can be filtered based on vCPU availability in a selected subscription and region, processor, VM family & version, number of cores & GB of RAM, and local temp storage. OS disks can be filtered based on storage type (premium, standard, SSD, HDD, or Ephemeral) and disk size.
During this exercise we are creating a resource rule which will limit the type of machine we can select, as well as the accompanying image type. 

### Challenge
- Create a Resource Rule with the name: “D2S_v5”
- Scope is “your assigned Workspace” + “Desktop images” 
- Enable the show costs option
- Select this rule to apply by default
- Set the “VM SIZE DROP-DOWN SELECTION RULES” TO “YES”
- Intel Processor only
- Family version is “V5”
- Family type is “General use” 
- CPU Cores is “2”
- RAM is “8GB”
- VM Availability is “Based on CPU core quota “ 
- Storage type is “Premium SSD” + “Standard HDD” 
- OS Disk Size is 128GB
- Allowed Desktop Images is Windows 11 (22H2) AVD – Gen2 (Multi-Session)

### Success Criteria
- When creating a new hostpool or importing an image you should only be able to choose from 4 different D series V5 machines. 
- When importing an image, the only image you will be allowed to pick will be the Windows 11 (22H2) AVD – Gen2 (Multi-Session) marketplace image (during the next exercise). 

### Learning Resources
- [Nerdio Resource Rules´](https://nmehelp.getnerdio.com/hc/en-us/articles/26124385602957-Resource-Selection-Rules-Management)


## Exercise 3: Import Image from the Azure Marketplace 
### Introduction
Nerdio Manager allows you to import a desktop image from the Azure library into a Workspace. This image can be used to create new host pools or reimage existing host pools, something we will manage during a later exercise. Once an image is imported into Nerdio you have multiple ways of automating ongoing lifecycle tasks like updating applications, installing the latest (security) patches, reimage hostpool according to pre-configured schedules and more. 
During this exercise you will leverage the earlier created resource rule “D2S_V5”, limiting you to only select the Windows 11 (22H2) AVD – Gen2 (Multi-Session) image. Normally, you would be able to select a range of different Marketplace images, custom images, gallery images, etc. 

### Challenge
- Select the Windows 11 (22H2) AVD – Gen2 (Multi-Session) image. Make sure no other types of images are selectable – see resource rule creation
- Set the machine type to D2s_v5 with a Premium SSD – no other types should be available for selection 
- Select the correct Resource Group
- Configure the correct time-zone
- Make sure to optimize disk usage when image is in a stopped state. 

### Success Criteria
- Once you click OK the process can be followed in the “Desktop image tasks” pane below
- Click on “Details” to follow along and wait for the first auto-refresh
- This will take some time to complete
- Have us check the result
- While we wait, we move on to the following exercise

### Learning Resources
- [Nerdio Image Management](https://nmehelp.getnerdio.com/hc/en-us/articles/26124336183821-Create-a-Desktop-Image)


## Exercise 4: Create a Dynamic Hostpool 
### Introduction
In this exercise we will have Nerdio create a new, but empty hostpool for us. Once we have filled in the details it will create an empty host pool, which will take somewhere between 15 to 20 seconds. Once created, it will automatically open up the Autoscale configuration page. This is normally where we would fill in the number of machines we would like to have created, as well as how the Autoscale engine should behave during the day, week, month, etc. 
During this exercise we will NOT use the autoscale configuration page right away. Instead, we will create our autoscale configuration based on what we refer to as an autoscale profile (next exercise), which we can apply to our hostpool once finished. 
Note that our image is still being imported into Nerdio, from the previous exercise. However, we can select the exact same image from the azure marketplace and have the hostpool and the machines created based on that. 

### Challenge
- Create a new Dynamic Hostpool and give it a name, use your own name for this
- It needs to be based on multi-user
- For “Directory” and FSLogix” select the ones pointed out earlier
- Use “Prefix” and fill in your username for today, “Hack1”, for example. Make sure you understand how this mechanism works and what it is used for
- Select the correct vNet, the one we shared earlier
- Leave the image at its default
- VM Size is “DS2_V5”
- OS Disk is “P10”
- Select the correct Resource Group, the one we shared earlier
- Leave the rest at default and click “OK”

### Success Criteria
- After 10-15 seconds the Hostpool will be created and the Autoscale configuration page will appear
- Have us check the result
- Click cancel and move on to the next Exercise

### Learning Resources
- [Dynamic Hostpool creation](https://nmehelp.getnerdio.com/hc/en-us/articles/26124383616909-Create-Dynamic-Host-Pools)

## Exercise 5: Create an Auto-Scale Profile  
### Introduction
Auto-scale profiles simplify the creation process for new host pools by allowing you to create a profile with auto-scale settings that can be reused. When configuring auto-scale for a host pool, you can select an auto-scale profile for both the standard and alternative auto-scale schedules. This eliminates the need for manual configuration of the auto-scale settings for each pool or schedule.
During this exercise we will create a single profile. As the next step (exercise 6) we will apply this profile to the earlier created Hostpool. 

### Challenge
- Select the correct “mode” for multi-user
- Give it a name. Be original 😊 Or use your own name, that’s OK too
- Configure two machines that can be started and stopped
- Make sure one machine is running all the time
- It should be allowed to create two additional machines from scratch (just in time provisioning)
- Set scaling logic to CPU
- Configure scale-in restrictions: from 6PM to 7AM
- Set the “Scale in aggressiveness” to “Medium”
- Configure “Rolling drain mode” to 2 PM at 50%
- Pre stage 1 machine at 7AM on Monday to Friday
- Create a second pre stage schedule for Saturday and Sunday. Set your own times
- For both schedules, set the “Scale in delay” at 2 hours
- Enable “Auto-heal broken hosts”
- Add “No heartbeat”
- Make sure it waits 5 minutes before taking the first action
- Have the machine restart one time, then delete and recreate
- Make sure it waits 8 minutes between the above actions
- Save configuration

### Success Criteria
- You should now have an Autoscale profile created with the above-mentioned parameters. 
- This profile can now be applied to the earlier created hostpool and any future hostpools created through Nerdio. 
- Before continuing have us check the result. 
- Move on to exercise 6. 

### Learning Resources
- [Manage Auto-Scale Profiles](https://nmehelp.getnerdio.com/hc/en-us/articles/26124342722701-Manage-Auto-scale-Profiles)
- [Configure Nerdio Auto-Scale](https://nmehelp.getnerdio.com/hc/en-us/articles/26124304193037-Enable-Dynamic-Host-Pool-Auto-scaling)

## Exercise 6: Apply Auto-scale profile to existing Hostpool and enable Auto-scale
### Introduction
The auto-scale feature ensures that only the number of session host VMs required to serve the current demand are running. When not in use, VMs are stopped or deleted. When demand rises, or at specific times of the day, additional VMs in the host pool are started or created. This allows for cost savings. In this exercise we will apply the earlier created Auto-scale profile to our existing hostpool. 

### Challenge
- Go te earlier created hostpool and go into autoscale configuration
- Enable Autoscale
- Leave all the configuration items at their default and scroll down to the “Default schedule”
- Select the earlier created autoscale profile
- When finished with the above make sure the autoscale configuration gets applied to the hostpool. 
- Wait a few second and follow along by viewing the details of the tasks being executed. 

### Success Criteria
- After 10-20 seconds the Auto-scale engine should pick up the configuration change and start building the 2 base hostpool capacity machines for us. 
- Follow along in the “Host pool task” pane by clicking on “Details”
- Have us check the result. 
- Move on to exercise 7. 

### Learning Resources
- [Enable Dynamic Hostpool Auto-Scale](https://nmehelp.getnerdio.com/hc/en-us/articles/26124342722701-Manage-Auto-scale-Profiles)

## Exercise 7: Ongoing image management – apply monthly security patches on recuring schedule
### Introduction
As mentioned previously, once an image has been imported into Nerdio the entire lifecycle can be managed and automated. One of those tasks includes applying the monthly “Patch Tuesday” (security) patches to your image(s). In this (three part) exercise we will set up a recurring schedule where the latest (security) patches will be applied an x number of days after Patch Tuesday. At the same time, we will also make sure that the image is automatically applied to your host pools for testing purposes. 
First, we will create a Scripted Actions Group, which will include a Windows script that pulls in and applies the latest monthly Windows patches. As a next step, we will set up a schedule, including the Scripted Actions Group to apply the Patch Tuesday patches, and finally we will set up a recurring schedule to reimage your hostpool with the updated image. 

### Challenge
- Create a new scripted actions group, give it a name
- Add the “Update Windows 11” Scripted Action. Here we can add as many Scripted Actions as we feel fit and change the order. Though, for this exercise we’ll keep it at a single script
- Go to your imported image and select “Set as image”
- Enable scripted actions, add the earlier created scripted actions group
- Set schedule to repeat 3 days after patch Tuesday at 12AM
- Make sure the image is backed-up 
- Fill in the “Change log”
- Go to your earlier created hostpool
- Select “resize / reimage”
- Set schedule to repeat 3 days after patch Tuesday, start time = 4AM

### Success Criteria
- You should now see a clock icon next to your image, under “Last updated”
- If you hover over it, it should display the details configured (schedule)
- You should now see a clock icon next to your hostpool, under “Last updated”
- If you hover over it, it should display the details configured (schedule)
- Let us check the results

### Learning Resources
- [Scripted Actions Groups](https://nmehelp.getnerdio.com/hc/en-us/articles/26124368803213-Scripted-Actions-Groups)
- [Desktop Images - Set As Image](https://nmehelp.getnerdio.com/hc/en-us/articles/26124381963149-Desktop-Images-Set-as-Image)
- [Re-size and Re-image Hostpool](https://nmehelp.getnerdio.com/hc/en-us/articles/26124319282061-Resize-Re-image-a-Host-Pool)