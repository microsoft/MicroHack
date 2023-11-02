# Challenge 5: Access your services via an ingress controller

Duration: 30 minutes

[Previous Challange Solution](./04-Scale-up-solution.md) - **[Home](../README.md)**

## Task 1: Deploy Wordpress and MySQL

In case you have not completed challenge 4, follow these steps to deploy Wordpress and MySQL with Persistent Volumes:
[wordpress](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

## Task 2: Set up Ingress Controller

NginX Ingress is one of the go-to resources for purposes like ours. An example manifest and all configuration information can be found [here](https://kubernetes.github.io/ingress-nginx/deploy/).

After getting wordpress and nginx, create an ingress.yaml file for the ingress configuration:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
   - http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: wordpress
            port:
              number: 80
```

then run:

```bash
kubectl apply -f ingress.yaml
```

Get the information about your ingress:

```bash
kubectl get ingress
```

Use the public IP from this info and check if $YOUR_PUBLIC_ID/wp-admin returns the Wordpress login page.
