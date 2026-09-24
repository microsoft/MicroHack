locals {
  # Comprehensive list of resource providers for application innovation, AI, containers, databases, and infrastructure
  # This registers providers proactively, even if not immediately used by Terraform
  # Useful for workshop/learning environments where users may deploy resources via portal, CLI, or other tools
  resource_providers = [
    # AI and Cognitive Services
    "Microsoft.CognitiveServices",       # Azure AI Services, OpenAI
    "Microsoft.MachineLearningServices", # Azure Machine Learning
    "Microsoft.BotService",              # Azure Bot Service

    # Compute and Containers
    "Microsoft.Compute",           # Virtual Machines, VM Scale Sets
    "Microsoft.ContainerInstance", # Azure Container Instances
    "Microsoft.ContainerRegistry", # Azure Container Registry (ACR)
    "Microsoft.ContainerService",  # Azure Kubernetes Service (AKS)
    "Microsoft.App",               # Azure Container Apps (ACA) and Azure SRE Agent

    # Web and App Services
    "Microsoft.Web",                     # App Service, Function Apps, Static Web Apps
    "Microsoft.ApiManagement",           # Azure API Management
    "Microsoft.CertificateRegistration", # App Service Certificates
    "Microsoft.DomainRegistration",      # App Service Domains

    # Storage
    "Microsoft.Storage", # Azure Storage (Blob, Files, Queue, Table)
    "Microsoft.NetApp",  # Azure NetApp Files

    # Databases
    "Microsoft.Sql",             # Azure SQL Database, SQL Managed Instance
    "Microsoft.DBforPostgreSQL", # Azure Database for PostgreSQL Flexible Server
    "Microsoft.DBforMySQL",      # Azure Database for MySQL
    "Microsoft.DBforMariaDB",    # Azure Database for MariaDB
    "Microsoft.DocumentDB",      # Azure Cosmos DB (SQL, MongoDB, Cassandra, Gremlin, Table)

    # Search and Analytics
    "Microsoft.Search", # Azure AI Search (formerly Cognitive Search)

    # Monitoring and Insights
    "microsoft.insights",             # Application Insights and Azure Monitor; key casing preserves existing state
    "Microsoft.OperationalInsights",  # Log Analytics
    "Microsoft.OperationsManagement", # Azure Monitor Solutions
    "Microsoft.AlertsManagement",     # Azure Monitor Alerts
    "Microsoft.Dashboard",            # Azure Dashboards / Grafana

    # Networking
    "Microsoft.Network", # VNet, Load Balancer, Application Gateway, etc.
    "Microsoft.Cdn",     # Azure CDN and Front Door

    # Security and Identity
    "Microsoft.KeyVault",        # Azure Key Vault
    "Microsoft.ManagedIdentity", # Managed Identities
    "Microsoft.Authorization",   # RBAC
    "Microsoft.Security",        # Microsoft Defender for Cloud
    "Microsoft.AAD",             # Azure Active Directory Domain Services

    # Messaging and Events
    "Microsoft.ServiceBus",       # Azure Service Bus
    "Microsoft.EventHub",         # Azure Event Hubs
    "Microsoft.EventGrid",        # Azure Event Grid
    "Microsoft.Relay",            # Azure Relay
    "Microsoft.NotificationHubs", # Azure Notification Hubs

    # Integration
    "Microsoft.Logic",       # Azure Logic Apps
    "Microsoft.DataFactory", # Azure Data Factory

    # Developer Tools
    "Microsoft.AppConfiguration", # Azure App Configuration
    "Microsoft.Cache",            # Azure Cache for Redis
    "Microsoft.SignalRService",   # Azure SignalR Service
    # Microsoft.ChangeAnalysis was retired by Azure and is no longer an accepted
    # registration namespace; its capability now lives in Azure Monitor.

    # DevOps
    "Microsoft.DevOpsInfrastructure", # Managed DevOps Pools
    "Microsoft.DevCenter",            # Microsoft Dev Box / Dev Center
    "Microsoft.DevTestLab",           # Azure DevTest Labs
    "Microsoft.LabServices",          # Azure Lab Services

    # Data and Analytics
    "Microsoft.Databricks",        # Azure Databricks
    "Microsoft.Synapse",           # Azure Synapse Analytics
    "Microsoft.StreamAnalytics",   # Azure Stream Analytics
    "Microsoft.DataShare",         # Azure Data Share
    "Microsoft.DataLakeStore",     # Azure Data Lake Store Gen1
    "Microsoft.DataLakeAnalytics", # Azure Data Lake Analytics
    "Microsoft.HDInsight",         # Azure HDInsight
    "Microsoft.PowerBIDedicated",  # Power BI Embedded
    "Microsoft.AnalysisServices",  # Azure Analysis Services

    # Migration and Hybrid
    "Microsoft.Migrate",            # Azure Migrate
    "Microsoft.OffAzure",           # Azure Migrate dependencies
    "Microsoft.HybridCompute",      # Azure Arc for Servers
    "Microsoft.HybridConnectivity", # Azure Arc connectivity
    "Microsoft.AzureArcData",       # Azure Arc-enabled data services

    # Management and Governance
    "Microsoft.Resources",      # Resource Groups, Deployments
    "Microsoft.Features",       # Azure Feature Flags
    "Microsoft.Portal",         # Azure Portal
    "Microsoft.Advisor",        # Azure Advisor
    "Microsoft.PolicyInsights", # Azure Policy Insights
    "Microsoft.CostManagement", # Azure Cost Management
    "Microsoft.Consumption",    # Azure Consumption API
    "Microsoft.Billing",        # Azure Billing
    "Microsoft.Maintenance",    # Azure Maintenance
    "Microsoft.ResourceHealth", # Azure Resource Health
    "Microsoft.ResourceGraph",  # Azure Resource Graph

    # Automation
    "Microsoft.Automation", # Azure Automation

    # Recovery and Backup
    "Microsoft.RecoveryServices", # Azure Backup, Site Recovery
    "Microsoft.DataProtection",   # Azure Backup (new)

    # Virtual Desktop
    "Microsoft.DesktopVirtualization", # Azure Virtual Desktop

    # Media
    "Microsoft.VideoIndexer", # Azure Video Indexer

    # Communication
    "Microsoft.Communication", # Azure Communication Services

    # Maps
    "Microsoft.Maps", # Azure Maps

    # Confidential Computing
    "Microsoft.ConfidentialLedger", # Azure Confidential Ledger

    # Chaos Engineering
    "Microsoft.Chaos", # Azure Chaos Studio

    # Service Connector
    "Microsoft.ServiceLinker", # Azure Service Connector

    # Load Testing
    "Microsoft.LoadTestService", # Azure Load Testing
  ]
}

locals {
  # Preview features that must stay registered for the workshop topology to deploy. Each
  # participant VM carries its own public IP address, and Azure refuses every public IP
  # allocation in this subscription unless this feature is registered.
  provider_features = {
    "Microsoft.Network" = {
      "AllowBringYourOwnPublicIpAddress" = true
    }
  }
}
