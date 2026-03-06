## Challenge 3 - Deploy CPU based Large & Small Language Models (LLM/SLM)

### Goal
In challenge 3 you will deploy a LLM/SLM to your Azure Arc-enabled Kubernetes Cluster to run an AI prompt.

### Actions
* Login to your Kubernetes via Azure CLI Kubernetes Proxy and use kubectl
* Create a new namespace and deploy a AIMH for CPU based compute resources
* Deploy openwebUI, access it and link it to the local ollama API

### Success Criteria
* In the Azure portal navigate to your arc-enabled k8s cluster. Under Namespaces > you can see a new namespace called AIMH
* In the AIMH namespace you see your Ollama and OpenWebUI deployment
* you entered your first prompt "What is a Microsoft MicroHack?" and you see a result.

### Learning Resources
* (https://learn.microsoft.com/en-us/azure/aks/aksarc/deploy-ai-model?tabs=portal)
* (https://github.com/otwld/ollama-helm) CPU based LLM/SLM
* (https://docs.openwebui.com/getting-started/quick-start/)
* (https://github.com/kaito-project/kaito) GPU Based LLM/SLM

### Solution - Spoilerwarning
[Solution Steps](../walkthroughs/challenge-03/solution.md)

[Next challenge](challenge-04.md) | [Back](../Readme.md)