# ДЗ 10. Multi master

Создадим CockroachDB на VM в Yandex Cloud, закачаем туда что-нибудь и сравним на таких же объемах с postgresql

 
## Clickhouse и на простом postgresql
Сначала вспомним как это было на VirtualBox. Для чистоты эксперимента повторим это в Yandex Cloud и запомним время.

### Clickhouse и загрузка данных 
```sh
# create VM for clickhouse
yc compute instance create \
  --cores 2 \
  --memory 8 \
  --create-boot-disk size=150G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=/home/ae/.ssh/id_ed25519.txt \
  --name pg \
  --hostname pg 

# развернем clickhouse как в ДЗ 08
# и зальем данные 730 млн строк
# ↗ Progress: 183.25 million rows, 2.29 GB (568.36 thousand rows/s., 7.10 MB/s.)                (1.0 CPU, 2.43 GB RAM) 22% 

select count() from sensors ;
# ┌───count()─┐
# │ 730237511 │
# └───────────┘
# 1 row in set. Elapsed: 0.546 sec.

# отправим в YC Object Storage 720 млн строк или 
INSERT INTO FUNCTION
   s3(
       'https://storage.yandexcloud.net/sensors-db/file-720.csv',
       '...jV9',
       '...laI2',
       'CSV'
    )
    PARTITION BY rand() % 10
SELECT *
FROM sensors
#limit 100000000;

# скопировалось 
ycs3 ls sensors-db
# 2023-11-05 16:26:22 64857126247 file-730.csv

# вспомним запросы которые мы делали на clickhouse в VirtualBox 
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# VirtaulBox: ответ готов за 8 секунд после ребута и за 0.8 сек. в повторе 
# YndexCloud: ответ готов за 5 секунд после ребута и за 5.4 сек. в повторе 

SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# VirtaulBox: 14 rows in set. Elapsed: 43.014 sec. Processed 730.24 million rows, 3.02 GB (16.98 million rows/s., 70.15 MB/s.)
# YndexCloud: 14 rows in set. Elapsed: 17.820 sec. Processed 730.24 million rows, 2.86 GB (40.98 million rows/s., 160.70 MB/s.)
```

### postgresql
```sh
# сделаем такую виртуалку как для Clickhouse
# скачаем CSV с yandex s3
# и зальем данные в postgres, только 100 млн. 720 вообще смысла нет 
ycs3 cp s3://sensors-db/file-100.csv /mnt/data/file-100.csv
\copy sensors from '/mnt/data/file-100.csv' WITH DELIMITER ',' CSV quote '"'
# только для 100 млн. записей 
\timing
ANALYZE;
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# VirtualbBox: -- Time: 230131.601 ms (03:50.132)
# YandexCloud: -- Time: 216423.353 ms (03:36.423)

# может индекс как-то поможет
CREATE INDEX ix_sensort_type ON sensors (sensor_type);

# повторяем запрос 
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# VirtualbBox: -- Time: 3114.434 ms (00:03.114)
# YandexCloud: -- Time: 8679.926 ms (00:08.680)

# чуть сложней запросик: 
SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# и время улетает
# VirtualbBox: -- Time: 220521.156 ms (03:40.521)
# YandexCloud: -- Time: 128721.572 ms (02:08.722)

# В ОБЩЕМ ВРЕМЯ +- ТАКОЕ ЖЕ
```

Теперь проверим как там у CockroachDB 

# CockroachDB 

