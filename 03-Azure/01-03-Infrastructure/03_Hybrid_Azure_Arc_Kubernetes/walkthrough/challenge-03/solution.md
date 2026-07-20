# Walkthrough Challenge 3 - Deploy CPU based Large & Small Language Models (LLM/SLM)

[Back to challenge](../../challenges/challenge-03.md) - [Next Challenge's Solution](../challenge-04/solution.md)

## Prerequisites
* You have an arc-connected k8s cluster/finisched challenge 01.
* Verify the firewall requirements in addition to the Azure Arc-enabled Kubernetes network requirements.
* You must be logged in to az cli (az login)
* You need kubectl and helm 

## Task 1 - Check the Kubernetes cluster, check nodes and size
Execute the following script in your bash shell to access the kuberentes cluster:
```bash
kubectl get nodes
kubectl get all --all-namespaces
```

## Task 2 - Create a new namespace and prepare the helm repository

```bash
helm repo add otwld https://helm.otwld.com/
helm repo add open-webui https://helm.openwebui.com/
helm repo update
kubectl create namespace aimh
```

## Task 3 - install ollama and openwebui as an AI framework running in the Azure Arc enabled kubernetes Cluster


### Step 1: Install ollama with phi4-mini

```bash
helm install ollama otwld/ollama \
  --namespace aimh \
  --set service.type=ClusterIP \
  --set persistentVolume.enabled=true \
  --set persistentVolume.size=20Gi \
  --set ollama.models.pull[0]=phi4-mini:latest \
  --set ollama.models.run[0]=phi4-mini:latest \
  --set resources.requests.cpu="2" \
  --set resources.requests.memory="4Gi" \
  --set resources.limits.cpu="4" \
  --set resources.limits.memory="8Gi"
```

### Step 2: Install openwebUI

```bash
helm install openwebui open-webui/open-webui \
  --namespace aimh \
  --set service.type=NodePort \
  --set service.nodePort=30080 \
  --set ollama.enabled=false \
  --set ollamaUrls[0]="http://ollama.aimh.svc.cluster.local:11434" \
  --set persistence.enabled=true \
  --set persistence.size=5Gi
```

Get the the URL of the openwebui.
```bash
export NODE_PORT=$(kubectl get -n aimh -o jsonpath="{.spec.ports[0].nodePort}" services openwebui-open-webui)
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
echo "Open http://$NODE_IP:$NODE_PORT"
```
**Note:** In this microhack lab K3s is configured to use internal IP addresses per default. Use the provided Windows workstation in the lab to open the URL.

## Task 5 - Access the openwebUI and run a prompt
* Open webbrowser to access URL provided in the previous step, create user login to the openwebUI portal.
* Then click on the arrow icon next to "Select a model" and in the pop up click "Manage Connections".

![add-connection](img/01_add_connection.png)

* Add a new Ollama API connection, by clicking the "+" sign on the right hand side next to Ollama API
![add-connection-ollama](img/02_add_connection_ollama.png)

* Add the URL of your ollama deployment including port ("http://ollama.aimh.svc.cluster.local:11434") and click on save (2x).

![add-connection-IPandPort](img/03_add_connection_ip_port.png)
* Try out your first prompt. If your connection works, you should see in the upper left corner the deployed model "phi4-mini".

You successfully completed challenge 3! 🚀🚀🚀

[Next challenge](../../challenges/challenge-04.md) - [Next Challenge's Solution](../challenge-04/solution.md)
