# Hadoop User Experience (HUE) Docker

## Quick Start

To run HUE, you first need to run [postgres](https://github.com/VladislavNagaev/Postgres-Docker) and [hadoop](https://github.com/VladislavNagaev/Hadoop-Docker) containers.

Build image:
~~~
make --jobs=$(nproc --all) --file Makefile 
~~~

Prepare postgres DB:
~~~
# multi-line command
docker cp ./initdb.sql /
docker exec postgres psql --username=postgres --dbname=postgres -f /initdb.sql

# or one-line command
cat ./initdb.sql | docker exec -i postgres psql --username=postgres --dbname=postgres
~~~

Depoyment of containers:
~~~
docker-compose -f docker-compose.yaml up
~~~


## Interfaces:
---
* [HUE](http://127.0.0.1:8888)


## Technologies
---
Project is created with:
* Cloudera HUE: 4.11.0
* Docker verion: 23.0.1
* Docker-compose version: v2.16.0
