# ДЗ 01. Работа с уровнями изоляции транзакции в PostgreSQL

## Инфраструктура 

-- развернем ВМ postgres в GCE
-- ubuntu-2010-groovy перестала поддерживаться
--image-family=ubuntu-2004-lts
gcloud beta compute --project=postgresql-linux-2023 instances create postgres --zone=us-central1-a --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=753465360043-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=postgres --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
 
gcloud compute instances create vm-01 --project=postgresql-linux-2023 --zone=europe-west4-a --machine-type=e2-medium --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=753465360043-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --create-disk=auto-delete=yes,boot=yes,device-name=vm-01,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20230831,mode=rw,size=10,type=projects/postgresql-linux-2023/zones/europe-west4-a/diskTypes/pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ec-src=vm_add-gcloud --reservation-affinity=any

gcloud compute ssh postgres

-- по умолчанию установится 12 версия
sudo apt-get -y install postgresql

-- для установки 13 версии (без 12)
-- https://www.postgresql.org/download/linux/ubuntu/
sudo apt update && sudo apt upgrade -y -q
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
-- установится 13 версия
sudo apt-get -y install postgresql

-- если 13 поверх 12
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-13

-- 14 версия
sudo apt update && sudo apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get -y install postgresql-14

-- 15 версия
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15


-- если будете экспериментировать с промежуточными версиями, не LTS
-- корректно добавим к upgrade & install postgres
-- sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q
-- sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-14

-- посмотрим, что кластер стартовал
pg_lsclusters

-- посмотрим новый метод шифрования пароля
sudo cat /etc/postgresql/15/main/pg_hba.conf

-- старый
sudo cat /etc/postgresql/12/main/pg_hba.conf


-- протестим ssh 
gcloud beta compute --project=celtic-house-266612 instances create sshtest --zone=us-central1-a --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=sshtest --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any

gcloud compute ssh sshtest

gcloud compute instances list

ssh aeugene@104.197.254.133

ssh-keygen -t rsa
-- запускаем агента, если не запущен
eval `ssh-agent -s`
ssh-add .ssh/id_rsa

-- добавим ключ в metadata

ssh aeugene@34.31.49.167

-- удалим тестовую ВМ
gcloud compute instances delete sshtest


-- запустим во 2 окне для тестирования уровней изоляции транзакций
gcloud compute ssh postgres

-- посмотрим на наши кластера
pg_lsclusters

-- удалим все ненужные
sudo pg_ctlcluster 12 main stop
sudo pg_dropcluster 12 main

sudo -u postgres psql
-- sudo su postgres
-- psql


-- создадим табличку для тестов
-- https://www.postgresql.org/docs/14/sql-set-transaction.html
-- список БД
CREATE TABLE test (i serial, amount int);
INSERT INTO test(amount) VALUES (100);
INSERT INTO test(amount) VALUES (500);
SELECT * FROM test;

\echo :AUTOCOMMIT
\set AUTOCOMMIT OFF
show transaction isolation level;
set transaction isolation level read committed;
set transaction isolation level repeatable read;
set transaction isolation level serializable;
SELECT txid_current();
\set AUTOCOMMIT ON
SELECT txid_current();
SELECT * FROM test;
commit;

SELECT * FROM pg_stat_activity;

-- глобально можно изменить
-- ALTER DATABASE <db name> SET DEFAULT_TRANSACTION_ISOLATION TO 'read committed';
-- set the default_transaction_isolation parameter appropriately, 
-- either in postgresql.conf or with ALTER SYSTEM. After reloading, this will apply to the whole cluster.
-- You can also use ALTER DATABASE or ALTER ROLE to change the setting for a database or user only.


-- test TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- 1 console
BEGIN;
SELECT * FROM test;

-- 2 consoleapp=# 
-- sudo -u postgres psql
\c iso
BEGIN;
UPDATE test set amount = 555 WHERE i = 1;
COMMIT;

-- 1 console
SELECT * FROM test; -- different values
COMMIT;


-- TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- 1 console
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM test;
 i | amount
---+--------
 2 |    500
 1 |    555
(2 rows)

-- 2 console
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO test VALUES (777);
COMMIT;

-- 1 console
SELECT * FROM test;
 i | amount
---+--------
 2 |    500
 1 |    555
(2 rows)


gcloud compute instances delete postgres

--ЯО
-- Ubuntu 22.04
-- Минимальные параметры 2 ядра 2Гб ОЗУ. Рекомендую SSD диск 10Gb. Также не забывайте отключать ВМ, когда не используете
-- https://cloud.yandex.ru/docs/compute/operations/vm-connect/ssh?from=int-console-help-center-or-nav
yc compute instance create \
  --name postgres \
  --hostname postgres \
  --cores 2 \
  --memory 4 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --metadata-from-file ssh-keys=/home/aeugene/.ssh/aeugene.txt

yc compute instance create `
  --name vm02 `
  --cores 2 `
  --memory 4 `
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts `
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \ `
  --ssh-key /p/y.pub `
  --preemptible `
  --zone ru-central1-c 
  
yc compute instance create `
  --name vm01 `
  --cores 2 `
  --memory 4 `
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts `
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 `
  --zone ru-central1-a `
  --metadata-from-file ssh-keys=/p/y.txt


-- обратит внимание на aeugene.txt
cat /home/aeugene/.ssh/aeugene.txt

-- как сгенерировать ssh ключи
-- ssh-keygen -t rsa
-- запускаем агента, если не запущен
-- eval `ssh-agent -s`
-- ssh-add .ssh/id_rsa


yc compute instance get postgres
yc compute instance get --full postgres


ssh aeugene@51.250.89.67
ssh yc-user@51.250.89.67
ssh root@51.250.89.67
ssh ubuntu@51.250.89.67



-- 15 версия
-- DEBIAN_FRONTEND=noninteractive - чтобы интерактивно не отвечать на обновление компонентов
-- в ЯО оооочень долгая процедура
-- sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && 
-- сразу ставим ПГ15
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15

-- Можно увеличичить на ней память до 4GB

yc compute instance update postgres.ru-central1.internal --memory 8


-- https://supabase.com/blog/supavisor-1-million

