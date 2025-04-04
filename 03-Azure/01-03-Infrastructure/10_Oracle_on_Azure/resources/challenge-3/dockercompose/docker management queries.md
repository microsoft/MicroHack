To build the demo environment an Azure virtual server or Azure container apps can be used.

As container images we are trying to use the public available container images from Docker Hub but you can use the available images from the Oracle Container Registry as well see [here](https://container-registry.oracle.com/ords/f?p=113:10::::::)


For the docker version we are using a debian 12 - bookworm image with at least 8 cores and 64 CPU's. The docker compose file is stored under /kafka/docker and contains the following images:

1. Oracle express edition 11g Rel.2
2. Oracle express edition 21c patchset 3
3. Ora2PG 24
4. confluent environment consist of:
   1. Kafka broker
   2. Servive registry
   3. Connect
   4. Control Center

All used images are public available on docker hub. If a different database version will be used the valid license requirement of the vendor needs to be considered.


An alternative to the docker images is Azure Container Apps. Which are not considered in this demo due to time restrictions.


In case data need to be copied on the remote Azure linux vm you the following SCP command can be used. If the server is deploy with an User/Password replace the private key in the command syntax. 


## How to login into the Docker hub if required:

~~~bash
export DOCKER_USERNAME=your-username
export DOCKER_PASSWORD=your-password

echo $DOCKER_PASSWORD | docker login --username $DOCKER_USERNAME --password-stdin
~~~


~~~bash
scp -C -i 'privatekey.pem' -r 'path_to_files'  azureuser@48.209.90.102:'path_to_files'
~~~

~~~bash
docker-compose logs connect

docker inspect container-name (for ex. oracle-xe)

docker network ls 
docker network inspect container-name (for ex. oracle-xe)

docker-compose down
docker-compose up -d

docker exec -it --workdir /root --user root oracle-xe1  bash


find the ip address of a docker container
docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" oracle-xe1
~~~


How to clean logs of docker-compose connect container

1. docker-compose stop connect
2. docker exec -it datareplicationkafka-connect-1 bash
3. rm -rf /path/to/log/files/*
4. rm -rf /var/log/connect/*
5. exit 
6. docker-compose start connect


How to identify the network IP address of a docker container
~~~bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oracle-xe1
~~~