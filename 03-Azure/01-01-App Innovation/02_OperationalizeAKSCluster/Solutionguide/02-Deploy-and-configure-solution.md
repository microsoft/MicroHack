# Challenge 2: Deploy and configure your first pod

Duration: 30 min

[Previous Challange Solution](./01-Setup-Environment-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./03-Azure-Monitor-solution.md)

## Task 1: Setup the environment

For deploying something on kubernetes, we can use tools like terraform or helm. If you want to use those, take a look here:

- [terraform kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [helm](https://helm.sh/docs/)

If not, you can just create a YAML-Manifest on your own, but be aware of the right intendation!

[Here](https://github.com/josedom24/kubernetes/blob/master/ejemplos/busybox/busybox.yaml) is a sample manifest for the BusyBox-Container.

## Task 2: Connect to the cluster

After installing kubectl and connecting to your AKS Cluster ([Connect to AKS via CLI](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli)) apply your manifest using the following command:

```bash
kubectl apply -f (manifest-filename)
```

To see your container and some others that are deployed by default, just type in the following:

```bash
kubectl get pod --all-namespaces
```

To access your freshly deployed container, you can use the following command:

```bash
kubectl exec -it (pod-name) /bin/sh
```
