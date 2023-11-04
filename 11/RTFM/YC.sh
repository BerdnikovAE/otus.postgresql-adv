-- managed от ЯО
-- https://console.cloud.yandex.ru/folders/b1ggepi457i7gntd5u09/managed-greenplum/clusters

документация 
-- https://gpdb.docs.pivotal.io/6-20/install_guide/init_gpdb.html

-- Развернем 4 ВМ small в регионе
-- for i in {1..1}; do gcloud beta compute --project=celtic-house-266612 instances create gp$i --zone=europe-west1-b --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=gp$i --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any & done;
for i in {1..1}; do gcloud beta compute --project=celtic-house-266612 instances create gp$i --zone=europe-north1-a --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=gp$i --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any & done;

-- развернем 4 ВМ в другом регионе
-- for i in {5..8}; do gcloud beta compute --project=celtic-house-266612 instances create gp$i --zone=europe-north1-a --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=gp$i --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any & done;

-- configure system
-- https://gpdb.docs.pivotal.io/6-20/install_guide/prep_os.html

-- install 
-- greenplum install ubuntu 20.04 - погуглим и увидим боль)
-- on single node https://greenplum.org/install-greenplum-oss-on-ubuntu/
-- https://gpdb.docs.pivotal.io/6-20/install_guide/install_gpdb.html

-- Create the gpadmin group and user.
gcloud compute ssh gp1

sudo groupadd gpadmin
sudo useradd gpadmin -r -m -g gpadmin
-- не сработает echo gpadmin123 | sudo passwd gpadmin --stdin
-- автоматизация баш скриптов
-- https://habr.com/ru/company/ruvds/blog/328436/
echo gpadmin:gpadmin123 | sudo chpasswd

-- создаем ssh ключ
sudo -u gpadmin ssh-keygen -t rsa -b 4096 -q -f /home/gpadmin/.ssh/id_rsa -N ''

-- даем судо (не wheel по инструкции)
sudo usermod -aG sudo gpadmin

-- download deb package
https://network.pivotal.io/api/v2/products/vmware-tanzu-greenplum/releases/1099296/product_files/1223327/download

