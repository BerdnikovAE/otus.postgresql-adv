
####################
# patroni
####################

sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters


# остановим и дропнем сущсетвующий кластер postgresql
# sudo systemctl stop postgresql 
sudo -u postgres pg_dropcluster 15 main --stop
sudo systemctl daemon-reload
# проверим 
pg_lsclusters

# ставим patroni
sudo apt install -y python3 python3-pip
sudo pip3 install psycopg2-binary 
sudo pip3 install patroni[etcd]

sudo ln -s /usr/local/bin/patroni  /bin/patroni

# сервисный файлик делаем для patroni
cat << EOF | sudo tee /etc/systemd/system/patroni.service
[Unit]
Description=High availability PostgreSQL Cluster
After=syslog.target network.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/postgres0.yml
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF


sudo mkdir /etc/patroni

# patroni config 
# тут пример https://github.com/zalando/patroni/blob/master/postgres0.yml
cat << EOF | sudo tee /etc/patroni/postgres0.yml
scope: pg_patroni
#namespace: /service/
name: $(hostname)

restapi:
  listen: $(hostname -I | awk '{print $NF}'):8008
  connect_address: $(hostname -I | awk '{print $NF}'):8008
#  cafile: /etc/ssl/certs/ssl-cacert-snakeoil.pem
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  authentication:
#    username: username
#    password: password

#ctl:
#  insecure: false # Allow connections to Patroni REST API without verifying certificates
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  cacert: /etc/ssl/certs/ssl-cacert-snakeoil.pem

#citus:
#  database: citus
#  group: 0  # coordinator

etcd:
  #Provide host to do the initial discovery of the cluster topology:
  hosts: 192.168.0.11:2379,192.168.0.12:2379,192.168.0.13:2379
  #Or use "hosts" to provide multiple endpoints
  #Could be a comma separated string:
  #hosts: host1:port1,host2:port2
  #or an actual yaml list:
  #hosts:
  #- host1:port1
  #- host2:port2
  #Once discovery is complete Patroni will use the list of advertised clientURLs
  #It is possible to change this behavior through by setting:
  #use_proxies: true

#raft:
#  data_dir: .
#  self_addr: 127.0.0.1:2222
#  partner_addrs:
#  - 127.0.0.1:2223
#  - 127.0.0.1:2224

bootstrap:
  # this section will be written into Etcd:/<namespace>/<scope>/config after initializing new cluster
  # and all other cluster members will use it as a `global configuration`
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
#    primary_start_timeout: 300
#    synchronous_mode: false
    #standby_cluster:
      #host: 127.0.0.1
      #port: 1111
      #primary_slot_name: patroni
    postgresql:
      use_pg_rewind: true
      pg_hba:
      # For kerberos gss based connectivity (discard @.*$)
      #- host replication replicator 127.0.0.1/32 gss include_realm=0
      #- host all all 0.0.0.0/0 gss include_realm=0
       - host replication replicator 192.168.0.0/24 md5
       - host all all 192.168.0.0/24 md5
       - host all all 127.0.0.1/32 md5
#      - host replication replicator 127.0.0.1/32 md5
#      - host all all 0.0.0.0/0 md5
      #  - hostssl all all 0.0.0.0/0 md5
#      use_slots: true
      parameters:
#        wal_level: hot_standby
#        hot_standby: "on"
#        max_connections: 100
#        max_worker_processes: 8
#        wal_keep_segments: 8
#        max_wal_senders: 10
#        max_replication_slots: 10
#        max_prepared_transactions: 0
#        max_locks_per_transaction: 64
#        wal_log_hints: "on"
#        track_commit_timestamp: "off"
#        archive_mode: "on"
#        archive_timeout: 1800s
#        archive_command: mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f
#      recovery_conf:
#        restore_command: cp ../wal_archive/%f %p

  # some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - data-checksums

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

  # Some additional users which needs to be created after initializing new cluster
  users:
    admin:
      password: admin-321
      options:
        - createrole
        - createdb

postgresql:
  listen: 127.0.0.1, $(hostname -I | awk '{print $NF}'):5432
  connect_address: $(hostname -I | awk '{print $NF}'):5432

#  proxy_address: 127.0.0.1:5433  # The address of connection pool (e.g., pgbouncer) running next to Patroni/Postgres. Only for service discovery.
  data_dir: /var/lib/postgresql/15/main
  bin_dir: /usr/lib/postgresql/15/bin
#  config_dir:
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: rep-pass-321
    superuser:
      username: postgres
      password: zalando-321
    rewind:  # Has no effect on postgres 10 and lower
      username: rewind_user
      password: rewind_password-321
  # Server side kerberos spn
#  krbsrvname: postgres
  parameters:
    # Fully qualified kerberos ticket file for the running user
    # same as KRB5CCNAME used by the GSS
#   krb_server_keyfile: /var/spool/keytabs/postgres
    unix_socket_directories: '..'  # parent directory of data_dir
  # Additional fencing script executed after acquiring the leader lock but before promoting the replica
  #pre_promote: /path/to/pre_promote.sh

#watchdog:
#  mode: automatic # Allowed values: off, automatic, required
#  device: /dev/watchdog
#  safety_margin: 5

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
EOF

sudo systemctl start patroni 

patronictl -c /etc/patroni/postgres0.yml list
