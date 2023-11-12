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
sudo chown -R gpadmin:gpadmin /home/gpadmin/.ssh

# готовимся 
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:greenplum/db -y

# поставим greenplum-db-6
sudo apt-get update && sudo apt-get install greenplum-db-6 -y

# дадим права 
sudo chown -R gpadmin:gpadmin /opt/greenplum*

# добавим  скрипт настройки Greenplum в ~/.bashrc
echo "source /opt/greenplum-db-6.25.3/greenplum_path.sh" | sudo tee -a /home/gpadmin/.bashrc

# сменим для gpadmin дефолтовый shell
sudo chsh -s /bin/bash gpadmin

# обменяемся ключиками через /vagrant папку
# sudo cp /home/gpadmin/.ssh/id_rsa.pub /vagrant/$HOSTNAME.pub
sudo ls /home/gpadmin/.ssh

# этот файл позже пришлем с данными YC 
# cat << EOF | sudo tee -a /etc/hosts
# 192.168.0.11 gp01
# 192.168.0.12 gp02
# 192.168.0.13 gp03
# 192.168.0.14 gp04
# EOF

# этот файл позже пришлем с данными YC 
# кто у нас в кластере будет ?
# cat << EOF | sudo tee /home/gpadmin/hostfile_exkeys
# gp01
# gp02
# gp03
# gp04
# EOF

# еще чего-то будет нехватать 
cat << EOF | sudo tee -a /etc/apt/sources.list
deb http://security.ubuntu.com/ubuntu xenial-security main
EOF

sudo apt-get update && sudo apt-get install libssl1.0.0 -y

sudo mkdir -p /data/master
sudo chown gpadmin:gpadmin /data/master

sudo mkdir -p /data/primary
sudo chown gpadmin:gpadmin /data/primary

# этот файл позже пришлем с данными YC 
# cat << EOF | sudo tee /home/gpadmin/hostfile_gpinitsystem
# gp03
# gp04
# EOF

echo "export MASTER_DATA_DIRECTORY=/data/master/gpseg-1" | sudo tee -a /home/gpadmin/.bashrc
source ~/.bashrc

echo "StrictHostKeyChecking no" | sudo tee -a /etc/ssh/ssh_config

cat etc_hosts | sudo tee -a /etc/hosts

sudo sed -i "s/127.0.1.1/#127.0.1.1/g" /etc/hosts

sudo cp hostfile_exkeys /home/gpadmin/
sudo cp hostfile_gpinitsystem /home/gpadmin/
sudo chown gpadmin:gpadmin /home/gpadmin/hostfile_*

cat << EOF | sudo tee -a /etc/sysctl.conf
# kernel.shmall = _PHYS_PAGES / 2 # See Shared Memory Pages
kernel.shmall = 197951838
# kernel.shmmax = kernel.shmall * PAGE_SIZE 
kernel.shmmax = 810810728448
kernel.shmmni = 4096
vm.overcommit_memory = 2 # See Segment Host Memory
vm.overcommit_ratio = 95 # See Segment Host Memory

net.ipv4.ip_local_port_range = 10000 65535 # See Port Settings
kernel.sem = 250 2048000 200 8192
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ipfrag_high_thresh = 41943040
net.ipv4.ipfrag_low_thresh = 31457280
net.ipv4.ipfrag_time = 60
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.swappiness = 10
vm.zone_reclaim_mode = 0
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.dirty_background_ratio = 0 # See System Memory
vm.dirty_ratio = 0
vm.dirty_background_bytes = 1610612736
vm.dirty_bytes = 4294967296
EOF

echo "kernel.shmall = $(expr $(getconf _PHYS_PAGES) / 2)" | sudo tee -a /etc/sysctl.conf
echo "kernel.shmmax = $(expr $(getconf _PHYS_PAGES) / 2 \* $(getconf PAGE_SIZE))" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p
