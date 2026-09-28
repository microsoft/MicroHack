# Wrap-up: what you moved and why it matters

You started with a small catalog application on a single virtual machine. You finish with
the same business capability running on managed Azure services, with a path to deploy,
observe, secure, and recover it.

This chapter is a short human retrospective. No files to generate, no scorecard to pass —
just a conversation about what changed and what you would take back to your own estate.

## The shape changed

| Before: legacy VM shape | After: Azure shape |
| --- | --- |
| App and database lived on one machine | App runs as a container on Azure Container Apps |
| Local SQL Server Express or PostgreSQL on the host | Managed Azure SQL Database serverless or PostgreSQL Flexible Server |
| Product images served from local disk | Images moved to Azure storage or another cloud-friendly static-content path |
| Manual build, copy, restart, and hope | Repeatable build and deployment flow |
| Scaling meant changing the VM | Container Apps can scale instances for traffic |
| Troubleshooting started by logging onto the box | Telemetry, logs, traces, and health endpoints guide investigation |
| Security posture was mostly unknown | Defender for Cloud and your own review expose what remains |
| Recovery depended on host access and backups | Rollback and SRE exercises give you a practiced recovery story |

## Discuss at your table

1. **Which Challenge 1 path did you take?** If your table split, compare Path A
   [modernization](ch01-A.md) with Path B
   [spec-driven rewrite](ch01-B.md). Which felt safer? Which
   taught more? Which would you use on a real app?
2. **What was the most important change?** The container, managed database, image storage,
   pipeline, telemetry, security review, or SRE Agent may matter differently to different
   organizations.
3. **What stayed harder than expected?** Name the manual steps, brittle assumptions, or
   missing permissions that slowed you down.
4. **What would need to be true before production?** Think backups, private networking,
   identity, cost controls, DR, on-call ownership, data migration, and compliance review.
5. **What did GitHub Copilot do well?** Also name where you had to slow it down, correct
   it, or ask for a smaller step.
6. **What would you measure next?** Performance, release frequency, recovery time, cost,
   security findings, or user satisfaction?

## Take it home

- Start with one application that people are afraid to touch. A small, visible win builds
  more trust than a platform diagram nobody uses.
- Keep the old behavior clear before changing the architecture. Modernization succeeds
  when users still recognize the app.
- Move state out of the compute layer early: database, images, secrets, and configuration
  each deserve their own home.
- Automate the path you expect people to repeat. A one-off migration is a project; a
  repeatable deployment is a capability.
- Treat observability and recovery as features. If you cannot explain an incident or roll
  back safely, the migration is not finished.
- Use the optional enterprise and innovation challenges as backlog ideas, not as proof that
  every production concern is solved.

## Clean up

Your workshop resources are temporary. If the facilitator owns the subscription, they will
usually delete the resource groups after the event. If you created resources in your own
subscription, delete them now or set a reminder before paid services surprise you.

Keep notes, prompts, diagrams, and decisions that would help your real team repeat the
journey. Delete credentials, local secrets, and any workshop-only access.

## What you proved

You took an application from a fragile host-centered design to a service-centered Azure
design. More importantly, you practiced the engineering conversations around that move:
what to keep, what to replace, what to automate, what to measure, and what still needs a
human owner.

That is the part you can reuse on Monday.

---

**Previous:** [ch06-sre-agent](ch06-sre-agent.md) · **Optional challenges:** [ch07-enterprise](ch07-enterprise.md) or [ch07-innovation](ch07-innovation.md) · **Back to:** [workshop overview](../README.md)
