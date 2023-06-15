# Deploying the Lab Environment Services with Terraform

This Terraform code deploys all Azure services, including virtual machines, network components, application gateway, log analytics workspace, and others.

## Prerequisites

Before you begin, you must have the following:

- An active Azure subscription
- Terraform installed on your local machine
- Azure CLI installed on your local machine

## Getting Started

To get started, follow these steps:

1. Clone this repository to your local machine.
2. Open a command prompt or terminal window and navigate to the project directory `/prerequisites/terraform` of the cloned repository.
3. Run the following command to log in to your Azure account and set the desired Azure subscription:

    ```shell
    az login

    az account set --subscription <subscription-id>
    ```

4. Run the following command to initialize the Terraform working directory:

    ```shell
    terraform init
    ```

5. (Optional) Review and modify the configuration values for you deployment if necessary as per you requirements.
6. Execute a Terraform plan to preview the changes that will be applied:

    ```shell
    terraform plan
    ```

7. If the plan looks good, apply the changes to deploy the Azure infrastructure:

    ```shell
    terraform apply
    ```

8. Confirm the deployment by typing yes when prompted.

Once the deployment is complete, Terraform will output relevant information about the provisioned resources. You can also review the Azure portal to verify the successful creation of your infrastructure services.
