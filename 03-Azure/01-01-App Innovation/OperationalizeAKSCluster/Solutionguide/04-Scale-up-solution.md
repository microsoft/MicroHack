# Challenge 4: Scale up your services

[Previous Challange Solution](./03-Azure-Monitor-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./05-Ingress-controller-solution.md)

Here you can find ready to go manifests for both instances:

* [redis](https://kubernetes.io/docs/tutorials/configuration/configure-redis-using-configmap/)
* [wordpress](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

Scaling your clusters can be achieved via the scale command of kubectl. Here is a sample:
```
kubectl scale [--resource-version=version] [--current-replicas=count] --replicas=COUNT (-f FILENAME | TYPE NAME)
```
