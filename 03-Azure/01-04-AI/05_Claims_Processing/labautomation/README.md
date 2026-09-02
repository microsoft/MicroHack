---
title: Lab Automation
description: Deployment entry points for the ClaimSight Claims MicroHack
---

## Files

* `deploy-lab.ps1` provisions the lab resources and returns Hackbox credentials.
* `get-keys.sh` creates a participant's repository-root `.env` from the deployed lab.
* `lab-defaults.json` declares the MicroHack deployment defaults.
* `azuredeploy.json` defines the Azure resources provisioned for each lab.

## Infrastructure

The ARM template is stored in [`azuredeploy.json`](./azuredeploy.json) alongside the
other platform-controlled deployment assets.