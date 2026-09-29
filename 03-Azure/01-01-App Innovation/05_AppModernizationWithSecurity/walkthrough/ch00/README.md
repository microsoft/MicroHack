# ch00: Meet the application you are about to move

There is not much to solve here — this challenge is about looking, not building. What
follows is the answer key: what you should have seen, and where to find it.

## The two stacks

| | `dotnet-sqlserver` | `java-postgresql` |
| --- | --- | --- |
| VM | `vm-dotnet-userNNN` | `vm-java-userNNN` |
| Application | .NET 8 Blazor Server | Spring Boot 3 on Java 17 |
| Database | SQL Server 2022 Express, same VM | PostgreSQL 18, same VM |
| Local URL | `http://localhost:5000` | `http://localhost:8080` |
| Source | [`dotnet/README.md`](../../dotnet/README.md) | [`java/README.md`](../../java/README.md) |

Both applications implement the same catalog: **198 figures across 20 categories**, one PNG
per figure, with search, category filtering, a detail page, and an import form.

## What the application exposes

| Route | Behaviour |
| --- | --- |
| `GET /` | The catalog, with optional `search` and `category` query parameters |
| `GET /figure/{id}` | Detail page, or 404 |
| `GET /images/{filename}` | The product photograph, or 404 |
| `GET /import` · `POST /import` | Upload form and transactional import |
| `GET /healthz` | Liveness — is the process alive? |
| `GET /readyz` | Readiness — can it reach the database? |
| `GET /perftest/catalog` | Bounded database workload, protected by the `x-api-key` header. Used in ch02 |

`/healthz` and `/readyz` are always true together on the VM, because the database is the
same machine. That distinction only starts to matter once the database moves away — which
is exactly what happens in ch01.

## Where everything lives on the VM

| Thing | Where it is today | Why that is a problem |
| --- | --- | --- |
| The application | Started by a scheduled task on one box | One instance, no autoscale, no failover |
| The database | A local service on the same box | A noisy query starves the web tier |
| 198 photographs | A folder on the C: drive | Rebuild the VM and they are gone |
| The connection string | A config file on the server | A credential sitting on disk |
| Diagnostics | One text log file | Your entire answer to "why was it slow last Tuesday?" |

Every one of those is something you move somewhere else over the rest of the workshop.

## How a change ships today

Fixing one wrong label on the catalog page means, roughly: change it locally, build,
publish, get the output onto the VM, raise a change ticket, wait for approval, wait for the
change window, connect over RDP, copy the current app folder somewhere safe, back up the
database, stop the scheduled task, wait for the process to exit, swap the files, start the
task, and click round the site to see whether it worked.

Fourteen steps, and every one of them is a person. Undoing it is another six — and only if
you remembered the two backup steps.

Keep that number in mind. In ch03 you replace all of it with a pipeline and an approval
button.

## Getting in with JIT

Standing inbound RDP rules are removed automatically by tenant governance, so JIT is the
supported route:

1. Azure Portal → your resource group `rg-userNNN` → your VM → **Connect**. Accept the
   offer to enable **Just-in-time access** if it appears.
2. Otherwise: **Microsoft Defender for Cloud → Just-in-time VM access → Not Configured →
   Enable JIT on 1 VM**. Keep the default port 3389 rule.
3. On the **Configured** tab, tick your VM → **Request access** → port 3389, source **My
   IP** → **Open ports**.
4. Back on **Connect → RDP**, download the `.rdp` file and sign in.

You enable JIT once per VM; you request access as often as you need it. If your public IP
changes during the day, request again.

## Facilitator notes

- Each participant gets a resource group `rg-userNNN` containing both VMs. Leave the
  unused one running — it costs little and people like to glance at the other stack.
- The applications start from scheduled tasks named `MicroHack-dotnet` and `MicroHack-java`.
  If a catalog page does not load, check the task and the local database service before
  anything else.
- Do not reseed or repair a participant's database during this challenge; a VM that did not
  provision cleanly is a rebuild, not a patch.

---

**Challenge:** [ch00](../../challenges/ch00.md) ·
**Next:** [ch01 — choose a path](../../challenges/ch01.md)
