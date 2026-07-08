# Modernize the Asset Manager Java Application

[Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Finish](finish.md)

## Goal

Modernize the Asset Manager Spring Boot application for Azure by replacing AWS S3 dependencies with Azure services through the GitHub Copilot App Modernization workflow.

## Actions

* Prepare the workstation by launching Docker Desktop, cloning the `migrate-modernize-lab` repo, and opening `src/AssetManager` in VS Code.
* Authenticate to GitHub, ensure the GitHub Copilot App Modernization extension (Claude Sonnet 4.5) is installed, and review prerequisite setup.
* Run `scripts\startapp.cmd` to validate the existing containers (RabbitMQ, Postgres) and confirm the app is reachable at `http://localhost:8080`.
* Launch the AppCAT assessment from the extension, track CLI installation, and wait for the identified cloud readiness issues and Java upgrade opportunities.
* Review the assessment insights, focusing on the AWS S3 to Azure Blob Storage migration recommendation and understanding the priority levels.
* Execute the guided migration task, inspect the generated `plan.md`, and continue the conversation to apply the proposed code refactoring.
* Monitor `progress.md`, Maven/Gradle changes, configuration updates, and Spring Cloud Azure versions as the migration proceeds.
* Allow the automated validation stages (CVE scans, builds, consistency checks, tests) to complete and remediate any issues flagged.
* Re-run `scripts\startapp.cmd`, verify Blob Storage integration locally, and test application functionality end-to-end.
* Optionally proceed with additional modernization tasks surfaced in the assessment to continue improving the workload.

## Success criteria

* Docker containers start successfully and the legacy app runs locally before changes.
* AppCAT completes with nine cloud readiness issues and four Java upgrade opportunities identified.
* The AWS S3 to Azure Blob Storage migration task executes with updated dependencies and configuration.
* All automated validation stages pass without unresolved issues.
* The modernized application starts locally using Azure Blob Storage with no storage errors.
* Migration activities are traceable through dedicated plan and progress artifacts for rollback readiness.

## Learning resources

* [GitHub Copilot for VS Code](https://code.visualstudio.com/docs/copilot/overview)
* [Azure SDK for Java](https://learn.microsoft.com/azure/developer/java/sdk/)
* [Migrate from AWS to Azure](https://learn.microsoft.com/azure/architecture/aws-professional/)
* [Azure Blob Storage for Java](https://learn.microsoft.com/azure/storage/blobs/storage-quickstart-blobs-java)
* [Spring Cloud Azure](https://learn.microsoft.com/azure/developer/java/spring-framework/)
* [AppCAT Assessment Tool](https://learn.microsoft.com/azure/developer/java/migration/migration-toolkit-intro)
