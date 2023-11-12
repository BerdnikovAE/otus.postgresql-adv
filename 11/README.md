# ДЗ 11. Parallel cluster

## Разворачиваем Greenplum через Vagrant 
Буду делать всё на локальном компьютере в VirtualBox.

Готовим 6 виртуалок:
- master 
- standy 
- 4 x server-segment

Все виртуалки провижинятся скриптом [install_greenplum.sh](install_greenplum.sh) 

``` sh
# поднимаем всё
vagrant up 

# на всех хостах чтоб добавилось 
1..6 | %{ vagrant ssh gp-0$_ -c 'cat /vagrant/*.pub | sudo tee /home/gpadmin/.ssh/authorized_keys && sudo chown gpadmin:gpadmin /home/gpadmin/.ssh/authorized_keys' }

# подключимся к master-у 
vagrant ssh gp-01

# дальше все под gpadmin
sudo -u gpadmin bash 

mkdir /home/gpadmin/gpconfigs
cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config
nano /home/gpadmin/gpconfigs/gpinitsystem_config
# поправить имя master
# поправить кол-во сегментов, пусть хотя бы 1 будет 

cd ~
# проверим что связь со всеми хостами есть 
gpssh -f hostfile_exkeys -e 'ls -la /opt/greenplum-db-*'

# инициируем greenplum
gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem -s gp-02 --mirror-mode=spread

# если после ребута 
# gpstart 

# заходим в psql 
psql -d postgres 

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
DISTRIBUTED RANDOMLY
PARTITION BY RANGE (sensor_type);

# зальём данные 
\copy sensors from '/vagrant/export-10.csv' WITH DELIMITER ',' CSV quote '"'

# всё встает колом и не рабаотет 
```

## Попробуем в YC 

