# GoldenGate for Distributed Applications Helm Chart

This chart packages the GoldenGate 23ai microservices container image that was built from Oracle's official Dockerfiles and pushed to `odaamh.azurecr.io`.

## Installation

```powershell
# make sure the goldengate namespace is free or use --create-namespace
helm upgrade --install goldengate-da ./helm/goldengate-da `
  --namespace goldengate --create-namespace
```

The default values expect the image `odaamh.azurecr.io/goldengate-da:23ai`, allocate a `100Gi` persistent volume using the `managed-csi` storage class, and expose the service through an Azure load balancer.

## nip.io Hostname

The default host in `values.yaml` is `ogg-bigdata.131.189.241.67.nip.io`. Update this value before installing if the service obtains a different IP:

```powershell
helm upgrade --install goldengate-da ./helm/goldengate-da `
  --namespace goldengate --create-namespace `
  --set ingress.host=ogg-bigdata.<new-ip>.nip.io
```

The chart ships with a basic ingress manifest that assumes an NGINX ingress controller. If your cluster uses a different controller (for example, Azure Application Gateway), adjust the `ingress.className` annotation or disable ingress and rely on the load balancer service instead.

Browse to `https://ogg-bigdata.<public-ip>.nip.io` and sign in with the default credentials `oggadmin / Welcome1234#`.

## Uninstall

```powershell
helm uninstall goldengate-da --namespace goldengate
```
