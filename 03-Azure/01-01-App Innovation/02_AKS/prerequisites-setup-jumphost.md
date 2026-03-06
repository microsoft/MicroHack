# Exercise 0: Setup Your Environment - Resource Group and Jumphost

## Objective
In this exercise, you will create an Azure Resource Group to organize your lab resources, and then set up a jumphost (virtual machine) in Azure that will serve as your management environment for the rest of the lab. This VM will have all the necessary tools pre-installed to work with Azure Kubernetes Service (AKS).

## Prerequisites
- Make sure you have an active Azure subscription. 
- Access to the Azure Portal (https://portal.azure.com)

## Variables

Throughout this lab, you'll use consistent naming with your initials for uniqueness:

```bash
export YOUR_INITIALS="<yourinitials>"  # e.g., js for John Smith
export RESOURCE_GROUP="rg-aks-lab-${YOUR_INITIALS}"
export LOCATION="francecentral"
export VM_NAME="vm-aks-jumphost-${YOUR_INITIALS}"
export ACR_NAME="acrakslabacr${YOUR_INITIALS}"
export AKS_CLUSTER_NAME="aks-lab-${YOUR_INITIALS}"
```

**Note**: Replace `<yourinitials>` with your actual initials in lowercase (e.g., `js` for John Smith).

## Tasks

### Task 1: Create an Azure Resource Group

1. **Sign in to Azure Portal**
   - Navigate to https://portal.azure.com
   - Sign in with your Azure credentials

2. **Define your naming convention**
   
   Throughout this lab, you'll use your initials in resource names to ensure uniqueness.
   
   - Format: `rg-aks-lab-<yourinitials>`
   - Example: `rg-aks-lab-js` (for John Smith)
   - Location: `francecentral`

3. **Create the resource group using Azure CLI** (if you have Azure CLI installed locally)
   
   ```bash
   az login
   az account show
   
   az group create \
     --name $RESOURCE_GROUP \
     --location $LOCATION
   ```

4. **Or create via Azure Portal**
   
   - Search for "Resource groups" in the Azure Portal
   - Click "+ Create"
   - Select your subscription
   - Enter the resource group name: `rg-aks-lab-<yourinitials>` (e.g., `rg-aks-lab-js`)
   - Select region: **France Central**
   - Click "Review + create"
   - Click "Create"

5. **Verify the resource group**
   
   - You should see your resource group listed in the Azure Portal
   - Note the name and location for use in the next task

### Task 2: Create a Jumphost Virtual Machine

1. **Navigate to Azure Portal**
   - Sign in to the Azure Portal
   - Click on "Create a resource" or use the search bar to find "Virtual Machine"

2. **Configure the VM**
   - **Subscription**: Select your subscription
   - **Resource Group**: Select the resource group you just created (e.g., `rg-aks-lab-js`)
   - **Virtual Machine Name**: Choose a name with your initials (e.g., `vm-aks-jumphost-js`)
   - **Region**: **(Europe) France Central** (same as your resource group)
   - **Image**: **Ubuntu Server 24.04 LTS - x64 Gen2**
   - **Size**: **Standard_D2s_v3** (2 vCPUs, 8 GB RAM)
   - **Authentication**: Select **Password**
   - **Username**: Choose a username you'll remember (e.g., `azureuser`)
   - **Password**: Create a strong password you'll remember

3. **Networking Configuration**
   - **Public IP**: Create a new Public IP
   - **Inbound port rules**: Allow SSH (port 22)
   - Leave other settings as default

4. **Review and Create**
   - Click "Review + create"
   - Once validation passes, click "Create"
   - Wait for the deployment to complete (2-5 minutes)

5. **Alternative: Create VM using Azure CLI**
   
   If you prefer using the CLI:
   
   ```bash
   read -s -p "Enter VM password: " PASSWORD
   
   az vm create \
     --resource-group $RESOURCE_GROUP \
     --name $VM_NAME \
     --location $LOCATION \
     --image Ubuntu2404 \
     --size Standard_D2s_v3 \
     --admin-username <your-username> \
     --admin-password "$PASSWORD" \
     --public-ip-sku Standard
   ```

6. **Get the VM Public IP**
   
   ```bash
   az vm show \
     --resource-group $RESOURCE_GROUP \
     --name $VM_NAME \
     --show-details \
     --query "publicIps" \
     -o tsv
   ```

### Task 3: Connect to Your Jumphost

1. **Get Connection Information**
   - Go to your VM resource in the portal
   - Note the Public IP address

2. **Connect via SSH**
   ```bash
   ssh <your-username>@<public-ip-address>
   ```
   
   Enter your password when prompted.

### Task 4: Run the Configuration Script

Once connected to your jumphost, run the following commands to set up your environment:

1. **Download the configuration script located under resources / exercice-00 / setup-script.sh**

2. **Make the script executable**
   ```bash
   chmod +x setup-script.sh
   ```

3. **Execute the configuration script**
   ```bash
   ./setup-script.sh
   ```

   This script will install:
   - Azure CLI (`az`)
   - kubectl (Kubernetes command-line tool)
   - Docker and Docker Compose
   - Helm (Kubernetes package manager)
   - K9s (terminal-based Kubernetes UI)
   - GitHub CLI (`gh`)
   - Other useful utilities (git, curl, etc.)

4. **Verify the installation**
   
   **Note**: After the script completes, you may need to log out and log back in for Docker permissions to take effect:
   ```bash
   exit
   ```
   Then reconnect via SSH.
   
   **Important**: After reconnecting, re-export your environment variables:
   ```bash
   export YOUR_INITIALS="<yourinitials>"
   export RESOURCE_GROUP="rg-aks-lab-${YOUR_INITIALS}"
   export LOCATION="francecentral"
   export VM_NAME="vm-aks-jumphost-${YOUR_INITIALS}"
   export ACR_NAME="acrakslabacr${YOUR_INITIALS}"
   export AKS_CLUSTER_NAME="aks-lab-${YOUR_INITIALS}"
   ```
   
   Check Azure CLI:
   ```bash
   az --version
   ```

   Check kubectl:
   ```bash
   kubectl version --client
   ```

   Check Docker:
   ```bash
   docker --version
   ```
   
   Check Helm:
   ```bash
   helm version
   ```
   
   Check K9s:
   ```bash
   k9s version
   ```

### Task 5: Login to Azure

1. **Authenticate with Azure**
   ```bash
   az login
   ```
   
   Follow the instructions to complete the authentication process. If you're working from a remote VM without a browser, use:
   ```bash
   az login --use-device-code
   ```

2. **Verify your subscription**
   ```bash
   az account show
   ```

3. **Set the correct subscription (if you have multiple)**
   ```bash
   az account list --output table
   az account set --subscription "<subscription-id>"
   ```

### Task 6: Set Default Azure Configuration

To avoid specifying resource group and location repeatedly:

```bash
az configure --defaults group=$RESOURCE_GROUP
az configure --defaults location=$LOCATION
az configure --list-defaults
```

### Task 7: Download Lab Resources

1. **Clone the lab repository**
   ```bash
   cd ~
   git clone https://github.com/fabricekrebs/aks-for-beginners.git
   cd aks-for-beginners
   ```

## Verification

Before moving to the next exercise, ensure:
- [ ] Your resource group is created in France Central
- [ ] Your jumphost VM is running in the resource group
- [ ] You can connect to the VM via SSH
- [ ] Azure CLI is installed and you're logged in
- [ ] kubectl is installed
- [ ] Docker is installed
- [ ] Helm is installed
- [ ] K9s is installed

## Expected Output

When you run `az account show`, you should see your subscription details in JSON format.
When you run `kubectl version --client`, you should see the client version information.
When you run `helm version`, you should see the Helm version information.

## Next Steps

Once your environment is ready, proceed to [Exercise 1: Create Azure Container Registry and Push Images](01-create-acr-push-images.md)
