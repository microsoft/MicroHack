# NOTES

Tips and trick for maintaining the linux microhack.

### Azure CLI

~~~bash
# List all resource groups
az group list --query [].name -o tsv

# List all resources inside a resource group
<<<<<<< HEAD
sourceRgName=$(az group list --query "[?starts_with(name, '$prefix') && ends_with(name, 'source-rg')].name" -o tsv)
destinationRgName=$(az group list --query "[?starts_with(name, '$prefix') && ends_with(name, 'destination-rg')].name"
=======
sourceRgName=$(az group list --query "[?ends_with(name, 'source-rg')].name" -o tsv)
destinationRgName=$(az group list --query "[?ends_with(name, 'destination-rg')].name" -o tsv)
>>>>>>> 8957122b7de423901e9a59775f64f7fccad23580
az resource list -g $sourceRgName -o table

# Login to Azure with local user
az network bastion ssh -n $srcBastionName -g $srcRgName --target-resource-id $srcVm1Id --auth-type password --username azuresuser
az network bastion ssh -n $sourceBastionName -g $sourceRgName --target-resource-id $sourceVm1Id --auth-type AAD

# Delete VMs only
az vm delete --ids $sourceVm1Id $sourceVm2Id --yes
az vm delete --id $sourceVm2Id --yes --no-wait

# Delete resource group
az group delete --name ${prefix}1-$suffix-destination-rg --yes --no-wait
az group delete --name ${prefix}1-$suffix-source-rg --yes --no-wait

# Install Azure SSH AAD
az vm extension set --publisher Microsoft.Azure.ActiveDirectory --name AADSSHLoginForLinux --ids $sourceVM1Id $sourceVM2Id

<<<<<<< HEAD

az login --use-device-code
=======
az quota create --resource-name StandardSkuPublicIpAddresses --scope /subscriptions/$subid/providers/Microsoft.Network/locations/$location --limit-object value=100 --resource-type PublicIpAddresses
az quota create -h
>>>>>>> 8957122b7de423901e9a59775f64f7fccad23580

# Assign application developer role to user of a group
# Get the object ID of the custom role
role_id=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/directoryRoles" | jq -r '.value[] | select(.displayName == "Application Developer") | .id')

# Get the object ID of the AAD group
group_id=$(az ad group show --group 'MH - Linux Migration' --query id -o tsv)

# assign the role to the group
az rest --method POST --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" --headers "Content-type=application/json" --body '{"@odata.type": "#microsoft.graph.unifiedRoleAssignment","roleDefinitionId": "'$role_id'","principalId": "'$group_id'","directoryScopeId": "/"}'

az rest --method POST --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" --headers "Content-type=application/json" --body '{"@odata.type": "#microsoft.graph.unifiedRoleAssignment","roleDefinitionId": "cf1c38e5-3621-4004-a7cb-879624dced7c","principalId": "'$group_id'","directoryScopeId": "/"}'
<<<<<<< HEAD

# Add needed providers
subid=651e7801-9bd4-457d-8e91-3afe3139da8d # MH - Linux Migration
az account set --subscription $subid
az provider register --namespace Microsoft.Compute 
az provider show --namespace Microsoft.Compute --query "registrationState"
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Resources
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.Insights

# Increase quota
location=germanywestcentral
# not working because of MF requirement
az quota create --resource-name StandardSkuPublicIpAddresses --scope /subscriptions/$subid/providers/Microsoft.Network/locations/$location --limit-object value=100 --resource-type PublicIpAddresses
az quota create -h

# list quotas for public standard IPs via azure cli
az quota list --scope subscriptions/$subid/providers/Microsoft.Network/locations/$location --query "[?name=='StandardSkuPublicIpAddresses'].properties.limit"
az quota list --scope subscriptions/$subid/providers/Microsoft.Network/locations/$location --query "[?name=='PublicIPAddresses'].properties.limit"
az quota list --scope subscriptions/$subid/providers/Microsoft.Compute/locations/$location --query "[?name=='cores'].properties.limit"
=======
>>>>>>> 8957122b7de423901e9a59775f64f7fccad23580
~~~

### Linux

~~~bash
# Open Red Hat Firewall 
# List all firewall rules
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --reload
sudo systemctl status firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld
~~~

### Azure Quotas

2 Windows (Windows Server 2019 Datacenter), Standard B8ms (8 vcpus, 32 GiB memory)
6 Linux, Standard D2s v5 (2 vcpus, 8 GiB memory)
= 2*8 + 6*2 = 28 vcpus
~30 vcpus/per table
8 VMs in total per user
8 public IPs per user + 1 for the load balancer + 1 for the bastion host = 10 public IPs per user

Per Table
- 10 public IPs
- 8 VMs
- 30 vcpus

### screen capture and mp4 to animated gif

Screen capture with Microsoft [Clipchamp](https://clipchamp.com/en/screen-recorder/)
<<<<<<< HEAD

~~~bash
=======
~~~bash

>>>>>>> 8957122b7de423901e9a59775f64f7fccad23580
# Install ffmpeg on Ubuntu
sudo apt install ffmpeg -y
# Install imagemagick
sudo apt install imagemagick -y
<<<<<<< HEAD
# Install gifsicle
sudo apt install gifsicle -y

cd resources
# verify video size
ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 ./media/mh.linux.login.mp4 # 1280x720
# increase imagemagick memory limit
free -h # 2.0G
sudo nano /etc/ImageMagick-6/policy.xml
sudo sed -i 's/<policy domain="resource" name="memory" value="256MiB"\/>/<policy domain="resource" name="memory" value="2GiB"\/>/g' /etc/ImageMagick-6/policy.xml
chmod +x ./resources/mp4togif.sh

# convert mp4 to gif
./mp4togif.sh ./media/mh.linux.login.mp4 ./media/mh.linux.login.gif
mv ./media/mh.linux.login.gif ../walkthrough/challenge-1/img/mh.linux.login.gif

./mp4togif.sh ./media/mh.linux.lb.test.mp4 ./media/mh.linux.lb.test.gif
mv ./media/mh.linux.lb.test.gif ../walkthrough/challenge-1/img/mh.linux.lb.test.gif

./mp4togif.sh ./media/mh.linux.webserver.test.mp4 ./media/mh.linux.webserver.test.gif
mv ./media/mh.linux.webserver.test.gif ../walkthrough/challenge-1/img/mh.linux.webserver.test.gif
~~~


### Git

The `git stash` command allows you to temporarily save changes that you have made to your working directory but do not want to commit yet. It takes your modified tracked files and staged changes, saves them away for later use, and then reverts them to the state of the last commit.

The changes stashed away by this command can be listed with `git stash list`, inspected with `git stash show`, and restored (potentially on top of a different commit) with `git stash apply`. Calling `git stash` without any arguments is equivalent to `git stash push`. A stash is by default listed as "WIP on branchname …", but you can give a more descriptive message on the command line when you create one.

The modifications stashed away by this command can be reapplied using `git stash apply` or `git stash pop`. You can also drop a stash with `git stash drop` after you are done with it.

~~~bash
git remote show
git remote -v
git remote show origin
git remote add msft https://github.com/microsoft/MicroHack.git
# store uncommited changes via stash
git stash
# create new branch to add changes
git checkout -b typofix202403
# apply stashed changes
git stash apply
git status 
git add .
git commit -m "several fixes including changing Region"
git push --set-upstream origin typofix202403
gh pr create --title "typofix202403" --body "several fixes including changing Region" --base msft


~~~
=======
cd resources
chmod +x ./resources/mp4togif.sh
./mp4togif.sh ./media/mh.linux.login.mp4 ./media/mh.linux.login.gif
mv ./media/mh.linux.login.gif ../walkthrough/challenge-1/img/mh.linux.login.gif

./mp4togif.sh ./media/mh.linux.webserver.test.mp4 ./media/mh.linux.webserver.test.gif
mv ./media/mh.linux.webserver.test.gif ../walkthrough/challenge-1/img/mh.linux.webserver.test.gif

~~~



>>>>>>> 8957122b7de423901e9a59775f64f7fccad23580
