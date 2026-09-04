# Challenge 09 - Model, review, and deploy with Radius Canvas

[< Previous Challenge](challenge-08.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-10.md)

Estimated time: 90-150 minutes | Difficulty: intermediate to advanced

## Challenge objective

Challenges 03-08 built the Adaptive Apps story from the platform side. You authored
resource-type contracts, implemented them with recipes, and deployed a hand-written
`iac/app.bicep` through two persistent Radius control planes.

This challenge approaches the same trading application from the developer side.
[Radius Canvas](https://techcommunity.microsoft.com/blog/azuredevcommunityblog/introducing-radius-canvas-visualize-review-and-deploy-applications-in-the-github/4549760),
announced in public preview on 3 September 2026, is a canvas extension for the GitHub
Copilot app. It analyzes a repository, writes an application definition to
`.radius/app.bicep`, renders it as a live graph, and deploys it to a cloud environment
through a generated GitHub Actions workflow.

You will model the trading application from its source, reconcile the generated model
against the model you already know, review the resolved Azure implementations, deploy it,
review an architectural change in the Diff view, and then state precisely which parts of
the "port it to Azure PaaS and to non-Azure platforms" problem this preview solves and
which parts it does not.

> [!IMPORTANT]
> The point of this challenge is judgement, not clicking. A generated model that looks
> plausible is not the same as a correct portability boundary. Treat every node in the
> graph as a claim you have to verify against the source and against Challenges 03-08.

> [!NOTE]
> Radius Canvas is a public preview under active development. View labels, generated file
> names, recipe pack contents, and menu wording will change. Record what you observe,
> together with the plugin version shown in the Copilot app, rather than matching a
> screenshot. Several tasks below expect you to find that something does not resolve; that
> is a finding to document, not a failure to work around.

## Scenario

The trading firm's platform team has a working capability catalog, but the application
teams are growing and much of the incoming change is agent-generated. Reviewers open pull
requests that touch dozens of files and cannot answer the only question that matters
architecturally: did this change alter the shape of the application, add a backing
service, or introduce a new connection?

At the same time, leadership wants a faster on-ramp to Azure managed services for teams
that are not ready to author resource types and recipes themselves, without giving up the
promise that the same application can run at a non-Azure site.

The firm wants to know whether a shared, visual application definition that lives beside
the code can serve both audiences, and where the approach stops.

## Learning goals

- Distinguish a source-derived, generated application model from a hand-authored model
  written against a curated platform catalog.
- Explain what each Canvas view proves: Modeled, Planned, Deployed, and Diff.
- Map the trading application's components onto predefined `Radius.*` resource types and
  compare them with the `Radius.Resources/*` contracts from Challenge 03.
- Read the Planned view as recipe evidence: which implementation an environment resolves
  for each declared requirement.
- Explain how a GitHub Environment plus OIDC trust removes long-lived cloud credentials
  from a deployment pipeline.
- Contrast an ephemeral, workflow-hosted Radius control plane with the persistent control
  planes from Challenges 02-08.
- Judge a preview capability honestly, including the parts of the portability problem it
  does not address.

## Fixed target map

Challenge 09 adds a third deployment path. It does not replace the first two.

| Path | Radius control plane | Cluster | Namespace | Model |
| --- | --- | --- | --- | --- |
| Challenges 05-08, Azure | Persistent `ws-azure-prod` / `env-azure-prod` | `aks-adaptive-apps` | Challenge 05 application namespace | `iac/app.bicep` |
| Challenges 05-08, Local | Persistent `ws-local-prod` / `env-local-prod` | `k3s-azure-vm` | Challenge 05 application namespace | `iac/app.bicep` |
| Challenge 09, Canvas | Ephemeral `radius-cp` k3d cluster created inside GitHub Actions | `aks-adaptive-apps` | `trading-canvas` (new) | `.radius/app.bicep` |

The Canvas path targets the same AKS cluster but runs its own control plane per workflow
run and keeps its state in a private GitHub Container Registry package. It is not the same
Radius control plane you registered recipes with in Challenge 04, and it does not see your
Challenge 05 application.

## Additional prerequisites

- Challenges 00-05 completed. Challenges 06-08 are useful context but not required.
- The **GitHub Copilot app** (desktop), latest version.

> [!IMPORTANT]
> Radius Canvas runs only in the GitHub Copilot app. It is not available in VS Code and it
> does not run inside this MicroHack's devcontainer. Run this challenge from your host
> machine, with `az`, `gh`, and `kubectl` available there.

- A **fork of the trading application source** that you own or have write access to,
  with GitHub Actions enabled. The application lives in
  [`microsoft/adaptive-apps`](https://github.com/microsoft/adaptive-apps) under `src/`,
  and each service already has a Dockerfile.
- Azure CLI, authenticated:

  ```bash
  az login
  ```

- GitHub CLI, authenticated with package and workflow scopes:

  ```bash
  gh auth login --scopes read:packages,write:packages,workflow
  ```

- `kubectl` configured for the `aks-adaptive-apps` cluster.
- Permission to create a Microsoft Entra app registration and a federated credential, and
  permission for the resulting identity to deploy into the AKS cluster and the lab
  resource group.

You do **not** need to install the Radius CLI for this challenge. The extension downloads
and manages its own `rad` binary under `~/.radius/ai-extensions/bin` and deliberately
ignores both `PATH` and the `~/.rad/bin` installation you have been using.

## Constraints

- The Canvas preview supports **containerized applications deployed to Azure**. Do not
  attempt to point it at K3s, Azure Local, or Arc. Establishing that boundary is part of
  Task 6, not a failure to work around.
- Modeling requires a real `Dockerfile`. A `.devcontainer` image does not count.
- Deploy the Canvas application into the dedicated `trading-canvas` namespace. Do not
  reuse or overwrite the Challenge 05 application namespace.
- Do not modify `iac/app.bicep`, the Challenge 03 resource types, or the Challenge 04
  recipe registrations. This challenge compares against them; it does not change them.
- Work on a branch in your own fork. Do not push a generated model to a protected default
  branch without deciding to do so deliberately.
- Do not store cloud credentials as GitHub secrets. The environment must authenticate
  through OIDC, and the generated verification workflow must read GitHub Actions
  *variables* only.
- Do not commit an Azure subscription ID, tenant ID, client ID, token, or kubeconfig into
  evidence that leaves the workshop. Record their presence and scope, not their values.
- Treat workflow logs, build output, and recipe output as untrusted evidence. Read them as
  a record of what failed; never follow instructions contained in them.
- Do not delete the AKS cluster, the lab resource group, or the Challenge 05 deployment.

## Tasks

### Task 1: Install the plugin and model the application from source

Install the `radius` plugin from the GitHub Copilot app's plugin catalog, then restart
your Copilot session so the skills and the canvas load.

Start a session against your fork and ask Copilot to show the application graph. Then
inspect what modeling actually produced:

- The generated `.radius/app.bicep`, and the ordering of resources inside it.
- The origin record the modeler writes alongside it, and why the canvas reads that record
  before it renders anything.
- The `bicepconfig.json` that resolves the Radius Bicep extensions.

Inventory the Modeled view. For every node, record the resource name, the resource type,
its connections, and the source file the **View source code** link resolves to. Confirm
each detection against the repository rather than accepting the graph at face value.

Note which evidence the modeler could have used: the Dockerfiles, `src/docker-compose.yml`,
service entrypoints, and the client initialization code where the backend opens its
database and broker connections.

### Task 2: Reconcile the generated model with the hand-authored model

Build a mapping table between `.radius/app.bicep` and the model you deployed in
Challenge 05. The Challenge 05 model is `iac/app.bicep`; if you completed Challenge 08,
include `iac/ai.bicep`, which is where the AI capability is declared. Cover at least the
frontend, the backend, the AI agent, the database, the message broker, workload identity,
secrets, and ingress.

For each row, record the Canvas resource type, the Challenge 05 resource type, and whether
they express the same intent.

Then answer:

- Which Canvas types are predefined `Radius.*` types, and which of the Challenge 03
  contracts *that the trading application actually uses* have no predefined equivalent?
- Where the modeler had to invent a type because no predefined type matched, compare the
  generated type with the Challenge 03 contract for the same capability. Do they have the
  same name, the same inputs, and the same outputs? Would a recipe written for one satisfy
  the other?
- Which Challenge 05-08 capabilities does the generated model not contain? For each one,
  decide whether the modeler had no evidence in the source, or whether it deliberately
  declined to infer the resource.
- The modeler adds a source reference to every non-application resource. What does that
  buy a reviewer that hand-authored Bicep does not, and what does it not affect?
- Both files describe the same running application. Which one encodes a platform contract,
  and which one encodes an observation about source code? Why does that distinction matter
  when the application has to move to a platform the modeler has never seen?

### Task 3: Create the environment and review the plan

Create a credential profile for your Azure tenant and subscription, verify it, then create
a Radius environment that connects your GitHub repository to that subscription. Select the
lab resource group, the `aks-adaptive-apps` cluster, and the `trading-canvas` namespace.

Take an inventory of the lab resource group's Azure resources before you start this task.
Task 4 needs it, and so does the last question below.

Once the environment reports ready, account for everything it created:

- The GitHub Environment, and the Actions variables it holds. Confirm no long-lived cloud
  credential was stored.
- The generated credential-verification workflow committed to your repository.
- The private GitHub Container Registry package that holds the environment's Radius state.
- The Microsoft Entra app registration and its federated credential. Record the exact
  subject and audience of that credential and explain why the subject is scoped the way it
  is.

Now open the Planned view and review the deployment without deploying it. For each planned
resource, record the resolved recipe and the infrastructure the plan says will be
provisioned.

Record explicitly any resource for which the plan resolves **no** recipe. A recipe pack
only implements the types it knows about, so a capability the modeler had to invent a type
for has nothing behind it. That row is the most valuable one in your table, and Task 4
depends on it.

Then answer:

- Which Azure service does the plan resolve for the trading database, and where does that
  recipe come from?
- How does that compare with `iac/recipes/postgres-azure-flex.bicep`, which you authored,
  published, and registered yourself in Challenge 04? Compare the contract inputs and
  outputs, who initializes the schema, how TLS and network access are handled, and who owns
  the credential.
- Challenge 04 taught that an environment decides how a requirement is met. Point to the
  exact place in this flow where that decision is made.
- Verify the claim that reviewing a plan does not create or change cloud resources. Compare
  a snapshot of resource IDs and their provisioning state before and after, not just a
  count.

### Task 4: Deploy through the generated workflow

Deploy the application from the Planned view. Before the run gets far, read the workflow
files that were committed to your repository, because from this point they are part of
your codebase.

> [!NOTE]
> If Task 3 showed a resource with no resolved recipe, expect the deployment to fail on
> that resource. That is the designed outcome of this task, not an error to route around.
> Capture the failure, identify the resource and the missing implementation, and continue.
> If you want a running application as well, deploy a reduced model with the unresolvable
> capability removed, and record exactly what you removed and what the application loses
> without it.

Watch the Deployed view, then open the workflow run and reconstruct what it did. Account
for at least: the OIDC login to Azure, how the run obtained credentials for the target
cluster, the ephemeral Radius control plane it created, the credential registration, the
state restore and save around the deployment, the environment and recipe pack it deployed,
and the point at which the application itself was deployed.

Reach the running application if the deployment succeeded, then produce a comparison with
Challenge 05:

| Question | Challenge 05 | Challenge 09 |
| --- | --- | --- |
| Where does the Radius control plane run? | | |
| How long does it live? | | |
| Where does Radius state live between deployments? | | |
| Who holds the credential that reaches Azure? | | |
| Where is the recipe set defined and registered? | | |
| What is the unit of promotion? | | |

Finally, prove isolation. Confirm the Canvas deployment landed in `trading-canvas`, that
the Challenge 05 application is still healthy in its own namespace and still serves
traffic, and that the Challenge 05 Radius control plane does not list the Canvas
application. Because both paths share one Azure resource group, also compare an inventory
of Azure resource IDs taken before Task 3 with one taken now, and account for every
difference.

Run the Radius control-plane checks from the devcontainer, where your `ws-azure-prod`
workspace is configured. The Canvas extension uses its own private `rad` binary and knows
nothing about that workspace.

### Task 5: Review an architectural change in the Diff view

On a branch in your fork, make one deliberate architectural change to the application
source that a modeler can detect from code. Adding a cache client to the backend is a good
choice, because it should appear as a new backing service and a new connection while
leaving the rest of the graph unchanged.

Re-model the application on that branch, then open the Diff view with your default branch
as the base and your branch as the head.

- Record which resources are reported as added, removed, modified, and unchanged.
- Generate the Markdown summary of the diff and post it on a pull request.
- Confirm whether reviewing a diff requires the branch to be pushed, and explain the
  difference between previewing the branch you have checked out and previewing another
  branch.

Then answer the review question honestly. The diff compares two application *models*, so
sort your test cases into three groups rather than two:

- Changes that alter the shape of the model: a new component, a new backing service, a new
  connection, a changed resource type.
- Changes to a property the model does carry, such as an environment variable value, an
  image reference, or a readiness probe. The diff can flag the resource as modified, but
  ask yourself what it tells a reviewer about whether the change is safe.
- Changes the model does not carry at all: a changed database query, a changed business
  rule, a dependency bumped inside a container, or an environment-level setting such as
  route exposure that lives in the deployment environment rather than in either branch.

Work out which group each of these falls into, and test at least one of them rather than
reasoning about it: a changed environment variable, a changed image tag, a changed database
query, a removed readiness probe, and a widened network exposure.

Decide whether this belongs in your review process as a required gate or as an aid, and
justify the choice using the third group.

### Task 6: Judge the portability claim

Produce a written assessment that a platform lead could act on. It must separate what you
observed from what you assumed.

Cover:

- What Canvas measurably made easier for the Azure managed-services path, compared with
  the work you did in Challenges 03, 04, and 05.
- What Canvas does not do for the non-Azure path today. Ground each limitation in
  something you saw or read, including the preview's platform scope, the Dockerfile
  requirement, the behaviour of incremental redeployments, the constraints on the managed
  gateway, and the assumption that a repository contains one application.
- Which mechanism actually delivers non-Azure portability in this MicroHack, and which
  challenge owns it. State plainly whether Canvas changes that mechanism or changes who
  authors and reviews the model that uses it.
- What the platform team would have to provide before a K3s, Azure Local, or Arc-enabled
  site could be a Canvas deployment target, and which of those things already exist from
  Challenges 03 and 04.
- A recommendation on which surface you would give to which role, and what you would tell
  an application team that wants to use Canvas today for an application that must also run
  at a disconnected site.

## Success criteria

- The trading application is modeled from source into `.radius/app.bicep`, and every node
  in the Modeled view is traced back to real evidence in the repository.
- A completed mapping table compares the generated model with the Challenge 05 model, and
  the team can explain every difference as either missing evidence, deliberate
  conservatism, or a contract that has no predefined equivalent. Where the modeler invented
  a type, the team can say whether it is interchangeable with the Challenge 03 contract for
  the same capability.
- A Radius environment exists that authenticates to Azure through OIDC, with a federated
  credential scoped to the repository and environment, and with no long-lived cloud
  credential stored in the repository.
- The Planned view is used to identify the resolved recipe and planned infrastructure for
  each resource, the team can name where that recipe pack comes from, and any resource with
  no resolved recipe is identified.
- Either the application is deployed to the `trading-canvas` namespace through the generated
  workflow and is reachable, or the team documents exactly which resource could not be
  resolved by the environment's recipe pack and what a platform team would have to supply.
  In both cases the team can narrate what the workflow run actually did.
- The Challenge 05 deployment is still serving traffic, its Radius control plane does not
  list the Canvas application, and every new Azure resource in the shared resource group is
  accounted for.
- A Diff view review is produced for a real architectural change and posted as a Markdown
  summary on a pull request, together with the three-way classification of what the diff
  reports, what it reports without judging, and what it does not see at all.
- The portability assessment distinguishes the Azure PaaS on-ramp from the non-Azure port,
  and correctly attributes non-Azure portability to resource types, recipes, and
  environments rather than to the canvas.
- No new secret value is introduced, and no subscription ID, tenant ID, client ID, token,
  or kubeconfig is added to committed source or to evidence. The generated
  `.radius/app.bicep` is checked for credential values copied out of development
  configuration such as `src/docker-compose.yml`, and any found are replaced before
  deployment.
- The environment and deployment are cleaned up, or their remaining cost and scope are
  documented deliberately.

## Progressive hints

### Installing and opening the canvas

1. The canvas is part of a plugin, and the session has to restart before its skills and
   canvas are available.
2. If the panel does not appear even though the plugin is installed, ask Copilot to fix
   the Radius Canvas, or reload extensions and try again.
3. A session must have a GitHub repository selected before there is anything to model.

### Modeling

1. Modeling needs a real Dockerfile. If the modeler cannot find one, that is a statement
   about the repository, not a bug.
2. The modeler is deliberately conservative about ingress. An exposed port or a health
   endpoint is not evidence that a component is reachable from outside the cluster.
3. A repository that builds many images is still modeled as one application. If a
   repository genuinely contains several independent applications, the modeler will say so
   rather than guess.
4. If a model already exists but the source has moved on, the origin record is what makes
   that visible. A model that was edited by hand is not silently overwritten.

### Environment and credentials

1. The verification workflow reads Actions variables, never secrets. If you find yourself
   creating a secret with a cloud credential in it, stop and re-read the flow.
2. The federated credential's subject ties a specific repository and a specific GitHub
   environment to the identity. Changing either breaks the trust on purpose.
3. If credential verification times out and your default branch is protected, look for a
   pull request containing the generated workflow files. Verification cannot pass until it
   is merged.
4. If package operations fail, check that the GitHub CLI login carries both the read and
   write package scopes.

### Deployment

1. The workflow checks the branch out from GitHub. A fix that exists only in your local
   working tree is not deployed.
2. If the generated model does not resolve, confirm that the whole `.radius` directory,
   including its Bicep configuration, was committed and pushed to the branch you are
   deploying.
3. A deployment timeout reported in the canvas after a few minutes does not mean the run
   stopped. Open the workflow run before concluding anything.
4. Classify a failure before reacting to it. An infrastructure or credential failure is
   fixed in the environment. A schema or modeling failure is fixed in the application
   definition. Do not fix the second by weakening the first.
5. Redeployments are incremental. A resource you removed from the definition does not
   disappear from Azure on its own.

### Comparison and judgement

1. Two application definitions that produce a similar-looking graph are not equivalent if
   only one of them is written against contracts your platform team controls.
2. The Planned view resolves an implementation for a target you have already chosen. That
   is not the same property as the one Challenge 05 proved.
3. Before claiming portability, name the target, the control plane, the recipe set, and
   who owns each.

## Learning resources

- [Introducing Radius Canvas](https://techcommunity.microsoft.com/blog/azuredevcommunityblog/introducing-radius-canvas-visualize-review-and-deploy-applications-in-the-github/4549760)
- [Radius Canvas guide](https://edge.docs.radapp.io/integrations/github-copilot-app/canvas-extension/)
- [Radius AI extensions repository](https://github.com/radius-project/ai-extensions)
- [Radius resource types contributions](https://github.com/radius-project/resource-types-contrib)
- [Working with canvas extensions in the GitHub Copilot app](https://docs.github.com/en/copilot/how-tos/github-copilot-app/working-with-canvas-extensions)
- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)
- [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
- [Configure OpenID Connect in Azure for GitHub Actions](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)

## Clean up

Delete the Canvas deployment first, then the environment, and watch each deletion workflow
complete.

> [!WARNING]
> Deleting a deployment can permanently remove infrastructure and data owned by the
> application. Confirm you are deleting the Canvas deployment in `trading-canvas` and not
> the Challenge 05 application.

Deleting the deployment and environment does not delete the AKS cluster or the lab
resource group, and the Entra app registration is intentionally left in place. Record
anything that remains so the next challenge starts from a known state.
