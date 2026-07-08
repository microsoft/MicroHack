# Modernize a Java Application

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Finish](../../challenges/finish.md)

**Duration:** 30 minutes

## Goal

Modernize the Asset Manager Java Spring Boot application for Azure deployment, migrating from AWS dependencies to Azure services using GitHub Copilot App Modernization in VS Code.

## Actions

### Environment Setup:
1. Navigate to [../../src/AssetManager](../../src/AssetManager)
1. Open Visual Studio Code
1. Login to GitHub from VS Code
1. Install GitHub Copilot App Modernization extension if not present

### Validate Application Locally:

1. Open Terminal in VS Code (View → Terminal)
1. Run `scripts\startapp.cmd`
1. Wait for Docker containers (RabbitMQ, Postgres) to start
1. Allow network permissions when prompted
1. Verify application is accessible at http://localhost:8080
1. Stop the application by closing console windows

### Perform AppCAT Assessment:

1. Open GitHub Copilot App Modernization extension in the Activity bar
1. Ensure Claude Sonnet 4.5 is selected as the model
1. Click "Migrate to Azure" to begin assessment
1. Wait for AppCAT CLI installation to complete
1. Review assessment progress in the VS Code terminal
1. Wait for assessment results (9 cloud readiness issues, 4 Java upgrade opportunities)

### Analyze Assessment Results:

1. Review the assessment summary in GitHub Copilot chat
1. Examine issue prioritization:
    - Mandatory (Purple) - Critical blocking issues
    - Potential (Blue) - Performance optimizations
    - Optional (Gray) - Future improvements
1. Click on individual issues to see detailed recommendations
1. Focus on the AWS S3 to Azure Blob Storage migration finding

### Execute Guided Migration:

1. Expand the "Migrate from AWS S3 to Azure Blob Storage" task
1. Read the explanation of why this migration is important
1. Click the "Run Task" button to start the migration
1. Review the generated migration plan in the chat window and `plan.md` file
1. Type "Continue" in the chat to begin code refactoring

### Monitor Migration Progress:

1. Watch the GitHub Copilot chat for real-time status updates
1. Check the `progress.md` file for detailed change logs
1. Review file modifications as they occur:
    - `pom.xml` and `build.gradle` updates for Azure SDK dependencies
    - `application.properties` configuration changes
    - Spring Cloud Azure version properties
1. Allow any prompted operations during the migration

### Validate Migration:

1. Wait for automated validation to complete:
    - CVE scanning for security vulnerabilities
    - Build validation
    - Consistency checks
    - Test execution
1. Review validation results in the chat window
1. Allow automated fixes if validation issues are detected
1. Confirm all validation stages pass successfully

### Test Modernized Application:

1. Open Terminal in VS Code
1. Run `scripts\startapp.cmd` again
1. Verify the application starts with Azure Blob Storage integration
1. Test application functionality at http://localhost:8080
1. Confirm no errors related to storage operations

### Optional: Continue Modernization:

1. Review other migration tasks in the assessment report
1. Execute additional migrations as time permits
1. Track progress through the `plan.md` and `progress.md` files


## Learning Resources

- [GitHub Copilot for VS Code](https://code.visualstudio.com/docs/copilot/overview)
- [Azure SDK for Java](https://learn.microsoft.com/azure/developer/java/sdk/)
- [Migrate from AWS to Azure](https://learn.microsoft.com/azure/architecture/aws-professional/)
- [Azure Blob Storage for Java](https://learn.microsoft.com/azure/storage/blobs/storage-quickstart-blobs-java)
- [Spring Cloud Azure](https://learn.microsoft.com/azure/developer/java/spring-framework/)
- [AppCAT Assessment Tool](https://learn.microsoft.com/azure/developer/java/migration/migration-toolkit-intro)
