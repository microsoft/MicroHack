# 2. Batch Upgrade a Java App and a .NET App

[Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-03.md)

## Goal

Use the GitHub Copilot App Modernization agent (modernize CLI) to assess and upgrade two applications at once — a Spring Boot (Java) app and an ASP.NET (.NET) app — bringing each to its latest framework version before any cloud migration work begins.

## Actions

* Complete the [environment setup guide](../docs/environment-setup.md), including GitHub and Azure authentication and the tool verification steps.
* Make sure the two sample repositories are cloned into the `repos/` working directory (done during environment setup — no forking needed) and that each is on its local `modernize` branch:
  * PhotoAlbum-Java (Spring Boot): `https://github.com/Azure-Samples/PhotoAlbum-Java`
  * PhotoAlbum (.NET): `https://github.com/Azure-Samples/PhotoAlbum`
* Use the preinstalled GitHub Copilot App Modernization agent (modernize CLI) in the recommended Codespace, or install it as described in the environment setup for a local workstation. You will use it end-to-end for assessment, upgrade, planning, and execution.
* Create the repositories config file at `.github/modernize/repos.json` in the hack working directory, using local `path` entries that point at the two clones in `repos/` — the CLI then operates on your local working copies in a single batch run instead of cloning fresh ones.
* Run a **batch assessment** across both repositories, selecting the *Upgrade* and *Cloud readiness* analyses with full analysis coverage, and verify the upgrade targets on the configuration page (**.NET 10** and **OpenJDK 25**). Let the assessment run locally and wait for it to complete.
* Explore the assessment output in `.github/modernize/assessment/`: the **aggregated report** (overall recommendations, target platforms, upgrade paths, and migration waves) and the **per-repository reports** (detailed findings per app).
* Because a batch upgrade requires both repositories to share the same language, **upgrade each app individually**:
  * Upgrade the .NET app to the version recommended in the assessment (.NET 10).
  * Upgrade the Java app to the versions recommended in the assessment (Java 25 and Spring Boot 4.0).
* Confirm each upgrade reports success, then commit the changes on each repository's `modernize` branch. (Optional) Publish a repository to your own GitHub account with `gh repo create` if you want a remote copy — the upstream `Azure-Samples` repositories are read-only.

> [!TIP]
> With full analysis coverage, the batch assessment takes roughly 10-20 minutes for the two repositories, and each upgrade can take 15-45 minutes. Review the generated reports while you wait — they explain *why* each recommendation was made.

## Success criteria

* Both PhotoAlbum-Java and PhotoAlbum are cloned into `repos/` and checked out on their local `modernize` branch.
* GitHub CLI is authenticated with the GitHub account that has Copilot access.
* The modernize CLI is installed and configured to target both repositories from a config file.
* A batch assessment completes and produces both an aggregated report and per-repository reports.
* The .NET app is upgraded to .NET 10 and the Java app is upgraded to Java 25 / Spring Boot 4.0, each reporting a successful upgrade.
* All upgrade changes are committed on the `modernize` branch of each repository.

> Need the detailed, step-by-step walkthrough? See the [Challenge 2 Solution](../walkthrough/challenge-02/solution-02.md).

## Learning resources

* [GitHub Copilot App Modernization – modernization agent quickstart](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
* [Batch assess multiple repositories](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/batch-assess)
* [Upgrade .NET applications](https://learn.microsoft.com/dotnet/core/porting/)
* [Spring Boot upgrade guidance](https://learn.microsoft.com/azure/developer/java/spring-framework/)
* [GitHub Copilot for VS Code](https://code.visualstudio.com/docs/copilot/overview)
