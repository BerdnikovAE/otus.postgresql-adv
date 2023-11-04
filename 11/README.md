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
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=.ssh/id_ed25519.txt \
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
for i in {1..4}; do \
    v=gp0$i 
    scp /mnt/c/p/otus.postgresql-adv/11/install_greenplum.sh ubuntu@${!v}:/home/ubuntu
    ssh ubuntu@${!v} bash /home/ubuntu/install_greenplum.sh
    done;

# Подключаемся к gp01
ssh ubuntu@$gp01

sudo -u gpadmin bash 
cd $HOME && wget --quiet https://edu.postgrespro.ru/demo_small.zip && unzip demo_small.zip 
psql -d postgres < demo_small.sql

# и опять всё встает колом
# но выглядит будтно все работает 
gpstate -s # Greenplum Array Configuration details
gpstate -m # Mirror Segments in the system and their status
gpstate -c # To see the primary to mirror segment mappings
gpstate -f # To see the status of the standby master mirror:

```


## Разное, заметки 
```sh 
# если что-то пошло не так, то можно к узлам напрямую подключится
PGOPTIONS='-c gp_session_role=utility' psql -h gp01 -p 6000 -d postgres


```