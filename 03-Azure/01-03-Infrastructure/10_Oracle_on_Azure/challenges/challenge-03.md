# Challenge 3 - Use GoldenGate to Replicate Data Between Oracle Databases

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-04.md)

## Goal 

The goal of this exercise is to deploy Oracle GoldenGate to enable real-time data replication between an Oracle database running in Azure Kubernetes Service (AKS) and the Oracle Autonomous Database (ADB) instance, ensuring high availability and seamless data migration.

## Actions

* Add the GoldenGate Helm repository and prepare your AKS cluster for the deployment.
* Configure the GoldenGate deployment file with the correct external IP address from your NGINX ingress controller.
* Retrieve and configure the Oracle ADB connection string in the GoldenGate configuration file.
* Create the necessary Kubernetes secrets for GoldenGate admin, source database, and target database authentication.
* Deploy GoldenGate using Helm and monitor the deployment until all pods are running successfully.
* Validate data replication by verifying that data from the source database schema is replicated to the target schema in the ADB instance.

## Success criteria

* You have successfully added the GoldenGate Helm repository to your AKS cluster.
* You have configured the GoldenGate deployment file [gghack.yaml](../gghack.yaml) with the correct NGINX ingress controller IP address.
* You have successfully retrieved and configured the Oracle ADB connection string in the GoldenGate configuration.
* You have created all required Kubernetes secrets (ogg-admin-secret and db-admin-secret) in the microhacks namespace.
* You have successfully deployed GoldenGate using Helm, and all pods are in Running or Completed status.
* You have verified that the GoldenGate web interface is accessible via the configured ingress URL.
* You have successfully validated data replication by querying both the source and target database schemas and confirming data consistency.
* You have verified that the GGADMIN user exists and is enabled in both source and target databases.

## Learning resources
* [Oracle GoldenGate Documentation](https://docs.oracle.com/en/middleware/goldengate/core/21.3/index.html)
* [Oracle GoldenGate for Oracle Database](https://www.oracle.com/integration/goldengate/)
* [Azure Kubernetes Service (AKS) documentation](https://learn.microsoft.com/en-us/azure/aks/)
* [Helm Charts documentation](https://helm.sh/docs/)
* [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
