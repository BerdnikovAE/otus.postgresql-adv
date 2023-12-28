# ДЗ 13. Работа c Yandex Managed Service for PostgreSQL

``` sh
# сделаем vm с которой будем работать 
ssh-keygen -f ~/.ssh/y -t ed25519 -q -N ""
(echo -n "ae0:" && cat ~/.ssh/y.pub) > ~/.ssh/y.txt

yc compute instance create \
  --cores 2 --memory 4 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --metadata-from-file ssh-keys=.ssh/y.txt \
  --name pg01 \
  --hostname pg01

ssh -i ~/.ssh/y ubuntu@xx.xx.xx.xx

# intall 15 postgres 

sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters

# создадим кластер Yandex Managed Service for PostgreSQL руками через GUI
# s3-c2-m8 (2 vCPU, 100% vCPU rate, 8 ГБ RAM)
# 20 ГБ network-ssd

# подключимся 
psql "host=rc1a-ylkpz659m27pg0qz.mdb.yandexcloud.net \
    port=6432 \
    sslmode=verify-full \
    dbname=db1 \
    user=user1 \
    target_session_attrs=read-write"

```
``` sql
-- как обычно таблички сделаем 
CREATE TYPE t_sensor AS ENUM ('BME280', 'BMP180', 'BMP280', 'DHT22', 'DS18B20', 'HPM', 'HTU21D', 'PMS1003', 'PMS3003', 'PMS5003', 'PMS6003', 'PMS7003', 'PPD42NS', 'SDS011');
CREATE TABLE sensors
(
    sensor_id integer,
    sensor_type t_sensor,
    location integer,
    lat real,
    lon real,
    timestamp timestamp,
    P1 real,
    P2 real,
    P0 real,
    durP1 real,
    ratioP1 real,
    durP2 real,
    ratioP2 real,
    pressure real,
    altitude real,
    pressure_sealevel real,
    temperature real,
    humidity real    
);

-- загрузим данные в БД
\copy sensors from 'file-100.csv' WITH DELIMITER ',' CSV quote '"'
--COPY 100000000

-- включим тайминг
\timing

-- первый уже привычный запрос + все предыдущие резуультаты для сравнения
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# postgres                              -- Time: 216423.353 ms (03:36.423)
# CockroachDB                           -- Time: 142.412s total (execution 142.412s / network 0.000s)
# Greenplum                             -- Time: 5401.526 ms
# CitusDB YC k8s                        -- Time: 109026.862 ms (01:49.027)
# Yandex Managed Service for PostgreSQL --

SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# postgres                              -- Time: 128721.572 ms (02:08.722)
# CockroachDB                           -- Time: 102.802s total (execution 102.801s / network 0.000s)
# Greenplum                             -- Time: 7142.630 ms
# CitusDB YC k8s                        -- Time: 62055.982 ms (01:02.056)
# Yandex Managed Service for PostgreSQL --

-- вернулись по результатамс чего начали - postgresql
```

``` sh
yc managed-postgresql cluster delete postgresql458

```
