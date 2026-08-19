# **Adaptive Apps MicroHack**

- [MicroHack introduction](#microhack-introduction)
- [MicroHack context](#microhack-context)
- [Objectives](#objectives)
- [MicroHack challenges](#microhack-challenges)
- [Contributors](#contributors)

## MicroHack introduction

Modern organizations increasingly need to run the same application in very
different places: a public cloud region, an on-premises datacenter, an edge
location, or a fully disconnected site. They need to do this without rebuilding
the application for every environment.

This MicroHack uses [Radius](https://radapp.io), an open-source, cloud-native
application platform, to make a single application adaptive. The application
declares the capabilities it needs, such as a database, message broker,
workload identity, or AI model, while each environment decides how those
capabilities are provided.

Across the challenges, you take the role of a platform engineering team. You
prepare target platforms, install Radius, define reusable platform abstractions
with resource types and recipes, and prove portability by deploying a sample
stock-trading application across multiple environments without changing its
application model. Advanced challenges apply the same approach to AI services,
custom resources, and brownfield modernization.

This MicroHack is not a complete explanation of Radius. The following articles
provide useful background:

- [What is Radius?](https://docs.radapp.io/concepts/overview/)
- [Radius application model](https://docs.radapp.io/guides/author-apps/application/overview/)
- [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
- [Radius recipes](https://docs.radapp.io/guides/recipes/overview/)

## MicroHack context

The scenario follows a trading firm whose stock-trading application must run
across cloud, on-premises, and edge environments. Some sites may need to keep
operating when disconnected from the cloud, while connected sites should use
managed Azure services where appropriate.

Instead of maintaining a different deployment definition for every site, the
platform team wants one application definition with environment-specific
implementations of the same capability contracts. Radius resource types define
those contracts, recipes provide their implementations, and Radius
environments determine which implementation is used at each location.

## Objectives

After completing this MicroHack, you will:

- Know how to prepare Kubernetes target platforms and install Radius.
- Understand how Radius resource types and recipes define reusable platform
  capabilities.
- Deploy one application model across multiple environments with minimal
  environment-only configuration changes.
- Adapt identity, secure service communication, and AI services without
  changing the application model.
- Apply the Adaptive Apps approach to an existing containerized application.

## MicroHack challenges

> [!NOTE]
> This initial scaffold establishes the challenge sequence and navigation.
> Detailed challenge and coach walkthrough content will be added incrementally.

### General prerequisites

To use the MicroHack time effectively, have the following available:

- An Azure subscription with **Owner** access to the lab resource group
- Capacity to create the default two-environment topology: one Azure Kubernetes
  Service cluster and one Linux VM hosting self-managed K3s
- Alternatively, an existing Azure Local or Arc-enabled Kubernetes environment to
  use in place of K3s
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Radius CLI (`rad`)](https://docs.radapp.io/getting-started/install/)
- [Visual Studio Code](https://code.visualstudio.com/)
- Bash or PowerShell 7; Windows users can also use WSL 2

The recommended option is the scoped
[devcontainer](.devcontainer/devcontainer.json), which installs the Challenges 00-04
toolchain while retaining the manual host setup path. Clone the contribution, open the
`04-adaptive-apps` folder itself in VS Code, and run **Dev Containers: Reopen in
Container**. See [Challenge 00](challenges/challenge-00.md) for host prerequisites,
credential persistence, verification, and troubleshooting.

### Challenge 00: universal prerequisite

Complete Challenge 00 before starting a challenge in any bucket.

- [Challenge 00 - Prerequisites: ready, set, go](challenges/challenge-00.md)
  **<- Start here**

### Bucket 1: Infrastructure setup

Prepare the target platforms and deploy the Radius control plane.

- [Challenge 01 - Prepare the platforms](challenges/challenge-01.md)
- [Challenge 02 - Deploy and explore Radius](challenges/challenge-02.md)

### Bucket 2: Exploring Radius

Define portable platform capabilities and implement them with recipes.

- [Challenge 03 - Build the platform abstractions](challenges/challenge-03.md)
- [Challenge 04 - Build the platform abstractions with recipes](challenges/challenge-04.md)

### Bucket 3: Portable apps across platforms

Deploy the application across environments and adapt its identity,
communication, and AI capabilities.

- [Challenge 05 - Port the app across environments](challenges/challenge-05.md)
- [Challenge 06 - Adapt identity services](challenges/challenge-06.md)
- [Challenge 07 - Secure service communication](challenges/challenge-07.md)
- [Challenge 08 - Adapt AI services](challenges/challenge-08.md)

### Bucket 4: Advanced challenges

Extend the application model and apply the Adaptive Apps approach to an
existing application.

- [Challenge 09 - Extend the application model with custom Radius resources](challenges/challenge-09.md)
- [Challenge 10 - Modernize a brownfield application](challenges/challenge-10.md)

## Contributors

- The Adaptive Apps team at Microsoft
- Dylan de Jong
- Jan Egil Ring
- Wesley Backelant

Contributions to the upstream project are welcome in the
[microsoft/adaptive-apps repository](https://github.com/microsoft/adaptive-apps).
