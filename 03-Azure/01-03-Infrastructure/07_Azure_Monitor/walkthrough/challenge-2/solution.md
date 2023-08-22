# Walkthrough Challenge 2

*Duration: 30 Minutes*

## Task 1: Enable VM Insights for `vm-linux`

- Enable VM Insights on monitored machines

    ![Create DCR](./img/task_01_a.png)

- Create a Data Collection Rule and configure to use the Log Analytics Workspace and enable processes and dependencies (Map)

    ![Create DCR](./img/task_01_b.png)

    ![Create DCR](./img/task_01_c.png)

- View Performance tab after successful deployment

    ![Verify DCR](./img/task_01_d.png)

## Task 2: Enable VM Insights on unmonitored `vm-windows`

- From Azure Monitor blade there is a way to enable VM Insights, too.
- From the Monitor menu in the Azure portal, select Virtual Machines > Overview > Not Monitored.

    ![Create DCR](./img/task_02_a.png)

    ![Create DCR](./img/task_02_b.png)

    ![Create DCR](./img/task_02_c.png)

    ![Verify](./img/task_02_d.png)

## Task 3: Enable VM Insights for `vmss-linux-nginx` automatically

- Enable VM Insights for th VMSS by using Azure Policy
- VM insights policy initiatives install Azure Monitor Agent and the Dependency agent on new virtual machine scale set in your Azure environment.
- Assign these initiatives to the resource group `rg-monitoring-microhack` to install the agents on the virtual machines in the defined scope automatically.

## Task 4: Log search and visualize
