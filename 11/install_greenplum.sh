# т.к. Greenplum существует только под ubuntu 18.04, для установки на 20.04 надо делать фокусы

# создадим пользователя и зададим пароль и добавим в sudo 
sudo groupadd gpadmin
sudo useradd gpadmin -r -m -g gpadmin
echo gpadmin:gpadmin123 | sudo chpasswd
sudo usermod -aG sudo gpadmin

# создадим ключ 
#sudo -u gpadmin ssh-keygen -t rsa -b 4096 -q -f /home/gpadmin/.ssh/id_rsa -N ''
# будем использовать ключ от яндекса 
sudo mkdir /home/gpadmin/.ssh
sudo cp ~/.ssh/* /home/gpadmin/.ssh
sudo chown gpadmin:gpadmin /home/gpadmin/.ssh{,/*}

# добавим 18.04 репозитории 
REPO="/etc/apt/sources.list.d/greenplum-ubuntu-db-bionic.list"
PIN="/etc/apt/preferences.d/99-greenplum"

echo "Add required repositories"
cat << EOF | sudo tee $REPO
deb http://ppa.launchpad.net/greenplum/db/ubuntu bionic main
deb http://ru.archive.ubuntu.com/ubuntu bionic main
EOF

echo "Configure repositories"
cat << EOF | sudo tee $PIN 
Package: *
Pin: release v=18.04
Pin-Priority: 1
EOF

sudo gpg --keyserver keyserver.ubuntu.com --recv 3C6FDC0C01D86213
sudo gpg --export --armor 3C6FDC0C01D86213 | sudo apt-key add -

# поставим greenplum-db-6
sudo apt update && sudo apt install greenplum-db-6 -y

# дадим права 
sudo chown -R gpadmin:gpadmin /opt/greenplum*

# добавим  скрипт настройки Greenplum в ~/.bashrc
echo "source /opt/greenplum-db-6.25.3/greenplum_path.sh" | sudo tee -a /home/gpadmin/.bashrc

# сменим для gpadmin дефолтовый shell
sudo chsh -s /bin/bash gpadmin

# обменяемся ключиками через /vagrant папку
# sudo cp /home/gpadmin/.ssh/id_rsa.pub /vagrant/$HOSTNAME.pub
sudo ls /home/gpadmin/.ssh

# YC это сделал сам 
# cat << EOF | sudo tee -a /etc/hosts
# 192.168.0.11 gp01
# 192.168.0.12 gp02
# 192.168.0.13 gp03
# 192.168.0.14 gp04
# EOF

# кто у нас в кластере будет ?
cat << EOF | sudo tee /home/gpadmin/hostfile_exkeys
gp01
gp02
gp03
gp04
EOF

# еще чего-то будет нехватать 
cat << EOF | sudo tee -a /etc/apt/sources.list
deb http://security.ubuntu.com/ubuntu xenial-security main
EOF

sudo apt update && sudo apt install libssl1.0.0 -y

sudo mkdir -p /data/master
sudo chown gpadmin:gpadmin /data/master

sudo mkdir -p /data/primary
sudo chown gpadmin:gpadmin /data/primary

cat << EOF | sudo tee /home/gpadmin/hostfile_gpinitsystem
gp01
gp02
gp03
gp04
EOF


echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" | sudo tee -a /home/gpadmin/.bashrc



