# ДЗ 02. Настройка дисков для Постгреса

## сделаем виртуалку в YC и поднимем там 15 postgresql и сделаем табличку 
``` sh
# install YC CLI
sudo apt install curl -y
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
source ~/.bashrc

# init
yc init

ssh-keygen -f ~/.ssh/y -t ed25519 -q -N ""
(echo -n "ae0:" && cat ~/.ssh/y.pub) > ~/.ssh/y.txt

yc compute instance create \
  --cores 2 --memory 4 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts \
  --network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
  --zone ru-central1-b \
  --metadata-from-file ssh-keys=.ssh/y.txt \
  --name pg01 \
  --hostname pg01

ssh -i ~/.ssh/y ubuntu@$xx.xx.xx.xx

# intall 15 postgres 

sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters

# создадим табличку в БД postgres
ubuntu@pg01:~$ sudo -u postgres psql -p 5432
could not change directory to "/home/ubuntu": Permission denied
psql (15.4 (Ubuntu 15.4-1.pgdg22.04+1))
Type "help" for help.

postgres=# create table test (i int);
CREATE TABLE
postgres=# insert into test values (2023);
INSERT 0 1
postgres=# select * from test;
  i
------
 2023
(1 row)
# всё нормально, табличка есть 
```

## сделаем диск новый в YC и подключим его VM
``` sh
# делаем доп.диск 
yc compute disk create --name pg01-disk1 --zone ru-central1-b --size 15G

# примаунтим его к VM 
yc compute instance attach-disk --name pg01 --disk-name pg01-disk1 --auto-delete

# в VM форматим и моунтим его в /mnt/data
sudo mkdir -p /mnt/data
sudo sgdisk --new 1::0  /dev/vdb
sudo mkfs.ext4 /dev/vdb1
lsblk --fs

sudo sh -c 'echo "/dev/disk/by-uuid/092d2af5-f782-4011-b80d-b5a76c5f170b /mnt/data ext4 defaults 0 1" >> /etc/fstab'

sudo mount -a
sudo chown -R postgres:postgres /mnt/data/
```

## перенесем данные postgresql на этот новый диск
``` sh
# стопаем postgresql
sudo systemctl stop postgresql@15-main

# переносим каталог с данными 
mv /var/lib/postgresql/15 /mnt/data

# стартуем
sudo systemctl stop postgresql@15-main

# ошибка ожидаемо 
Error: /var/lib/postgresql/15/main is not accessible or does not exist

# правим конфиг 
vi /etc/postgresql/15/main/postgresql.conf
data_directory = '/mnt/data/15/main'

# стартуем
sudo -u postgres pg_ctlcluster 15 main start

# всё ок
ubuntu@pg01:~$ systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
     Active: active (exited) since Sat 2023-09-09 15:01:11 UTC; 6min ago
   Main PID: 15423 (code=exited, status=0/SUCCESS)
        CPU: 2ms

Sep 09 15:01:11 pg01 systemd[1]: Starting PostgreSQL RDBMS...
Sep 09 15:01:11 pg01 systemd[1]: Finished PostgreSQL RDBMS.

# проверям - есть табличка
postgres=# select * from test;
  i
------
 2023
(1 row)
``` 

## Задание под *: делаем еще одну VM, а старую стопаем и диск ее забираем
``` sh
# делаем  еще одну виртуалку 
yc compute instance create \
  --cores 2 --memory 4 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts \
  --network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
  --zone ru-central1-b \
  --metadata-from-file ssh-keys=.ssh/y.txt \
  --name pg01 \
  --hostname pg01

# стопаем первую VM и забираем ее диск 
yc compute instance stop pg01
yc compute instance detach-disk --name pg01 --disk-name pg01-disk1

# подключаем диск к новой VM
yc compute instance attach-disk --name pg02 --disk-name pg01-disk1 --auto-delete

# снова ставим  postgresql
sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters

pg_ctlcluster 15 main stop

# правим конфиг 
vi /etc/postgresql/15/main/postgresql.conf
data_directory = '/mnt/data/15/main'

# подключаем диск 
sudo mkdir -p /mnt/data
sudo sh -c 'echo "/dev/disk/by-uuid/092d2af5-f782-4011-b80d-b5a76c5f170b /mnt/data ext4 defaults 0 1" >> /etc/fstab'
sudo mount -a

pg_ctlcluster 15 main start

# проверяем что там с табличкой
sudo -u postgres psql -p 5432
postgres=# select * from test;
  i
------
 2023
(1 row)
# всё гуд
```
