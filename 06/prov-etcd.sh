# Установка Postgresql отказоусточивой конфигурации: etcd+Patroni+Postgresql+pgbouncer+HAProxy+keepalived
# (делать будем на VirtualBox + Vagrant из под Windows+Powershell)

####################
# etcd (https://etcd.io/)
####################

# установим
sudo apt update && sudo apt upgrade -y && sudo apt install -y etcd

# проверим 
hostname; ps -aef | grep etcd | grep -v grep


# остановим 
sudo systemctl stop etcd

# конфиг файл 
cat << EOF | sudo tee /etc/default/etcd
ETCD_NAME="$(hostname)"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://$(hostname -I | awk '{print $NF}'):2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$(hostname -I | awk '{print $NF}'):2380"
ETCD_INITIAL_CLUSTER_TOKEN="PatroniCluster"
ETCD_INITIAL_CLUSTER="etcd-01=http://192.168.0.11:2380,etcd-02=http://192.168.0.12:2380,etcd-03=http://192.168.0.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_DATA_DIR="/var/lib/etcd"
EOF


# старт на всех трех, только если все в сети 
# sudo systemctl start etcd

# проверим что живой на ком-нибудь 
# etcdctl cluster-health && etcdctl member list
# member 6180bb4ed903d97d is healthy: got healthy result from http://192.168.0.11:2379
# member 72db4918d259f94e is healthy: got healthy result from http://192.168.0.12:2379
# member aca3b8b90ab8cfc8 is healthy: got healthy result from http://192.168.0.13:2379
# cluster is healthy