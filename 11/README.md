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
1..4 | %{ vagrant ssh gp-0$_ -c 'cat /vagrant/*.pub | sudo tee /home/gpadmin/.ssh/authorized_keys && sudo chown gpadmin:gpadmin /home/gpadmin/.ssh/authorized_keys' }

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
for i in {1..4}; do \
yc compute instance create \
  --cores 2 \
  --memory 8 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-1804-lts \
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
for i in {1..4}; do \
    declare gp0$i=$(yc compute instance get gp0$i | grep "        address:" | cut -c 18-100)
    v=gp0$i 
    echo "gp0$i ${!v}"
    scp ./.ssh/id_* ubuntu@${!v}:/home/ubuntu/.ssh
    scp ./.ssh/authorized_keys ubuntu@${!v}:/home/ubuntu/.ssh
    done;

# закинем скриптик установочный и запустим, повторить на всех 
for i in {2..4}; do \
    v=gp0$i 
    scp /mnt/c/p/otus.postgresql-adv/11/install_gp.sh ubuntu@${!v}:/home/ubuntu
    ssh ubuntu@${!v} bash /home/ubuntu/install_gp.sh
    done;

# Подключаемся к gp01
ssh ubuntu@$gp01
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
gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem -s gp02 --mirror-mode=spread

# если после ребута 
# gpstart 

# проверим
gpstate -s
# 20231108:16:07:23:016502 gpstate:gp01:gpadmin-[INFO]:-Starting gpstate with args: -s
# 20231108:16:07:23:016502 gpstate:gp01:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Greenplum Database) 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source'
# 20231108:16:07:23:016502 gpstate:gp01:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL 9.4.26 (Greenplum Database 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source) on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit compiled on Oct  4 2023 23:27:38'
# 20231108:16:07:23:016502 gpstate:gp01:gpadmin-[INFO]:-Obtaining Segment details from master...
# 20231108:16:07:23:016502 gpstate:gp01:gpadmin-[INFO]:-Gathering data from segments...
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:--Master Configuration & Status
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master host                    = gp01
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master postgres process ID     = 14936
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master data directory          = /data/master/gpseg-1
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master port                    = 5432
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master current role            = dispatch
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Greenplum initsystem version   = 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Greenplum current version      = PostgreSQL 9.4.26 (Greenplum Database 6.25.3 build commit:367edc6b4dfd909fe38fc288ade9e294d74e3f9a Open Source) on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit compiled on Oct  4 2023 23:27:38
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Postgres version               = 9.4.26
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Master standby                 = gp02
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Standby master state           = Standby host passive
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-Segment Instance Status Report
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp01
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp01
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg0
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 14923
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp02
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp02
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg1
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 9159
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp03
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp03
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg2
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 8391
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-----------------------------------------------------
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Segment Info
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Hostname                          = gp04
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Address                           = gp04
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Datadir                           = /data/primary/gpseg3
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Port                              = 6000
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-   Status
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      PID                               = 8499
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Configuration reports status as   = Up
# 20231108:16:07:24:016502 gpstate:gp01:gpadmin-[INFO]:-      Database status                   = Up

# выглядит хорошо

# заходим в psql 
psql -d postgres 
# делаем табличку 
# делаем select и ВСЁ ВИСНЕТ 

# postgres=# create table t1 (i int);
# NOTICE:  Table doesn't have 'DISTRIBUTED BY' clause -- Using column named 'i' as the Greenplum Database data distribution key for this table.
# HINT:  The 'DISTRIBUTED BY' clause determines the distribution of data. Make sure column(s) chosen are the optimal data distribution key to minimize skew.
# CREATE TABLE
# postgres=# select * from t1;
# WARNING:  interconnect may encountered a network error, please check your network  (seg1 slice1 10.128.0.31:6000 pid=9770)
# DETAIL:  Failed to send packet (seq 1) to 127.0.1.1:38224 (pid 15359 cid -1) after 100 retries.
# WARNING:  interconnect may encountered a network error, please check your network  (seg2 slice1 10.128.0.24:6000 pid=8524)
# DETAIL:  Failed to send packet (seq 1) to 127.0.1.1:38224 (pid 15359 cid -1) after 100 retries.
# WARNING:  interconnect may encountered a network error, please check your network  (seg3 slice1 10.128.0.4:6000 pid=8638)
# DETAIL:  Failed to send packet (seq 1) to 127.0.1.1:38224 (pid 15359 cid -1) after 100 retries.
# ^CCancel request sent


# и опять всё встает колом
 
```


## Разное, заметки 
```sh 
# если что-то пошло не так, то можно к узлам напрямую подключится
PGOPTIONS='-c gp_session_role=utility' psql -h gp01 -p 6000 -d postgres

gpstate -s # Greenplum Array Configuration details
gpstate -m # Mirror Segments in the system and their status
gpstate -c # To see the primary to mirror segment mappings
gpstate -f # To see the status of the standby master mirror:


sudo -u gpadmin bash 
cd $HOME && wget --quiet https://edu.postgrespro.ru/demo_small.zip && unzip demo_small.zip 
psql -d postgres < demo_small.sql
```