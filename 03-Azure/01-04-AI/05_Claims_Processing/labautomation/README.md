---
title: Lab Automation
description: Deployment entry points for the ClaimSight Claims MicroHack
---

## Files

* `deploy-lab.ps1` provisions the lab resources and returns Hackbox credentials.
* `lab-defaults.json` declares the MicroHack deployment defaults.

## Infrastructure

The ARM template is stored in [`../infrastructure/azuredeploy.json`](../infrastructure/azuredeploy.json)
so this platform-controlled directory contains only the permitted deployment assets.