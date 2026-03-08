subscription_id=$(az account show --query id --output tsv)
echo "Using subcription ID: $subscription_id"

# Create a service principal with the name "mh-arc-aks-onprem" and assign it the "Contributor" role
# service_principal=$(az ad sp create-for-rbac -n "mh-arc-aks-onprem" --role "Contributor" --scopes /subscriptions/$subscription_id)
# echo "created service principal: $service_principal"

# Extract client_id and client_secret from the service_principal JSON output
# client_id=$(echo $service_principal | jq -r .appId)
# client_secret=$(echo $service_principal | jq -r .password)

# echo "replacing client_id and client_secret in fixtures.tfvars..."
# # Replace client_id and client_secret in fixtures.tfvars
# sed -i "s|client_id=\".*\"|client_id=\"$client_id\"|" fixtures.tfvars
# sed -i "s|client_secret=\".*\"|client_secret=\"$client_secret\"|" fixtures.tfvars

echo "replacing subscription_id in provider.tf..."
# replace the subscription id in provider.tf
sed -i "s|subscription_id = \".*\"|subscription_id = \"$subscription_id\"|" provider.tf

