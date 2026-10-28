# Deploy the Inventory Planning Assistant (Challenge 5, Part A)

In this step you deploy a small app that runs your three agents from Challenges 2–4 in order and returns a purchase order proposal. You do it from **Azure Cloud Shell** in your browser. Nothing is installed on your computer, and it takes about 15 minutes.

> Facilitators and developers: see the [facilitator guide](FACILITATOR.md).

## Before you start

- Your three agents are **saved** and use **Fabric IQ** (Challenges 2–4).
- Your Fabric capacity is **running**.
- Your lab dashboard is open. You need one value from it: **ResourceGroupName**.

## Step 1: Open Cloud Shell

1. Open a private window (Edge InPrivate or Chrome Incognito).
2. Sign in to the [Azure portal](https://portal.azure.com/) with your **lab account**.
3. Select the Cloud Shell icon (`>_`) at the top, or open [Cloud Shell](https://shell.azure.com/powershell), and choose **PowerShell**. If you are asked about storage, choose the option without storage if you can.

> [!IMPORTANT]
> Never type your Temporary Access Pass (TAP) in the terminal. Enter it only on the Microsoft sign-in page.

## Step 2: Download the lab files

This copies only this lab's folder from GitHub (about 8 MB) into Cloud Shell, then moves you into it. It takes a few seconds.

```powershell
git clone --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MicroHack inventory-microhack
Set-Location ./inventory-microhack
git sparse-checkout set 03-Azure/01-04-AI/02_Inventory_Planning_Fabric
Set-Location ./03-Azure/01-04-AI/02_Inventory_Planning_Fabric/orchestrator
```

If your facilitator gives you a release tag, add `--branch <tag>` after `--sparse` in the first command.

## Step 3: Deploy and check

Replace `<ResourceGroupName>` with the value from your lab dashboard, then run:

```powershell
./Start-ParticipantDeployment.ps1 -ResourceGroupName '<ResourceGroupName>' -VerifyHosted
```

What this does:

1. Finds your Foundry project and your Fabric IQ connection in that resource group.
2. Saves a copy of your three agents' instructions for the app to use.
3. Deploys the app, `inventory-planning-assistant`, into your Foundry project (about 3 minutes).
4. Tests it with a full planning conversation, so you know it works before you try it (about 5–8 minutes).

The first run also prepares some tools, so you will see a lot of text scroll past. That is normal. During the test you will see lines like `Turn 3/12 passed`. The planning turns take 2–4 minutes each, so wait while the screen looks quiet.

You are done when you see:

```text
PASS: hosted multi-turn checks.
```

Go back to [Challenge 5, Part B](../challenges/challenge-05.md#part-b--run-the-complete-planning-loop-10-min) to run the assistant.

> [!NOTE]
> The deployment also saves new versions of your three agents (for example version 3 instead of 2). That is expected. If you change an agent later, run Step 3 again so the assistant uses the new version.

## If something goes wrong

| What you see | What to do |
|--------------|------------|
| `Select the assigned lab subscription` | Cloud Shell is using a different subscription. Run `az account list -o table`, then `az account set --subscription '<lab subscription id>'` (ask your facilitator which one it is), and repeat Step 3. |
| `No Fabric IQ connection found` | Add **Fabric IQ** to your `demand-sensing-agent` as in Challenge 2, **Save**, then repeat Step 3. |
| `More than one Fabric IQ connection found` | Repeat Step 3 with `-FabricIQConnectionName '<one of the names shown>'` added. |
| `Project not found` | Wait a few minutes and repeat Step 3. If it happens again, tell your facilitator. |
| Permission denied | Tell your facilitator. Don't ask for Owner access. |
| Cloud Shell timed out or the lab files are gone | Reopen Cloud Shell and repeat Steps 2 and 3. |
| The check fails and mentions Fabric | Make sure your Fabric capacity is **running** and your Data Agent is **published**, then repeat Step 3. Give your facilitator the request ID from the error if it keeps failing. |
