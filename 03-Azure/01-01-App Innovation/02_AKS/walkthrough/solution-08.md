# Exercise 8: Monitoring with Azure Managed Grafana

## Objective
In this exercise, you will learn how to monitor your AKS cluster and applications using the pre-configured Azure Managed Grafana dashboards. You'll explore built-in dashboards, understand key metrics, and interact with visualizations to monitor your workloads.

## What is Azure Managed Grafana?

Azure Managed Grafana is a fully managed service that provides:
- Pre-built dashboards for Azure services
- Integration with Azure Monitor and Prometheus
- Real-time metrics and visualization
- Interactive data exploration
- High availability and automatic scaling

**Key Benefits**:
- No infrastructure management
- Native integration with Azure services
- Secure authentication with Azure AD
- Built-in high availability
- Pre-configured dashboards ready to use

## Prerequisites
- Completed Exercise 4 (Applications deployed and exposed)
- Running AKS cluster with applications
- Access to Azure Portal
- Azure Managed Grafana already configured (provided in your environment)

## Tasks

### Task 1: Verify Azure Monitor for Containers

First, verify that monitoring is enabled on your AKS cluster.

1. **Navigate to your AKS cluster in Azure Portal**
   - Sign in to [Azure Portal](https://portal.azure.com)
   - Go to **Kubernetes services**
   - Select your AKS cluster: `aks-lab-<yourinitials>`

2. **Configure Dashboards with Grafana**
   - In the left navigation menu, click **Monitoring** > **Dashboards with Grafana**
   - Click on Configure
     - Select **Enable Prometheus metrics** and **Container logs**
     - Click on **Configure**
   - After around 5 minutes refresh the pages.
   
3. **Review the differnt Dashboards with Grafana**
   - Take some time to review the differents **Buil-in dashboard** of Grafana.

## Congratulations!

You've completed all AKS exercises! You now have comprehensive knowledge of:
- ✅ AKS cluster setup and management
- ✅ Container registry and image management
- ✅ Application deployment and exposure
- ✅ Scaling (HPA and Cluster Autoscaler)
- ✅ Persistent storage (Azure Disks and Files)
- ✅ Backup and disaster recovery
- ✅ Monitoring and observability with Grafana

### What You Can Do Next
- Explore more advanced Grafana features (alerts, custom queries)
- Investigate Azure Monitor Workbooks for additional insights
- Learn about Application Insights for application-level monitoring
- Study Azure Policy for governance and compliance

## Cleanup

To avoid ongoing charges, remember to delete your resources:
```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

This will remove:
- AKS cluster
- Log Analytics workspace
- Container Registry
- Backup vault
- Storage accounts
- All other lab resources