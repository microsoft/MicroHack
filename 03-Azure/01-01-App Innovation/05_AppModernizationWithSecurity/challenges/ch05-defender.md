# Review your Defender for Cloud posture

## Goal

Your catalog now runs as a container on Azure Container Apps, uses a managed database, stores images outside the app, and pulls images from Azure Container Registry. That is better than the original VM, but it is not automatically secure.

Use Microsoft Defender for Cloud to read the posture of the old VM and the new Azure resources, then decide what to fix and what to deliberately accept.

## Before you start

- Keep using the stack you chose in [Challenge 0](ch00.md): .NET with Azure SQL, or Java with Azure Database for PostgreSQL.
- Your Challenge 1 deployment should still exist: Container App, Container Registry, managed database, image storage, and the retained legacy VM.
- In a shared subscription, do not enable or disable paid Defender plans unless the facilitator asks you to. You usually need `Security Reader` plus rights in your own resource group.
- New to the terms? Skim the [glossary](../docs/Glossary.md).

## Actions

- Open **Microsoft Defender for Cloud**. In **Environment settings**, inspect enabled plans: Defender CSPM (`CloudPosture`), Containers, Defender for Servers Plan 2 (`VirtualMachines`), `SqlServers`, and `OpenSourceRelationalDatabases`.
- For each resource, ask what Defender can actually see:

  | Resource | What to look for |
  | --- | --- |
  | Retained VM | Server posture, exposed SSH/RDP, update and endpoint recommendations |
  | Container App | Serverless container posture; no VM host sensor you can log into |
  | Container Registry | Image recommendations and whether admin credentials are enabled |
  | Azure SQL or PostgreSQL | Database plan coverage and public network exposure |

- Review **Recommendations**, **Secure score**, Microsoft Cloud Security Benchmark controls, and **Attack path analysis**. Empty results mean "nothing reported yet", not "safe forever".
- Decide what to do about four common findings:
  - ACR admin authentication.
  - Container App insecure HTTP.
  - Database public network access.
  - Public SSH/RDP to the retained VM.
- Use GitHub Copilot to explain unfamiliar recommendations and draft safe remediation commands, then verify before running them.

## Success Criteria

- You can describe what Defender sees for the VM, Container App, registry, and database.
- The ACR admin account is disabled and the app still pulls its image.
- Container App ingress is HTTPS-only.
- The database network posture and retained VM management access have an explicit decision.
- Your application still responds on its public URL after the changes.

## Solution - Spoilerwarning

[Solution Steps](../walkthrough/ch05-defender/README.md)

---

**Challenge:** [ch05-defender](ch05-defender.md) · **Previous:** [ch04](ch04.md) · **Next:** [ch06-sre-agent](ch06-sre-agent.md)
