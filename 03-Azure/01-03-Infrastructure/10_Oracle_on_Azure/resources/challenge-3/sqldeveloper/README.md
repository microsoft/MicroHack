~~~bash
apt-get update

apt-get install openjdk-17-jdk

java -version
~~~

openjdk 17.0.7 2023-04-18
OpenJDK Runtime Environment (build 17.0.7+7-Ubuntu-0ubuntu118.04)
OpenJDK 64-Bit Server VM (build 17.0.7+7-Ubuntu-0ubuntu118.04, mixed mode, sharing)


Install necessary packages for running SQL Developer
~~~bash
apt-get update && \
    apt-get install -y openjdk-17-jdk libxext6 libxrender1 libxtst6 libfreetype6 libfontconfig1 && \
    apt-get clean

apt-get install alien dpkg-dev debhelper build-essential
~~~

Install SQL Developer 
~~~bash
alien sqldeveloper-24.3.1-347.1826.noarch.rpm
~~~



docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix oracle-xe-sqldeveloper


If SQLDeveloper current version 24 will be used against outdated database like 11g Rel2 the following error might happen:

~~~bash
java.sql.SQLException: ORA-00604: error occurred at recursive SQL level 1 ORA-01882: timezone region not found
~~~

In a plain a SQL-Developer installation under Windows go to directory C:\Program Files\sqldeveloper\sqldeveloper\bin and add
~~~bash
AddVMOption -Duser.timezone=CET
~~~
to file sqldeveloper.conf.


