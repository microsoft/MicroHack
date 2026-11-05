# Migrate and Secure to be ready for AI Ops

[Previous Challenge](challenge-08.md) - **[Home](../Readme.md)**

## Congratulations

You finished *Migrate and Secure to be ready for AI Ops*.

*From secure migration to agent-assisted cloud operations.*

You followed the complete storyline: discover, assess, plan, migrate, secure, operate intelligently, and replatform. The final target includes an independently operating App Service web app, while Azure Monitor provides telemetry and alerting for the migrated VM estate.

The final architecture keeps App Service independent of the migrated VM networking. For the static demo workload, Azure Storage static website hosting or Azure Static Web Apps should also be evaluated before choosing a production target.

Keep `<YOUR-LAB-RESOURCE-GROUP>` throughout Challenges 2–8. Cleanup after this finish is optional and must be approved by the lab owner. Stopping a VM or web app does not necessarily stop all charges.

The lab uses **one resource group** for both the simulated source environment and migrated workloads, plus monitoring and App Service. Deleting that group removes **all** of them, not just the source. Before an approved deletion, use the supported Azure Migrate test-migration cleanup and complete-migration/stop-replication actions, then remove any backup protection or retained recovery data through the relevant service's cleanup workflow. Backup and replication dependencies can block deletion; do not bypass their safeguards.

Azure Monitor's automatically created `MA_*_managed` group is service-managed. Manage its lifecycle by deleting the parent Azure Monitor workspace through the supported workflow, not by separately deleting its internals. Do not delete shared subscription resources or change instructor-managed Defender plans.

Thank you for investing the time.
