# Challenge 5 - Review data replication via Beaver

[Previous Challenge Solution](challenge-04.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-06.md)

## Goal 

The goal of this exercise is to deploy CloudBeaver, a web-based database management tool, to your AKS cluster and use it to connect to both your local Oracle database running in AKS and your Oracle Database@Azure (ODAA) Autonomous Database instance. This will allow you to review and verify the data replication that was configured in the previous challenges.

## Actions

* Deploy CloudBeaver to your AKS cluster using Helm
* Configure an Ingress resource to expose CloudBeaver externally
* Set up CloudBeaver with an initial admin password
* Create a database connection in CloudBeaver to the Oracle database running in your AKS cluster
* Create a database connection in CloudBeaver to the ODAA Autonomous Database instance
* Verify that you can access and query both databases through the CloudBeaver web interface
* Review and compare data between the source and target databases to confirm replication is working

## Success criteria

* You have successfully deployed CloudBeaver to your AKS cluster
* You have configured an Ingress resource and can access CloudBeaver via a web browser
* You have set up CloudBeaver with an admin password and can log in
* You have successfully created a connection to the local Oracle database in AKS
* You have successfully created a connection to the ODAA ADB instance
* You can browse tables and execute SQL queries on both databases through CloudBeaver
* You have verified that data is being replicated correctly between the source and target databases

## Learning resources
* [CloudBeaver Documentation](https://cloudbeaver.io/docs/)
* [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
* [Helm Charts Repository](https://helm.sh/docs/topics/charts/)
* [Oracle JDBC URL Format](https://docs.oracle.com/en/database/oracle/oracle-database/19/jjdbc/data-sources-and-URLs.html)
