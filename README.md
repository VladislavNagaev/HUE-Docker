# Hadoop User Experience (HUE) Docker

## Quick Start

Build image:
~~~
make --jobs=$(nproc --all) --file Makefile 
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
