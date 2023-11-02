# Challenge 4: Scale up your services

Duration: 15 min

[Previous Challange Solution](./03-Azure-Monitor-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./05-Ingress-controller-solution.md)

## Task 1: Create your clusters

Here you can find ready to go manifests for both instances:

- [redis](https://kubernetes.io/docs/tutorials/configuration/configure-redis-using-configmap/)
- [wordpress](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

## Task 2: Scale the clusters

Scaling your clusters can be achieved via the scale command of kubectl. Here is a sample:

```bash
kubectl scale [--resource-version=version] [--current-replicas=count] --replicas=COUNT (-f FILENAME | TYPE NAME)
```

For example, for redis you can execute the following commands:

```bash
kubectl create deploy redis --image=redis
```

Next, you can specify the number of replicas, e.g. 5:

```bash
kubectl scale --replicas=5 deployment/redis
```
