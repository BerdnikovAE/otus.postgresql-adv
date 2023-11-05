# ДЗ 09. Развернуть HA кластер

Кластер на Patroni делали в ДЗ 06. Поэтому тут сделаем на базе pg_auto_failover

Готовим 3+1 VM в Yandex Cloud:
- primary   = pgpri
- secondary = pgsec
- monitor   = pgmon
- client    = cli


``` sh
# сделаем несколько виртуалок 
for i in pgpri pgsec pgmon cli; do \
yc compute instance create \
  --cores 2 \
  --memory 2 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=/home/ae/.ssh/id_ed25519.txt \
  --name $i \
  --hostname $i 
    done;

# должно быть готово
yc compute instance list

# сделаем переменные чтоб IP не использовать  
for i in pgpri pgsec pgmon cli; do \
    declare $i=$(yc compute instance get $i | grep "        address:" | cut -c 18-100)
    done;

# закинем в VM ключики ssh
for i in pgpri pgsec pgmon cli; do \
    v=$i 
    echo "$i ${!v}"
    scp ~/.ssh/id_* ubuntu@${!v}:/home/ubuntu/.ssh
    scp ~/.ssh/authorized_keys ubuntu@${!v}:/home/ubuntu/.ssh
    done;

# закинем скриптики установочные
for i in pgpri pgsec pgmon cli; do \
    v=$i
    scp /mnt/c/p/otus.postgresql-adv/09/*.sh ubuntu@${!v}:/home/ubuntu;     
    done;
    
# и запустим на всех своё
ssh ubuntu@$pgmon bash /home/ubuntu/mon.sh
ssh ubuntu@$pgpri bash /home/ubuntu/pri-sec.sh
ssh ubuntu@$pgsec bash /home/ubuntu/pri-sec.sh
ssh ubuntu@$cli bash /home/ubuntu/cli.sh
```
Скрптики, которые настраивают ноды:
- monitor   = [mon.sh](mon.sh)
- primary   = [pri-sec.sh](pri-sec.sh)
- secondary = [pri-sec.sh](pri-sec.sh)
- client    = [cli.sh](cli.sh)

Всё развернулось, проверяем и шатаем.

