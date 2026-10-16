# Glossary

Short definitions for terms participants meet during the workshop.

**ACR (Azure Container Registry)**
The private registry where your container image is built and stored. `az acr build` runs the build in Azure, so Docker is not required on the VM.

**Application Insights**
The Azure Monitor service used for request rates, dependencies, failures, logs, and traces from the catalog.

**Azure Container Apps (ACA)**
The serverless container platform that runs the modernized catalog. ACA handles ingress, revisions, replicas, scale rules, and traffic splitting.

**Bicep**
Azure's readable language for Infrastructure as Code. Participants write their own Bicep with GitHub Copilot instead of copying a shared template.

**Container App environment**
The hosting boundary around Container Apps. It provides the managed runtime, logging integration, networking boundary, and workload profile settings.

**Container image**
A packaged version of the application and its runtime dependencies. The image is built in ACR and deployed to ACA.

**Defender for Cloud**
Azure's security posture and recommendation service. Challenge 5 uses it to review what the migration exposed and which findings matter first.

**Federated credential**
The trust rule that lets GitHub Actions use OIDC to obtain an Azure token for a managed identity. It must match the repository, branch, and environment.

**GitHub OIDC**
Secretless authentication from GitHub Actions to Azure. GitHub sends a short-lived token; Azure checks it and grants only the roles assigned to the identity.

**JIT VM access**
Just-in-Time access opens RDP port 3389 to your current IP address for a limited time. The VMs start with RDP closed on purpose.

**KQL (Kusto Query Language)**
The query language used by Log Analytics and Application Insights to ask questions about operations, dependencies, and failures.

**Log Analytics workspace**
The Azure Monitor data store for logs and traces. Application Insights writes to a workspace, and queries run against that telemetry.

**Managed database**
A database service operated by Azure rather than installed on the VM. The .NET path targets Azure SQL Database serverless; Java targets Azure Database for PostgreSQL Flexible Server.

**Managed identity**
An Azure identity attached to a resource. It lets the Container App pull images, read storage, or access other Azure services without long-lived secrets in code.

**OTLP**
The OpenTelemetry Protocol. The application uses OTLP exporters to send telemetry to Azure Monitor / Application Insights.

**OpenTelemetry**
A vendor-neutral way to collect traces, metrics, and logs. Challenge 4 uses it to show requests and database calls across the new architecture.

**PRD (Product Requirements Document)**
The document created in the rewrite path before implementation. It describes the legacy behavior that the new app must preserve.

**Replica**
One running copy of a Container App revision. Scaling out adds replicas; scaling in removes them when demand falls.

**Revision**
An immutable version of a Container App's image and configuration. Changing the image or an environment variable creates a new revision.

**Scale rule**
The condition ACA watches to decide how many replicas to run. The workshop starts with HTTP/load signals and discusses when other signals would be better.

**Scale to zero**
Running no replicas while idle. It saves money, but the next request may wait while the app and database wake up.

**Spec-driven development**
The rewrite workflow where Copilot first helps describe desired behavior in a PRD, then uses that reviewed specification to plan and build the app.

**Traffic split**
The percentage of requests sent to each revision. Reversing the split is the fast rollback move.

**Workload profile**
The compute profile available inside a Container Apps environment. The workshop uses consumption-style behavior for the catalog so it can scale with demand.
