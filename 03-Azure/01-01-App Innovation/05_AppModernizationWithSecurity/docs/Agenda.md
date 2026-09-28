# Two-day agenda

This workshop is practical and hands-on. The goal is not to finish every optional idea; it
is to get every table through the core modernization story and leave enough time to talk
about what changed.

The minimum useful run is **Challenge 1 plus Challenge 2**:

- **ch01** moves the catalog from one VM to Azure Container Apps, a managed database,
  Azure storage for images, and Azure Container Registry for the image build.
- **ch02** proves the new shape can scale under load and give capacity back afterwards.

Everything after that deepens the operating story: releases, traces, cloud security, and
agent-assisted incident response.

## Challenge 1 path choice

Challenge 1 has exactly two paths. Both end at the same target architecture and both ask
participants to author their own Bicep with GitHub Copilot.

| Path | Best for | Facilitator guidance |
| --- | --- | --- |
| **A — Modernize with GitHub Copilot** | Teams who want the realistic upgrade-and-containerize workflow | Recommend this as the default. It keeps the existing app and is usually faster. |
| **B — Rewrite with GitHub Copilot (spec-driven)** | Teams who want to try PRD-first development and compare AI-generated designs | Encourage only if the table understands that reviewing the PRD matters as much as writing code. |

If a table has several people, split the table between the two paths. The debrief is much
better when one pair can describe modernization while another describes rewrite tradeoffs.
Do not spend the debrief deciding which path was "right"; compare what each made easier
and riskier.

## Suggested two-day schedule

Assumes 09:00–17:00 both days with a 45-minute lunch and two 15-minute breaks.

### Day 1

| Time | Block | Notes |
| --- | --- | --- |
| 09:00–09:10 | **[Opening demo](Demo.md)** | Show the journey: legacy VM catalog, target Azure app, autoscale, pipeline, traces, and the incident story. Keep it fast. |
| 09:10–09:30 | Orientation | Explain resource groups, Just-in-Time RDP access, the two stacks, and the two Challenge 1 paths. Point to the [glossary](Glossary.md). |
| 09:30–10:30 | **[ch00 — choose a stack](../challenges/ch00.md)** | Participants pick `.NET 8 + SQL Server` or `Java 17 + PostgreSQL`, connect to the matching VM, and confirm the legacy app runs. |
| 10:30–10:45 | Break | Use the break to unblock RDP and MFA problems. |
| 10:45–12:30 | **[ch01 — modernization block 1](../challenges/ch01.md)** | Tables choose [ch01-A](../challenges/ch01-A.md) or [ch01-B](../challenges/ch01-B.md). Encourage small checkpoints: app still runs, database connects, image builds. |
| 12:30–13:15 | Lunch | Ask tables to compare path choices informally. |
| 13:15–15:15 | **ch01 — modernization block 2** | Focus on getting the managed database, container image, and first Container App deployment working. |
| 15:15–15:30 | **ch01 debrief** | Split-path comparison: what did Copilot help with, what needed human review, and what would you do differently at work? |
| 15:30–15:45 | Break | Reset the room before load testing. |
| 15:45–17:00 | **[ch02 — load and autoscaling](../challenges/ch02.md)** | Run the first load test, watch replicas and database pressure, and discuss scale-to-zero tradeoffs. |

### Day 2

| Time | Block | Notes |
| --- | --- | --- |
| 09:00–09:15 | Day 2 kickoff | Confirm each team has a working Container App URL, managed database, image access, and health checks. |
| 09:15–11:15 | **[ch03 — CI/CD and revisions](../challenges/ch03.md)** | Build the GitHub Actions flow with OIDC, staging revision, approval, promotion, and rollback. |
| 11:15–11:30 | Break | Check that GitHub environments and Azure federated credentials are in place. |
| 11:30–12:45 | **[ch04 — observability](../challenges/ch04.md)** | Add OpenTelemetry and Application Insights. Show traces before polishing dashboards. |
| 12:45–13:30 | Lunch | Ask teams to name one signal they wish the VM had produced. |
| 13:30–15:00 | **[ch05-defender — security posture](../challenges/ch05-defender.md)** | Read Defender for Cloud findings and decide what should be fixed first. Keep it read-only unless the guide says otherwise. |
| 15:00–15:15 | Break | Decide whether ch06 is hands-on or facilitator-led. |
| 15:15–16:15 | **[ch06-sre-agent — incident](../challenges/ch06-sre-agent.md)** | Let the agent investigate, challenge its reasoning, and approve only the safe recovery action. |
| 16:15–16:40 | **[Wrap-up](../challenges/wrapup.md)** | Fill the before/after scorecard while the numbers are fresh. |
| 16:40–17:00 | Closing debrief | Round the room: what surprised you, and what will you try on Monday? |

## Time levers

1. **Protect ch01 and ch02.** If the room is slow, shorten later chapters before cutting the
   core migration and autoscale story.
2. **Default to path A when time is tight.** Path B is valuable, but PRD review and rewrite
   iterations can expand quickly.
3. **Make ch06 facilitator-led for large cohorts.** One shared incident on screen still
   teaches the reasoning loop: observe, ask the agent, verify, approve.
4. **Use portal views when commands would slow the room down.** Metrics, revisions, traces,
   and Defender findings all demo well from the portal.
5. **Keep optional work optional.** [ch07-enterprise](../challenges/ch07-enterprise.md)
   and [ch07-innovation](../challenges/ch07-innovation.md) are excellent follow-up
   exercises, not prerequisites for a successful two days.

## The useful waiting time in ch02

Autoscaling has real delays. Use them deliberately.

| Wait | What is happening | What to do with the room |
| --- | --- | --- |
| Baseline period | Azure Monitor records the one-replica starting point | Explain revisions, traffic splits, and OIDC before ch03. |
| Load run | Requests hit `/perftest/catalog` with an `x-api-key` header | Watch the Container App **Replicas** metric and database CPU together. |
| Scale-down | The app waits out its cooldown window | Discuss which scale signal each team would use for its own application. |

## If you have three days

Give Challenge 1 a full day, run Challenges 2 through 6 at a calmer pace across days two
and three, and leave the optional ch07 tracks as stretch work. The story stays the same;
you simply get more room for review, troubleshooting, and comparison.
