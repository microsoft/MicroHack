# Challenge 7 - (Optional) Use Estate Explorer to visualize the Oracle ADB instance

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-08.md)

## Goal 

The goal of this exercise is to deploy and configure Estate Explorer to visualize and analyze your Oracle Autonomous Database instance, providing comprehensive insights into your database landscape and performance characteristics.

## Actions

* Install Estate Explorer using Helm in your Kubernetes cluster
* Configure the Estate Explorer deployment with the external IP address of your ingress controller
* Set up the database connection credentials in the configuration
* Deploy Estate Explorer to a dedicated namespace
* Access the Estate Explorer interface through the configured ingress
* Connect Estate Explorer to your Oracle ADB instance
* Explore the visualization and analysis capabilities

## Success criteria

* You have successfully deployed Estate Explorer using Helm
* All Estate Explorer pods are running in the dedicated namespace
* You can access the Estate Explorer web interface via the ingress controller
* You have successfully configured the connection to your Oracle ADB instance
* You can visualize your Oracle database landscape and explore its features

## Learning resources
* [Helm Documentation](https://helm.sh/docs/)
* [Oracle Autonomous Database Documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/)
* [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
