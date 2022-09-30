# Challenge 2: Deploy and configure your first pod

[Previous Challange Solution](./01-Setup-Environment-solution.md) - **[Home](../README.md)** - [Next Challenge Solution](./03-Azure-Monitor-solution.md)

For deploying something on kubernetes, we can use tools like terraform or helm. If you want to use those, take a look here:

* [terraform kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
* [helm](https://helm.sh/docs/)

If not, you can just create a YAML-Manifest by your own, but be aware of the right intendation!

[Here](https://github.com/josedom24/kubernetes/blob/master/ejemplos/busybox/busybox.yaml) is a sample manifest for the BusyBox-Container.

To apply your manifest, use the following command:

```
kubectl apply -f (manifest-filename)
```

To access your freshly deployed container, you can use the following command:

```
kubectl exec -it (pod-name) /bin/bash
```
