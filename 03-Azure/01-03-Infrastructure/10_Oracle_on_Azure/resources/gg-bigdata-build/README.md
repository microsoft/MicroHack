# GoldenGate Installation

Hello I need you to build based on the following instruction https://blogs.oracle.com/coretec/post/running-goldengate-23ai-on-kubernetes an docker container for "GoldenGate for Distributed Applications and Analytics". Follow the instructions mentioned on the link. I already downloaded the corresponding zip file "V1043090-01.zip" into the workspace. Change the default password to <font color=red><"The assigned one at the beginning of the workshop"></font>. Upload the docker image to the Azure Container Registry "/subscriptions/<font color=red><"sub-mhodaa>"</font>/resourceGroups/odaa/providers/Microsoft.ContainerRegistry/registries/odaamh". Run the container in Azure Kubernetes Service /subscriptions/<font color=red><"sub-mhx>"</font>/resourceGroups/odaa1/providers/Microsoft.ContainerService/managedClusters/odaa1.
Note you are already setup to access the AKS with kubectl via the command "az aks get-credentials". You also have access to the ACR via "az acr login" already, just make sure to use the correct azure subscription context. 

## Reference Links

- [Oracle GoldenGate download center](https://www.oracle.com/europe/middleware/technologies/goldengate-downloads.html#) – official portal for trial binaries, patches, and licensing information for GoldenGate.
- [GoldenGate 23 container build scripts](https://github.com/oracle/docker-images/tree/main/OracleGoldenGate/23) – Oracle-maintained Dockerfiles and helper scripts for building GoldenGate 23.x images.
- [Running GoldenGate 23ai on Kubernetes (blog)](https://blogs.oracle.com/coretec/post/running-goldengate-23ai-on-kubernetes) – step-by-step guide for deploying GoldenGate 23ai into a Kubernetes environment.


