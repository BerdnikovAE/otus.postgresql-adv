# ДЗ 03. Установка и настройка PostgteSQL в контейнере Docker

## сделаем виртуалку в YC как в ДЗ 02

## Docker
Ставим в ```vm-docker``` Docker по иструкции https://docs.docker.com/engine/install/debian/
``` sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# проверим 
sudo docker run hello-world
```

## postgres & client docker 
Разворачиваем postgres и клиент 
``` sh
sudo mkdir -p /var/lib/postgres/data
# сделаем сеть
docker network create --driver bridge pg-net

sudo docker run --name postgres-server --network pg-net -p 5432:5432 -e POSTGRES_USER=otus -e POSTGRES_PASSWORD=otuspsw -d -v "/var/lib/postgres/data":/var/lib/postgresql/data postgres:14

sudo docker run -it --rm --name postgres-client --network pg-net postgres:14 psql -h postgres-server -U otus

psql (14.9 (Debian 14.9-1.pgdg120+1))
Type "help" for help.

otus=# create table t1 (i int);
CREATE TABLE
otus=# insert into t1 values (100500);
INSERT 0 1
otus=# \q
root@vm-docker:/home/ae# docker ps
CONTAINER ID   IMAGE         COMMAND                  CREATED              STATUS              PORTS
 NAMES
25305ac1f3d7   postgres:14   "docker-entrypoint.s…"   About a minute ago   Up About a minute   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   postgres-server

# убиваем все контейнеры 
docker rm $(docker ps -a -q) -f

# запустим новый (снова) 
sudo docker run --name postgres-server --network pg-net -p 5432:5432 -e POSTGRES_USER=otus -e POSTGRES_PASSWORD=otuspsw -d -v "/var/lib/postgres/data":/var/lib/postgresql/data postgres:14
# клиента 
sudo docker run -it --rm --name postgres-client --network pg-net postgres:14 psql -h postgres-server -U otus

psql (14.9 (Debian 14.9-1.pgdg120+1))
Type "help" for help.
otus=# select * from t1;
   i
--------
 100500
(1 row)

```
Всё на месте