``` sh
# сгенерируем ключик для YC
ssh-keygen -f ~/.ssh/id_25519 -t ed25519 -q -N ""
(echo -n "ae0:" && cat ~/.ssh/*.pub) > ~/.ssh/id_ed25519.txt
cat ./.ssh/id_ed25519.pub >> ./.ssh/authorized_keys

# отключим воспросы про fingerprint
echo "StrictHostKeyChecking no" | sudo tee -a /etc/ssh/ssh_config

# сделаем несколько виртуалок 
for i in {1..6}; do \
yc compute instance create \
  --cores 2 \
  --memory 8 \
  --create-boot-disk size=50G,type=network-hdd,image-folder-id=standard-images,image-family=ubuntu-1804-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=/home/ae/.ssh/id_ed25519.txt \
  --name gp0$i \
  --hostname gp0$i \
  --async 
    done;

# готово ? 
yc compute instance list

# закинем в них ключики и сделаем переменные для удобства 
for i in {1..6}; do \
    declare gp0$i=$(yc compute instance get gp0$i | grep "        address:" | cut -c 18-100)
    v=gp0$i 
    echo "gp0$i ${!v}"
    scp ./.ssh/id_* ubuntu@${!v}:/home/ubuntu/.ssh
    scp ./.ssh/authorized_keys ubuntu@${!v}:/home/ubuntu/.ssh
    done;

# заготовка для файла hosts для узлов. вроде бы и не надо, но greenplum пользуется
yc compute instance list | awk '/1/ {print $12 " " $4}' > etc_hosts

#yc compute instance list | awk '/1/ {print "declare " $4 "=" $10}'


# заготовка для файла /home/gpadmin/hostfile_exkeys
rm hostfile_exkeys
for i in {1..6}; do \
    echo "gp0$i" >> hostfile_exkeys
    done;

# заготовка для файла /home/gpadmin/hostfile_gpinitsystem
rm hostfile_gpinitsystem
for i in {3..6}; do \
    echo "gp0$i" >> hostfile_gpinitsystem
    done;
    

# закинем скриптик установочный и запустим, повторить на всех 
for i in {1..6}; do \
    v=gp0$i 
    scp /mnt/c/p/otus.postgresql-adv/11/install_gp.sh ubuntu@${!v}:/home/ubuntu

    scp etc_hosts ubuntu@${!v}:/home/ubuntu
    scp hostfile_exkeys ubuntu@${!v}:/home/ubuntu
    scp hostfile_gpinitsystem ubuntu@${!v}:/home/ubuntu

    #ssh ubuntu@${!v} bash /home/ubuntu/install_gp.sh
    done;

# Подключаемся к gp01
ssh ubuntu@$gp01
sudo su - gpadmin

mkdir /home/gpadmin/gpconfigs
cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config
#nano /home/gpadmin/gpconfigs/gpinitsystem_config

echo "declare -a DATA_DIRECTORY=(/data/primary /data/primary /data/primary)" >> /home/gpadmin/gpconfigs/gpinitsystem_config
echo "MASTER_HOSTNAME=10.128.0.25" >> /home/gpadmin/gpconfigs/gpinitsystem_config




#### OS-configured hostname or IP address of the master host.
# поправить имя master
# поправить кол-во сегментов, пусть хотя бы 1 будет 

cd ~

# проверим что связь со всеми хостами есть 

for i in {1..6}; do \
    ssh gpadmin@gp0$i ls
    done;

gpssh-exkeys -f hostfile_exkeys
gpssh -f hostfile_exkeys -e 'ls -la /opt/greenplum-db-*'

# интересно потестить скорость между узлами 
gpcheckperf -f hostfile_exkeys -r M -d /tmp
#gpcheckperf -f hostfile_exkeys -r ds -D -d /data/primary -d /data/master

# инициируем greenplum
gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem -s gp02 --mirror-mode=spread

# если после ребута 
# gpstart 

# проверим
gpstate -s
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-Starting gpstate with args: -s
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Greenplum Database) 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source'
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL 9.4.26 (Greenplum Database 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source) on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit compiled on Oct  4 2023 23:27:38'
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-Obtaining Segment details from master...
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-Gathering data from segments...
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:--Master Configuration & Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master host                    = gp01
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master postgres process ID     = 22250
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master data directory          = /data/master/gpseg-1
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master port                    = 5432
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master current role            = dispatch
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Greenplum initsystem version   = 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Greenplum current version      = PostgreSQL 9.4.26 (Greenplum Database 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source) on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit compiled on Oct  4 2023 23:27:38
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Postgres version               = 9.4.26
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Master standby                 = gp02
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Standby master state           = Standby host passive
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-Segment Instance Status Report
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg0
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 17281
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg1
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6001
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 17280
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp03
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg2
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6002
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 17282
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg3
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 16775
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg4
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6001
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 16776
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp04
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg5
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6002
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 16777
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231112:10:42:29:022498 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up

# выглядит хорошо

# заходим в psql 
psql -d postgres 
# делаем табличку 

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

\copy sensors from '/home/gpadmin/file-100.csv' WITH DELIMITER ',' CSV quote '"'
# только для 100 млн. записей 
\timing


SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# postgres      -- Time: 216423.353 ms (03:36.423)
# CockroachDB   -- Time: 142.412s total (execution 142.412s / network 0.000s)
# Greenplum     -- Time: 5401.526 ms

explain
SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# postgres      -- Time: 128721.572 ms (02:08.722)
# CockroachDB   -- Time: 102.802s total (execution 102.801s / network 0.000s)
# Greenplum     -- Time: 7142.630 ms

postgres=# explain
postgres-# SELECT
postgres-#     sensor_type,
postgres-#     avg(temperature)
postgres-# FROM sensors
postgres-# GROUP BY sensor_type;
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Gather Motion 12:1  (slice2; segments: 12)  (cost=0.00..2080.12 rows=14 width=12)
   ->  GroupAggregate  (cost=0.00..2080.12 rows=2 width=12)
         Group Key: sensor_type
         ->  Sort  (cost=0.00..2080.12 rows=2 width=12)
               Sort Key: sensor_type
               ->  Redistribute Motion 12:12  (slice1; segments: 12)  (cost=0.00..2080.12 rows=2 width=12)
                     Hash Key: sensor_type
                     ->  Result  (cost=0.00..2080.12 rows=2 width=12)
                           ->  HashAggregate  (cost=0.00..2080.12 rows=2 width=12)
                                 Group Key: sensor_type
                                 ->  Seq Scan on sensors  (cost=0.00..916.85 rows=8333536 width=8)
 Optimizer: Pivotal Optimizer (GPORCA)
(12 rows)

Time: 4.757 ms



# ИНТЕРЕСНО
```


## Разное, заметки 
```sh 
# если что-то пошло не так, то можно к узлам напрямую подключится
PGOPTIONS='-c gp_session_role=utility' psql -h gp01 -p 6000 -d postgres

gpstate -s # Greenplum Array Configuration details
gpstate -m # Mirror Segments in the system and their status
gpstate -c # To see the primary to mirror segment mappings
gpstate -f # To see the status of the standby master mirror:
```