-- скопируем пакет с ноута
-- permission denied
-- gcloud compute scp /mnt/c/download/greenplum-db-6.20.4-ubuntu18.04-amd64.deb gp1:/home/gpadmin/greenplum-db-6.20.4-ubuntu18.04-amd64.deb
-- долго в условиях Геленджикского 4г - 10 минут и то не факт(
-- gcloud compute scp /mnt/c/download/greenplum-db-6.20.4-ubuntu18.04-amd64.deb gp1:/home/aeugene/greenplum-db-6.20.4-ubuntu18.04-amd64.deb
gsutil -m cp -R gs://chicago10/greenplum-db-6.20.4-ubuntu18.04-amd64.deb .

-- on node
sudo mv /home/aeugene/greenplum-db-6.20.4-ubuntu18.04-amd64.deb /home/gpadmin/greenplum-db-6.20.4-ubuntu18.04-amd64.deb

sudo apt install ./greenplum-db-6.20.4-ubuntu18.04-amd64.deb
The following packages have unmet dependencies:
 greenplum-db-6 : Depends: libevent-2.1-6 but it is not installable
                  Depends: libreadline7 but it is not installable
E: Unable to correct problems, you have held broken packages.

-- чтож поставим ручками

sudo apt update && sudo apt upgrade -y
sudo apt install libevent-2.1-6 libreadline7
sudo apt install apr apr-util bash bzip2 curl krb5 libcurl libevent libxml2 libyaml zlib openldap openssh openssl openssl-libs perl readline rsync

-- Pivotal Greenplum 6 runs on the following operating system platforms:
    Red Hat Enterprise Linux 64-bit 7.x (See the following Note.)
    Red Hat Enterprise Linux 64-bit 6.x
    CentOS 64-bit 7.x
    CentOS 64-bit 6.x
    Ubuntu 18.04 LTS
-- Minimum Memory 	16 GB RAM per server

-- напишем свой скрипт, чтож
nano greenplum.sh
chmod +x greenplum.sh
sudo ./greenplum.sh

-- добавим ключики
sudo gpg --keyserver keyserver.ubuntu.com --recv 3C6FDC0C01D86213
sudo gpg --export --armor 3C6FDC0C01D86213 | sudo apt-key add -

sudo ./greenplum.sh

-- посмотрим, что установилось
dpkg-query -l

-- выдадим права
sudo chown -R gpadmin:gpadmin /usr/local/greenplum*

-- по умолчанию каталога не оказалось
sudo find / -name "greenplum*" 

sudo chown -R gpadmin:gpadmin /opt/greenplum*
-- sudo chgrp -R gpadmin /opt/greenplum*

-- скрипт первоначальной настройки
sudo -u gpadmin source /opt/greenplum-db-6.21.0/greenplum_path.sh
sudo su gpadmin
bash
source /opt/greenplum-db-6.21.0/greenplum_path.sh
which gpssh
exit
bash
which gpssh
-- пропишем в bashrc
nano ~/.bashrc

-- проверим
exit
bash
which gpssh


-- for i in {2..4}; do gcloud beta compute --project=celtic-house-266612 instances create gp$i --zone=europe-west1-b --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=gp$i --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any & done;
for i in {2..4}; do gcloud beta compute --project=celtic-house-266612 instances create gp$i --zone=europe-north1-a --machine-type=e2-small --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=933982307116-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-ssd --boot-disk-device-name=gp$i --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any & done;

-- создаем юзера и ссх
for i in {2..4}; do gcloud compute ssh gp$i --command='sudo groupadd gpadmin && sudo useradd gpadmin -r -m -g gpadmin && echo gpadmin:gpadmin123 | sudo chpasswd && sudo -u gpadmin ssh-keygen -t rsa -b 4096 -q -f /home/gpadmin/.ssh/id_rsa -N "" && sudo usermod -aG sudo gpadmin' & done;

gcloud compute ssh gp2

for i in {2..4}; do gcloud compute ssh gp$i --command='cat > greenplum.sh << EOF 
#! /bin/bash
# Check we are a root
if [ "\$EUID" -ne 0 ]
    then echo "Please run this script as root"
    exit
fi
REPO="/etc/apt/sources.list.d/greenplum-ubuntu-db-bionic.list"
PIN="/etc/apt/preferences.d/99-greenplum"
echo "Add required repositories"
touch \$REPO
cat > \$REPO <<REPOS
deb http://ppa.launchpad.net/greenplum/db/ubuntu bionic main
deb http://ru.archive.ubuntu.com/ubuntu bionic main
REPOS
echo "Configure repositories"
touch \$PIN
cat > \$PIN <<PIN_REPO
Package: *
Pin: release v=18.04
Pin-Priority: 1
PIN_REPO
echo "Repositories described in \$REPO"
echo "Repositories configuration in \$PIN"
echo "Installing greenplum"
gpg --keyserver keyserver.ubuntu.com --recv 3C6FDC0C01D86213
gpg --export --armor 3C6FDC0C01D86213 | sudo apt-key add -
apt update && apt install greenplum-db-6 -y
EOF
' & done;

for i in {2..4}; do gcloud compute ssh gp$i --command='chmod +x greenplum.sh && sudo ./greenplum.sh' & done;


-- если раньше времени завершил баш скрпт
-- gcloud compute ssh gp1
-- sudo dpkg --configure -a

-- пропишем source
sudo su gpadmin
which gpssh

-- не сработает
-- . /opt/greenplum-db-6.21.0/greenplum_path.sh
-- по умолчанию у нас исопльзуется dash, а нужен bash
ls -l $(which sh)

-- answer no
sudo dpkg-reconfigure dash

-- проверим
sudo su gpadmin
which gpssh
echo $SHELL

-- сменим ручками
chsh
/bin/bash
exit
sudo su gpadmin
which gpssh

-- проделаем то же самое на 2-4 ВМ
gcloud compute ssh gp2
sudo su gpadmin
echo "source /opt/greenplum-db-6.21.0/greenplum_path.sh" >> ~/.bashrc
chsh -s /bin/bash
which gpssh

-- Use the ssh-copy-id command to add the gpadmin user’s public key to the authorized_hosts SSH file on every other host in the cluster.
-- не работает
ssh-copy-id gp2
SSHPASS=gpadmin123 sshpass -e ssh-copy-id gp2
ssh-copy-id -i ~/.ssh/id_rsa.pub gpadmin@gp2

sudo nano /etc/ssh/sshd_config
PasswordAuthentication no -> yes
sudo systemctl restart sshd
-- второй вариант ручками слить публичные ключи в 1 файл authorized_hosts и разложить в ~/.ssh/
-- https://blog.programs74.ru/how-to-copy-ssh-key-using-utility-ssh-copy-id/
-- https://www.digitalocean.com/community/questions/ssh-copy-id-not-working-permission-denied-publickey


-- In the gpadmin home directory, create a file named hostfile_exkeys that has the machine configured 
-- host names and host addresses (interface names) for each host in your Greenplum system (master, standby master, and segment hosts). 
-- Make sure there are no blank lines or extra spaces. Check the /etc/hosts file on your systems for the correct host names 
-- to use for your environment. 
nano ~/hostfile_exkeys
gp1
gp2
gp3
gp4


-- Run the gpssh-exkeys utility with your hostfile_exkeys file to enable n-n passwordless SSH for the gpadmin user.
cd ~
gpssh-exkeys -f hostfile_exkeys

-- Error: unable to import module: libssl.so.1.0.0: cannot open shared object file:
-- https://askubuntu.com/questions/1261614/ubuntu-20-04-libssl-so-1-0-0-cannot-open-shared-object-file-no-such-file-or-d
sudo nano /etc/apt/sources.list
cat << EOF | tee -a /etc/apt/sources.list
deb http://security.ubuntu.com/ubuntu xenial-security main
EOF 

sudo apt update && sudo apt install libssl1.0.0 -y

-- на каждом хссте
gpssh-exkeys -f hostfile_exkeys

-- confirm ssh instalation
gpssh -f hostfile_exkeys -e 'ls -l /opt/greenplum-db-6.21.0'


-- Creating the Data Storage Areas
-- https://gpdb.docs.pivotal.io/6-20/install_guide/create_data_dirs.html
sudo mkdir -p /data/master

-- Change ownership of this directory to the gpadmin user. For example:
sudo chown gpadmin:gpadmin /data/master

-- Using gpssh, create the master data directory location on your standby master as well. For example:
gpssh -h gp2 -e 'mkdir -p /data/master'
-- error !!!
-- [gp2] mkdir -p /data/master
-- [gp2] mkdir: cannot create directory ‘/data’: Permission denied

-- under root
-- тоже не сработает, от рута пароля то нет)
-- sudo su
-- source /opt/greenplum-db-6.21.0/greenplum_path.sh 
-- gpssh -h gp2 -e 'mkdir -p /data/master'
-- gpssh -h gp2 -e 'chown gpadmin:gpadmin /data/master'

