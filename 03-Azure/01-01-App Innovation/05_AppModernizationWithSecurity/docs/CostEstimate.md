# Cost and capacity estimate

These are planning numbers, not a quote. Re-price them for your region, agreement, and
workshop dates before asking anyone to approve spend.

The important point is simple: the two facilitator-provisioned Windows VMs dominate the
bill. The modern Azure target is usually smaller, but optional Defender and SRE Agent work
can add noticeable cost if you leave it running.

## Quick assumptions

| Item | Assumption used here |
| --- | --- |
| Region | Sweden Central list pricing, USD, rounded |
| Participant footprint | Two `Standard_D2as_v5` Windows VMs, two Premium P10 OS disks, two Standard public IPs |
| Workshop window | Friday 17:00 provision, Monday/Tuesday delivery, Wednesday 10:00 teardown: 113 hours |
| Modernized workload | Created during ch01 and kept until teardown, roughly 42.5 hours |
| Stack split | 50% .NET / Azure SQL, 50% Java / PostgreSQL |
| Telemetry | 0.2 GB Log Analytics ingestion per participant per day |

Re-query meters with the Azure Retail Prices API when accuracy matters:

```bash
curl -s "https://prices.azure.com/api/retail/prices?currencyCode=USD&\$filter=serviceName%20eq%20'Virtual%20Machines'%20and%20armRegionName%20eq%20'swedencentral'"
```

## Unit prices to check

| Meter | Planning price |
| --- | ---: |
| Windows VM `Standard_D2as_v5` | about **$0.184/hour** |
| Premium SSD P10 OS disk, 127 GiB | about **$21.68/month** |
| Standard static public IP | about **$0.005/hour** |
| Azure Container Apps consumption | active vCPU/memory/request meters; small apps are usually low cost |
| Azure Container Registry Basic | about **$5/month** |
| Azure SQL Database serverless compute | about **$0.57/vCore-hour while active**; auto-pause matters |
| Azure SQL storage | about **$0.14/GB-month** |
| PostgreSQL Flexible Server B1ms | about **$0.02/hour**, plus storage; it does not auto-pause like SQL serverless |
| Log Analytics ingestion | about **$3/GB** |
| Azure Load Testing resource | confirm current monthly/resource pricing before delivery |
| Defender for Cloud paid plans | subscription/resource dependent; get explicit approval |
| Azure SRE Agent | billed by agent units for as long as the agent resource exists |

## Per participant per day

| Line | Cost/day | Notes |
| --- | ---: | --- |
| Two Windows VMs | **$8.83** | 2 × 24 h × $0.184 |
| Two P10 OS disks | **$1.43** | Disks bill even when VMs are stopped |
| Two public IPs | **$0.24** | RDP access path for the two VMs |
| **Base total** | **~$10.50/day** | Before any participant-created Azure target |

If you deliberately deallocate the unchosen VM after ch00, you save about **$4.42 per
participant per day** in VM compute. The disk and public IP still bill so the environment is
not free.

## Modernized workload comparison

Both ch01 paths end at the same architecture: container on Azure Container Apps, image in
ACR, images outside the app container, and a managed database.

| Line | .NET / Azure SQL | Java / PostgreSQL | Why |
| --- | ---: | ---: | --- |
| Container Apps | low | low | Consumption billing tracks actual CPU, memory, and requests. Scale-to-zero can make idle cost tiny. |
| Container Registry Basic | low | low | One small registry per participant is usually cents for a short workshop. |
| Database compute | higher when active | lower but always on | SQL serverless can auto-pause; PostgreSQL B1ms bills continuously. |
| Database storage | low | low | The 198-item catalog is tiny. |
| Log Analytics | workload-dependent | workload-dependent | Keep sampling and retention modest for a lab. |

For a day of active workshop use, a practical planning range is **~$6-7/day** for the
.NET/Azure SQL target and **~$2-3/day** for the Java/PostgreSQL target. The difference is
mostly database compute, not Container Apps.

Use this comparison honestly:

- Java/PostgreSQL often lands below the legacy VM's daily compute cost.
- .NET/Azure SQL may be similar to or above the legacy VM if SQL stays active all day.
- Azure SQL serverless looks much better for dev/test or intermittent workloads where
  auto-pause actually happens.
- The VM comparison excludes operational work: patching, backups, rollback, security review,
  and incident response.

## 30-person worked example

For 30 participants over the Friday-to-Wednesday window:

| Line | Cohort estimate |
| --- | ---: |
| Base VM compute, disks, and public IPs for 113 hours | **~$1,480** |
| Modernized workloads, 50/50 stack split | **~$250-550** |
| Azure Load Testing resources | **confirm; budget at least a few hundred dollars if each participant creates one** |
| Optional Defender paid plans | **depends on enabled plans and resource count** |
| Optional SRE Agent | **small for one shared demo, larger if every team gets an agent and nobody deletes it** |

A safe planning envelope for the Azure side of a 30-person delivery is **roughly
$2,000-$3,000**, before GitHub plan/Copilot licensing and before any month-bound Load
Testing or Defender charges you have approved separately.

## What changes the number most

1. **How long the VMs exist.** Every extra day adds about $315 for 30 participants before
   participant-created Azure resources.
2. **Whether unused VMs are deallocated.** Useful saving, but disks and IPs remain.
3. **Database activity.** Azure SQL serverless only saves money when it pauses.
4. **Telemetry volume.** Load tests can generate noisy traces; keep retention short.
5. **Paid plans.** Defender and SRE Agent are intentional teaching tools, not defaults to
   leave on forever.

## Budget and teardown

Create the budget before provisioning. Set alerts at 50%, 90%, and 100%, and send them to a
named person. A useful first budget is **1.5× your worked estimate**.

The most expensive scenario is forgetting cleanup. A 30-person cohort left running for a
month can cost five figures from the base VMs alone, and SRE Agent resources continue
billing until deleted. Follow teardown in [the facilitator guide](Facilitator.md).