``` sh

# сделаем несколько виртуалок 
for i in $(seq -f "cdb%02g" 1 4); do \
yc compute instance create \
  --cores 2 \
  --memory 8 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=/home/ae/.ssh/id_ed25519.txt \
  --name $i \
  --hostname $i \
  --async
    done;

# должно быть готово
yc compute instance list

# сделаем переменные чтоб IP не использовать  
for i in $(seq -f "cdb%02g" 1 4); do \
    declare $i=$(yc compute instance get $i | grep "        address:" | cut -c 18-100)
    v=$i 
    echo "$i = ${!v}"
    done;

# установка на всех нодах
for i in $(seq -f "cdb%02g" 1 4); do \
    v=$i 
cat << EOF | ssh ubuntu@${!v}
wget -qO- https://binaries.cockroachdb.com/cockroach-v23.1.11.linux-amd64.tgz | \
tar  xvz && sudo cp -i cockroach-v23.1.11.linux-amd64/cockroach /usr/local/bin/ && \
sudo mkdir -p /opt/cockroach && \
sudo chown ubuntu:ubuntu /opt/cockroach
EOF
done;

# генерим сертификаты на cdb01
ssh ubuntu@$cdb01
mkdir certs my-safe-directory
cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key 
cockroach cert create-node localhost $(seq -f "cdb%02g" 1 4) --certs-dir=certs --ca-key=my-safe-directory/ca.key --overwrite
cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key --overwrite
cockroach cert list --certs-dir=certs
logout

# скопируем везде 
cd ~
mkdir certs-for-cdb
scp ubuntu@$cdb01:/home/ubuntu/certs/* /home/ae/certs-for-cdb/
for i in $(seq -f "cdb%02g" 1 4); do \
    v=$i    
    ssh ubuntu@${!v} mkdir /home/ubuntu/certs
    scp certs-for-cdb/* ubuntu@${!v}:/home/ubuntu/certs
    done;


# стартанем везде
for i in $(seq -f "cdb%02g" 1 4); do \
    v=$i    
    ssh ubuntu@${!v} 'cockroach start --certs-dir=certs --advertise-addr='$i' --join=$(seq -f "cdb%02g" -s "," 1 4) --cache=.25 --max-sql-memory=.25 --background'
    done;

# init
ssh ubuntu@$cdb01 cockroach init --certs-dir=certs --host=cdb01

# status 
ssh ubuntu@$cdb01 cockroach node status --host=cdb01 --certs-dir=certs
# id      address sql_address     build   started_at      updated_at      locality        is_available    is_live
# 1       cdb01:26257     cdb01:26257     v23.1.11        2023-11-05 18:16:54.638979 +0000 UTC    2023-11-05 18:18:30.700546 +0000 UTC            true    true
# 2       cdb03:26257     cdb03:26257     v23.1.11        2023-11-05 18:16:55.258485 +0000 UTC    2023-11-05 18:18:28.273086 +0000 UTC            true    true
# 3       cdb04:26257     cdb04:26257     v23.1.11        2023-11-05 18:16:55.495873 +0000 UTC    2023-11-05 18:18:28.513134 +0000 UTC            true    true
# 4       cdb02:26257     cdb02:26257     v23.1.11        2023-11-05 18:16:55.674597 +0000 UTC    2023-11-05 18:18:28.689539 +0000 UTC            true    true

# далее руками подключаемся к первой ноде 
ssh ubuntu@$cdb01
cockroach sql --certs-dir=certs --host=cdb01 
#
# Welcome to the CockroachDB SQL shell.
# All statements must be terminated by a semicolon.
# To exit, type: \q.
#
# Server version: CockroachDB CCL v23.1.11 (x86_64-pc-linux-gnu, built 2023/09/27 01:53:43, go1.19.10) (same version as client)
# Cluster ID: 9c4573af-bbdd-4f95-9afc-dd717befc2cf
#
# Enter \? for a brief introduction.
#

# сделаем табличку 
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
)

IMPORT INTO sensors (sensor_id ,sensor_type ,location ,lat ,lon ,timestamp ,P1 ,P2 ,P0 ,durP1 ,ratioP1 ,durP2 ,ratioP2 ,pressure ,altitude ,pressure_sealevel ,temperature ,humidity ) 
CSV DATA ('https://storage.yandexcloud.net/sensors-db/file-100.csv') WITH DELIMITER = ',', SKIP = '1';

# Time: 1154.380s total (execution 1154.191s / network 0.189s)

SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# postgres: -- Time: 216423.353 ms (03:36.423)
# CockroachDB  Time: 142.412s total (execution 142.412s / network 0.000s)
#  => Раза в два быстрей
# Но я упустил и машинки почему то создались по 2 гига RAM, а не 8 как у postgres, но зато их 4

# чуть сложней запросик: 
SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# postgres : -- Time: 128721.572 ms (02:08.722)
# CockroachDB   Time: 102.802s total (execution 102.801s / network 0.000s)

# а если индекс сделать ?
CREATE INDEX ON defaultdb.public.sensors (sensor_type) STORING (temperature);

# ERROR: unexpected EOF
# warning: error retrieving the transaction status: connection closed unexpectedly: conn closed
# warning: connection lost!
# opening new connection: all session settings will be lost
# warning: error retrieving the database name: failed to connect to `host=cdb01 user=root database=`: dial error (dial tcp 127.0.1.1:26257: connect: connection refused)

# Всё упало, надо попробовать с нормальным кол-вом памяти
# Добавил виртуалка по 8 GB


CREATE INDEX ON defaultdb.public.sensors (sensor_type) STORING (temperature);
# Time: 528.357s total (execution 528.357s / network 0.001s)

SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# Time: 28.294s total (execution 28.293s / network 0.000s)
# уже лучше 


# ИНТЕРЕСНО 
```