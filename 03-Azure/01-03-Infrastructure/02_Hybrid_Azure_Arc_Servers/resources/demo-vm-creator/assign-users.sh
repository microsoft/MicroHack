#!/bin/bash

# Make sure to first create your VMs and resource groups with the create-vms-and-rgs.sh before running this script
# You can also use the create-and-assign.sh to run the scripts in sequence automatically

# Variables
resourceGroupforOnpremBase="mh-arc-onprem"
resourceGroupforArcBase="mh-arc-cloud"
password="REPLACE-ME"
number_of_participants=10

# Disable all Conditional access policies to enable frictionless login for participants
token=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken --output tsv)
policy_ids=$(az rest --method get \
  --uri https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies \
  --headers "Authorization=Bearer $token" \
  --query "value[].id" \
  --output tsv)

for id in $policy_ids; do
  echo "Disabling conditional access policy with ID: $id" 
  az rest --method patch \
    --uri https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$id \
    --headers "Authorization=Bearer $token" "Content-Type=application/json" \
    --body '{"state": "disabled"}'
done

# Create users and assign resource groups
tenant=$(az account show --query tenantDefaultDomain --output tsv)

for i in $(eval echo {0..$(($number_of_participants-1))}); do
    displayName="MHUser$i"
    userPrincipalName="MHUser$i@$tenant"
    resourceGroupOnpremId=$(az group show --name "$resourceGroupforOnpremBase-$i" --query "id" --output tsv) 
    resourceGroupArcId=$(az group show --name "$resourceGroupforArcBase-$i" --query "id" --output tsv)

    echo Creating user $displayName...
    az ad user create \
        --display-name "$displayName" \
        --user-principal-name "$userPrincipalName" \
        --password "$password"
    user=$(az ad user show --id "$userPrincipalName" --query "id" --output tsv)

    echo Assigning $displayName to resource groups...
    # Owner required in case we want to run SSH using Azure CLI
    az role assignment create --assignee "$user" --role "Owner" --scope "$resourceGroupOnpremId" --output none
    # Policy Contributer and RBAC write needed to assign DINE policies in challenge 7, requiring owner role
    az role assignment create --assignee "$user" --role "Owner" --scope "$resourceGroupArcId" --output none

done