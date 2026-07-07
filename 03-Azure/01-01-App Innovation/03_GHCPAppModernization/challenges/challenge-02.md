# Batch Upgrade a Java App and a .NET App

[Previous Challenge Solution](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-03.md)

## Goal

Use the GitHub Copilot App Modernization agent (modernize CLI) to assess and upgrade two applications at once — a Spring Boot (Java) app and an ASP.NET (.NET) app — bringing each to its latest framework version before any cloud migration work begins.

## Actions

* Fork the two sample repositories into your own GitHub account:
  * PhotoAlbum-Java (Spring Boot): `https://github.com/Azure-Samples/PhotoAlbum-Java`
  * PhotoAlbum (.NET): `https://github.com/Azure-Samples/PhotoAlbum`
* Prepare a working directory and install the GitHub Copilot App Modernization agent (modernize CLI), which you will use end-to-end for assessment, upgrade, planning, and execution.
* Create a repositories config file so the CLI can operate on both apps in a single batch run.
* Run a **batch assessment** across both repositories, selecting the *Upgrade* and *Cloud readiness* analyses with full analysis coverage. Let the assessment run locally and wait for it to complete.
* Explore the assessment output: the **aggregated report** (overall recommendations, target platforms, upgrade paths, and migration waves) and the **per-repository reports** (detailed findings per app).
* Because a batch upgrade requires both repositories to share the same language, **upgrade each app individually**:
  * Upgrade the .NET app to the version recommended in the assessment (.NET 10).
  * Upgrade the Java app to the versions recommended in the assessment (Java 25 and Spring Boot 4.0).
* Confirm each upgrade reports success, then commit and push the changes to each respective forked repository.

> [!TIP]
> The assessment and each upgrade can take several minutes to run. Review the generated reports while you wait — they explain *why* each recommendation was made.

## Success criteria

* Both PhotoAlbum-Java and PhotoAlbum are forked and available in your working directory.
* The modernize CLI is installed and configured to target both repositories from a config file.
* A batch assessment completes and produces both an aggregated report and per-repository reports.
* The .NET app is upgraded to .NET 10 and the Java app is upgraded to Java 25 / Spring Boot 4.0, each reporting a successful upgrade.
* All upgrade changes are committed and pushed to the respective remote repositories.

> Need the detailed, step-by-step walkthrough? See the [Challenge 2 Solution](../walkthrough/challenge-02/solution-02.md).

## Learning resources

* [GitHub Copilot App Modernization – modernization agent quickstart](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
* [Batch assess multiple repositories](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/batch-assess)
* [Upgrade .NET applications](https://learn.microsoft.com/dotnet/core/porting/)
* [Spring Boot upgrade guidance](https://learn.microsoft.com/azure/developer/java/spring-framework/)
* [GitHub Copilot for VS Code](https://code.visualstudio.com/docs/copilot/overview)
