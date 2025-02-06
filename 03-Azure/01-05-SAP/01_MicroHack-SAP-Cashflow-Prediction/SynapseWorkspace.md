# Configure Synapse Workspace

## Introduction
In this part we'll configure the Synapse Workspace and install the Ingration Runtime on our Azure Virtual Machine. If you didn't install the Synapse workspace with the Terraform script (included by default) earlier you can deploy the Synapse Workspace following [these](DeploySynapseWorkspace.md) steps.

# Synapse Configuration
## Register Integration Runtime
The rest of the configuration is done via `Synapse Studio` which is shown on the `Overview` page:\
<img src="images/synapsews/openSynapseStudio.jpg">

To register the integration runtime click on manage:

<img src="images/irt/syn-irt1.png" height = 300>

* Click on `Integration runtimes`:
<img src="images/irt/syn-irt2.png">

* Click on `+ New`:

<img src="images/irt/syn-irt3.png" height=300>


* Choose `Azure, Self-Hosted`:

<img src="images/irt/syn-irt4-1.png" height = 400>

* Choose `Self-Hosted`:

<img src="images/irt/syn-irt4.png" height = 400>

* Choose a name for the runtime installation:

<img src="images/irt/syn-irt5.png" height = 400>

* You will receive two key values. Make sure to note these down, in the next step you need one of these keys

<img src="images/irt/syn-irt6.png" height=400>

* In `Option 2: Manual setup` you can download the integration runtime via `Step 1`. Click on the link and copy the URL from the URL bar. Paste this URL in `Microsoft Edge` on your Gateway VM.

Choose `Download`

<img src="images/irt/syn-irt7.png">

Select the latest version available:

<img src="images/irt/syn-irt8.png">

Choose `Next`. The download will start.

* Execute the MSI package and press `Next`, `Install` and `Finish`, after that you get the question for the `authentication key`:

<img src="images/irt/gw-irt1.png" height=400>

* Enter one of the keys you noted down earlier from the integration runtime setup and choose `Register`.

* Enter the name of the integration runtime node configured earlier, this is already completed by default

<img src="images/irt/gw-irt2.png" height=400>

* Choose `Finish`, this can take a few minutes.

<img src="images/irt/gw-irt3.png" height=400>

The installation is done and the node is connected and can be used.
You can now proceed with the [next](DataFlowConfig.md) step.
