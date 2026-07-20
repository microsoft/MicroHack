# **Migrate & Modernize Applications with GitHub Copilot*#

- [**MicroHack introduction**](#microhack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack guides you through migrating and modernizing real-world applications to Azure using **GitHub Copilot App Modernization**. You will work across two technology stacks — **.NET** and **Java (Spring Boot)** — and use the **modernize CLI** agent to assess, upgrade, and deploy applications at scale.

The lab builds up progressively: you start by learning to author the AI foundation — **Custom Agents**, **Skills**, and **MCP** — then drive multi-repository assessment and framework upgrades from the command line, and finish by provisioning Azure infrastructure and deploying the modernized apps.

# MicroHack context

Modernizing legacy applications is often slow and error-prone: upgrading frameworks, resolving cloud readiness issues, replacing non-Azure dependencies, and standing up infrastructure all take significant manual effort. GitHub Copilot App Modernization uses AI to accelerate every phase of this journey — assessment, code upgrade, migration planning, and deployment — while keeping you in control through reviewable plans and pull requests.

Across the challenges you will work with **PhotoAlbum** and **PhotoAlbum-Java** — a .NET and a Spring Boot sample app that you upgrade and deploy to Azure using the modernize CLI.

# Objectives

After completing this MicroHack you will:

- Know how to author a **Custom Agent** (`.agent.md`), package a reusable **Skill** (`SKILL.md`), and configure **MCP** (`mcp.json`), and understand the gated assess → plan → execute → validate loop.
- Understand how to use the GitHub Copilot App Modernization agent (modernize CLI).
- Know how to assess applications for cloud readiness and framework upgrade opportunities.
- Be able to upgrade .NET and Java applications to their latest framework versions.
- Understand how to run batch assessments across multiple repositories.
- Know how to create a cloud modernization plan, resolve cloud readiness issues, and migrate dependencies (for example, Oracle to PostgreSQL).
- Be able to provision Azure infrastructure and deploy modernized apps to Azure Container Apps.

# MicroHack challenges

## General prerequisites

This MicroHack has a few but important prerequisites.

In order to use the MicroHack time most effectively, the following should be in place before you start:

- An **Azure Subscription** with permission to create resource groups and resources (Contributor or Owner).
- A **GitHub account** to fork the sample repositories.
- **Visual Studio Code** and/or a terminal with the **GitHub Copilot App Modernization agent (modernize CLI)** installed.
- **Docker Desktop**, **Git**, and the relevant SDKs (.NET and Java) installed locally.
- An active **GitHub Copilot** subscription.

## Challenges

* [Challenge 1 - Fundamentals: Custom Agents, Skills & MCP for App Modernization](challenges/challenge-01.md)  **<- Start here**
* [Challenge 2 - Batch Upgrade a Java App and a .NET App](challenges/challenge-02.md)
* [Challenge 3 - Modernize the Upgraded Apps and Deploy Them to Azure](challenges/challenge-03.md)
* [Finish](challenges/finish.md)

## Solutions - Spoilerwarning

* [Solution 1 - Fundamentals: Custom Agents, Skills & MCP for App Modernization](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - Batch Upgrade a Java App and a .NET App](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Modernize the Upgraded Apps and Deploy Them to Azure](./walkthrough/challenge-03/solution-03.md)