-- on 2
sudo mkdir -p /data/master
sudo chown gpadmin:gpadmin /data/master

-- on 3-4
sudo mkdir -p /data/primary
sudo mkdir -p /data/mirror
sudo chown -R gpadmin /data/*


-- Validating Your Systems
-- https://gpdb.docs.pivotal.io/6-20/install_guide/validate.html


-- Initializing a Greenplum Database System
-- https://gpdb.docs.pivotal.io/6-20/install_guide/init_gpdb.html
-- on all hosts
nano ~/hostfile_gpinitsystem
gp3
gp4

-- on 1
cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config \
     /home/gpadmin/gpconfigs/gpinitsystem_config
-- cp: cannot create regular file '/home/gpadmin/gpconfigs/gpinitsystem_config': No such file or directory
mkdir /home/gpadmin/gpconfigs
cp
-- сконфигурируем
nano /home/gpadmin/gpconfigs/gpinitsystem_config

-- Running the Initialization Utility
!!! у нас файл hostfile_gpinitsystem в домашнем каталоге!!!
-- gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem
-- сразу включаем мирроринг и второго мастера
cd ~
gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem -s gp2 --mirror-mode=spread
-- уменьшим до 4 сегментов
-- отключим мирроринг
-- и снова ошибка - каталоги на предыдущем шаге другие (
./bin/touch: cannot touch '/data1/primary/tmp_file_test': No such file or directory
20220611:10:12:53:005114 gpinitsystem:gp1:gpadmin-[FATAL]:-Cannot write to /data1/primary on gp3  Script Exiting!


20220611:10:20:45:012005 gpinitstandby:gp1:gpadmin-[INFO]:-Successfully created standby master on gp2
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Successfully completed standby master initialization
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Scanning utility log file for any warning messages
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[WARN]:-*******************************************************
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[WARN]:-Scan of log file indicates that some warnings or errors
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[WARN]:-were generated during the array creation
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Please review contents of log file
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-/home/gpadmin/gpAdminLogs/gpinitsystem_20220611.log
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-To determine level of criticality
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-These messages could be from a previous run of the utility
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-that was called today!
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[WARN]:-*******************************************************
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Greenplum Database instance successfully created
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-------------------------------------------------------
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-To complete the environment configuration, please
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-update gpadmin .bashrc file with the following
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-1. Ensure that the greenplum_path.sh file is sourced
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-2. Add "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1"
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-   to access the Greenplum scripts for this instance:
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-   or, use -d /data/master/gpseg-1 option for the Greenplum scripts
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-   Example gpstate -d /data/master/gpseg-1
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Script log file = /home/gpadmin/gpAdminLogs/gpinitsystem_20220611.log
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-To remove instance, run gpdeletesystem utility
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Standby Master gp2 has been configured
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-To activate the Standby Master Segment in the event of Master
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-failure review options for gpactivatestandby
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-------------------------------------------------------
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-The Master /data/master/gpseg-1/pg_hba.conf post gpinitsystem
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-has been configured to allow all hosts within this new
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-array to intercommunicate. Any hosts external to this
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-new array must be explicitly added to this file
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-Refer to the Greenplum Admin support guide which is
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-located in the /opt/greenplum-db-6.21.0/docs directory
20220611:10:20:45:008438 gpinitsystem:gp1:gpadmin-[INFO]:-------------------------------------------------------


gcloud compute ssh gp1
-- после рестарта опять нет гринплама)
cat /home/gpadmin/gpAdminLogs/gpinitsystem_20220611.log

-- https://gpdb.docs.pivotal.io/6-5/admin_guide/managing/startstop.html
sudo su gpadmin
gpstart
-- 20220617:09:27:59:001197 gpstart:gp1:gpadmin-[CRITICAL]:-gpstart failed. (Reason='Environment Variable MASTER_DATA_DIRECTORY not set!') exiting...
-- https://russianblogs.com/article/7209879156/
nano ~/.bashrc
MASTER_DATA_DIRECTORY=/opt/data/master/gpseg-1
export MASTER_DATA_DIRECTORY
-- gpstart:gp1:gpadmin-[CRITICAL]:-gpstart failed. (Reason='[Errno 2] No such file or directory: '/opt/data/master/gpseg-1/postgresql.conf'

-- FU
MASTER_DATA_DIRECTORY=/data/master/gpseg-1

-- on 2-4 nodes
nano ~/.bashrc
echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" | sudo tee -a /home/gpadmin/.bashrc
export MASTER_DATA_DIRECTORY

-- gpstart:gp2:gpadmin-[ERROR]:-gpstart error: Master instance process running
-- https://greenplum.org/checking-greenplum-database-status-linux/

gpstate

psql -d postgres

cd $HOME && wget --quiet https://edu.postgrespro.ru/demo_small.zip && unzip demo_small.zip && psql -d postgres < demo_small.sql

psql -d demo
\l+
\dt+ bookings.*

CREATE TABLE flights2 (
    flight_id integer NOT NULL,
    flight_no character(6) NOT NULL,
    scheduled_departure timestamp with time zone NOT NULL,
    scheduled_arrival timestamp with time zone NOT NULL,
    departure_airport character(3) NOT NULL,
    arrival_airport character(3) NOT NULL,
    status character varying(20) NOT NULL,
    aircraft_code character(3) NOT NULL,
    actual_departure timestamp with time zone,
    actual_arrival timestamp with time zone,
    CONSTRAINT flights_check CHECK ((scheduled_arrival > scheduled_departure)),
    CONSTRAINT flights_check1 CHECK (((actual_arrival IS NULL) OR ((actual_departure IS NOT NULL) AND (actual_arrival IS NOT NULL) AND (actual_arrival > actual_departure)))),
    CONSTRAINT flights_status_check CHECK (((status)::text = ANY (ARRAY[('On Time'::character varying)::text, ('Delayed'::character varying)::text, ('Departed'::character varying)::text, ('Arrived'::character varying)::text, ('Scheduled'::character varying)::text, ('Cancelled'::character varying)::text])))
)
DISTRIBUTED RANDOMLY
PARTITION BY RANGE (scheduled_departure)
SUBPARTITION BY LIST (status)
SUBPARTITION TEMPLATE
( SUBPARTITION stat_onti VALUES ('On Time'), 
  SUBPARTITION stat_dely VALUES ('Delayed'), 
  SUBPARTITION stat_depd VALUES ('Departed'), 
  SUBPARTITION stat_arrd VALUES ('Arrived'), 
  SUBPARTITION stat_schd VALUES ('Scheduled'), 
  SUBPARTITION stat_canc VALUES ('Cancelled'),
  DEFAULT SUBPARTITION stat_othr)
  (START (TIMESTAMP '2020-01-01 00:00:00+00') INCLUSIVE
   END (TIMESTAMP '2022-01-01 00:00:00+00') EXCLUSIVE
   EVERY (INTERVAL '1 month'), 
   DEFAULT PARTITION dep_othr );

select * from flights2;

INSERT INTO flights2 SELECT * FROM bookings.flights;

select * from flights2 where scheduled_departure = '2016-10-14 07:05:00+00'; 

explain select * from flights2 where scheduled_departure = '2016-10-14 07:05:00+00'; 


-- Defining Database Objects 
-- https://gpdb.docs.pivotal.io/6-20/admin_guide/ddl/ddl.html

-- Loading and Unloading Data
-- https://gpdb.docs.pivotal.io/6-20/admin_guide/load/topics/g-loading-and-unloading-data.html




gcloud compute instances delete gp1
gcloud compute instances delete gp2
gcloud compute instances delete gp3
gcloud compute instances delete gp4