``` sh
# Подключаемся к pgmon и посмотрим что там наподнималось
ssh ubuntu@$pgmon
sudo -u postgres pg_autoctl show state --pgdata /var/lib/postgresql/ha
#   Name |  Node |  Host:Port |       TLI: LSN |   Connection |      Reported State |      Assigned State
# -------+-------+------------+----------------+--------------+---------------------+--------------------
# node_1 |     1 | pgpri:5432 |   1: 0/303C140 |   read-write |             primary |             primary
# node_2 |     2 | pgsec:5432 |   1: 0/303C140 |    read-only |           secondary |           secondary

# Посмотреть коннекшен стринги 

sudo -u postgres pg_autoctl show uri --pgdata /var/lib/postgresql/ha
#         Type |    Name | Connection String
# -------------+---------+-------------------------------
#      monitor | monitor | postgres://autoctl_node@10.128.0.20:5432/pg_auto_failover?sslmode=require
#    formation | default | postgres://pgsec:5432,pgpri:5432/testapp?target_session_attrs=read-write&sslmode=require

sudo -u postgres pg_autoctl show uri --pgdata /var/lib/postgresql/ha --formation default
# postgres://pgsec:5432,pgpri:5432/testapp?target_session_attrs=read-write&sslmode=require



# идем на клиента 
ssh ubuntu@$cli
# подключаемся с по url, с желаением писать-читать 
psql "postgres://pgsec:5432,pgpri:5432/testapp?target_session_attrs=read-write&sslmode=require" -U postgres
# You are connected to database "testapp" as user "postgres" on host "pgpri" (address "10.128.0.25") at port "5432".
# SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
testapp=# create table t1 (i int);
CREATE TABLE
testapp=# insert into t1 values (1);
INSERT 0 1

# делаем switchover
sudo -u postgres pg_autoctl perform switchover  --pgdata /var/lib/postgresql/ha
# 10:49:13 34906 INFO  Waiting 60 secs for a notification with state "primary" in formation "default" and group 0
# 10:49:13 34906 INFO  Listening monitor notifications about state changes in formation "default" and group 0
# 10:49:13 34906 INFO  Following table displays times when notifications are received
#     Time |   Name |  Node |  Host:Port |       Current State |      Assigned State
# ---------+--------+-------+------------+---------------------+--------------------
# 10:49:14 | node_1 |     1 | pgpri:5432 |             primary |            draining
# 10:49:14 | node_2 |     2 | pgsec:5432 |           secondary |   prepare_promotion
# 10:49:14 | node_2 |     2 | pgsec:5432 |   prepare_promotion |   prepare_promotion
# 10:49:14 | node_2 |     2 | pgsec:5432 |   prepare_promotion |    stop_replication
# 10:49:14 | node_1 |     1 | pgpri:5432 |             primary |      demote_timeout
# 10:49:14 | node_1 |     1 | pgpri:5432 |            draining |      demote_timeout
# 10:49:14 | node_1 |     1 | pgpri:5432 |      demote_timeout |      demote_timeout
# 10:49:15 | node_2 |     2 | pgsec:5432 |    stop_replication |    stop_replication
# 10:49:15 | node_2 |     2 | pgsec:5432 |    stop_replication |        wait_primary
# 10:49:15 | node_1 |     1 | pgpri:5432 |      demote_timeout |             demoted
# 10:49:15 | node_2 |     2 | pgsec:5432 |        wait_primary |        wait_primary
# 10:49:15 | node_1 |     1 | pgpri:5432 |             demoted |             demoted
# 10:49:15 | node_1 |     1 | pgpri:5432 |             demoted |          catchingup
# 10:49:16 | node_1 |     1 | pgpri:5432 |          catchingup |          catchingup
# 10:49:17 | node_1 |     1 | pgpri:5432 |          catchingup |           secondary
# 10:49:17 | node_1 |     1 | pgpri:5432 |           secondary |           secondary
# 10:49:17 | node_2 |     2 | pgsec:5432 |        wait_primary |             primary
# 10:49:17 | node_2 |     2 | pgsec:5432 |             primary |             primary

# проверяем 
sudo -u postgres pg_autoctl show state --pgdata /var/lib/postgresql/ha
#   Name |  Node |  Host:Port |       TLI: LSN |   Connection |      Reported State |      Assigned State
# -------+-------+------------+----------------+--------------+---------------------+--------------------
# node_1 |     1 | pgpri:5432 |   2: 0/3053020 |    read-only |           secondary |           secondary
# node_2 |     2 | pgsec:5432 |   2: 0/3053020 |   read-write |             primary |             primary

# пробуем в существующей коннекции с клиента посмотреть
testapp=# \conninfo
You are connected to database "testapp" as user "postgres" on host "pgpri" (address "10.128.0.25") at port "5432".
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

# всё ок мы до сих пор на pgpri
# попробуем вставить что-нибудь 
testapp=# insert into t1 values (2);
FATAL:  terminating connection due to administrator command
SSL connection has been closed unexpectedly
The connection to the server was lost. Attempting reset: Succeeded.
psql (12.16 (Ubuntu 12.16-0ubuntu0.20.04.1), server 15.4 (Ubuntu 15.4-2.pgdg20.04+1))
WARNING: psql major version 12, server major version 15.
         Some psql features might not work.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
# он увидел что не может и
testapp=# \conninfo
# переподключил нас на pgsec
You are connected to database "testapp" as user "postgres" on host "pgsec" (address "10.128.0.14") at port "5432".
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
# а тут уже все вставляется
testapp=# insert into t1 values (2);
INSERT 0 1

# да и данные на месте
testapp=# select * from t1;
 i
---
 1
 2
(2 rows)


# ВСЁ РАБОТАЕТ
```
