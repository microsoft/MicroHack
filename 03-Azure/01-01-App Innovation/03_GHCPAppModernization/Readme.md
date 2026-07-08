# **App Modernization with GitHub Copilot**

- [**MicroHack introduction**](#microhack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack teaches you to **drive application modernization with AI tooling**. You will use GitHub Copilot **Custom Agents**, **Skills**, and **MCP (Model Context Protocol)** servers, together with the GitHub Copilot **App Modernization** extensions, to modernize a legacy **.NET Framework** application and a legacy **Java / Spring Boot** application and move them to Azure.

You start by building the AI foundation (agents, skills, MCP), then apply it to two real applications shipped in [`src/`](src/): **Contoso University** (.NET) and **Asset Manager** (Java).

This lab is not a full explanation of app modernization as a discipline. The following are recommended pre-reading:

- [GitHub Copilot app modernization for .NET](https://learn.microsoft.com/dotnet/core/porting/github-copilot-app-modernization-overview)
- [GitHub Copilot app modernization for Java](https://learn.microsoft.com/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java)
- [Model Context Protocol](https://modelcontextprotocol.io/)

# MicroHack context

Modernization is a **multi-step, knowledge-heavy workflow**: assess → plan → execute → validate. AI coding agents are good at executing steps, but out of the box they lack a defined role and guardrails (Custom Agent), reusable domain knowledge (Skills), and tools to act on the real world (MCP servers). This MicroHack shows how those three pieces combine into a repeatable, gated modernization playbook — and then applies it to a .NET and a Java workload.

> 📖 Concept primer: [docs/00-fundamentals.md](docs/00-fundamentals.md)

# Objectives

After completing this MicroHack you will:

- Explain how Custom Agents, Skills, and MCP fit together in an AI-assisted modernization workflow.
- Author a **Custom Agent** (`.agent.md`) with a phased, gated workflow and a least-privilege tool allow-list.
- Author a **Skill** (`SKILL.md`) that packages modernization domain knowledge with explicit `WHEN:` triggers.
- Configure **MCP servers** (`mcp.json`) that give the agent modernization tools (assessment, build, CVE checks, deployment).
- Run an end-to-end **assess → plan → execute → validate** loop to upgrade a .NET Framework app to **.NET 9** and a Java 8 / Spring Boot 2.x app to **Java 21 / Spring Boot 3.x**, and deploy to Azure.

# MicroHack challenges

## General prerequisites

This MicroHack has a few but important prerequisites.

In order to use the MicroHack time most effectively, the following should be completed prior to the session:

- **VS Code** (latest) with **GitHub Copilot** + **GitHub Copilot Chat** extensions, agent mode enabled
- **Visual Studio 2022** (latest) for the .NET challenge
- GitHub Copilot **App Modernization** extensions:
  - *App Modernization for Java* (`vscjava.migrate-java-to-azure`)
  - GitHub Copilot **app modernization for .NET** (Visual Studio "Modernize" flow)
- **Azure subscription** with **Contributor** on your resource group (for the deploy steps)
- **.NET SDK 9**, **Java 17/21 + Maven**, **Docker Desktop**

## Repository layout

```
03_GHCPAppModernization/
├── docs/
│   └── 00-fundamentals.md          # Concepts: Custom Agents, Skills, MCP
├── templates/                      # Generic + pre-tailored templates
│   ├── agents/                     # Custom Agent templates (generic, .NET, Java)
│   ├── skills/                     # Skill templates (generic, skill-creator, .NET, Java)
│   └── mcp/                        # MCP server configuration template
├── challenges/                     # Challenge instructions
├── walkthrough/                    # Step-by-step solutions
└── src/                            # Sample apps: ContosoUniversity (.NET), AssetManager (Java)
```

## Challenges

* [Challenge 1 - Fundamentals: Custom Agents, Skills & MCP](challenges/challenge-01.md)  **<- Start here**
* [Challenge 2 - Modernize a .NET Application](challenges/challenge-02.md)
* [Challenge 3 - Modernize a Java Application](challenges/challenge-03.md)
* [Finish](challenges/finish.md)

## Solutions - Spoilerwarning

* [Solution 1 - Fundamentals](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - .NET Application](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Java Application](./walkthrough/challenge-03/solution-03.md)

# Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
