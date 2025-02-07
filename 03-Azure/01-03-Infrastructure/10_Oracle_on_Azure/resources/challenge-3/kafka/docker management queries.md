docker-compose logs connect

docker inspect container-name (for ex. oracle-xe)

docker network ls 
docker network inspect container-name (for ex. oracle-xe)

docker-compose down
docker-compose up -d

    docker exec -it --workdir /root --user root oracle-xe1  bash


find the ip address of a docker container
docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" oracle-xe1



How to clean logs of docker-compose connect container
1. docker-compose stop connect
2. docker exec -it datareplicationkafka-connect-1 bash
3. rm -rf /path/to/log/files/*
4. rm -rf /var/log/connect/*
5. exit 
6. docker-compose start connect


How to identify the network IP address of a docker container

docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oracle-xe1