
# https://pg-auto-failover.readthedocs.io/en/main/azure-tutorial.html#azure-tutorial

# repo 
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update

# cli + postgresql
sudo apt-get install -y postgresql-common
echo 'create_main_cluster = false' | sudo tee -a /etc/postgresql-common/createcluster.conf
sudo apt-get install -y postgresql-15-auto-failover

# create postgresql
sudo -u postgres pg_autoctl create postgres \
    --pgdata /var/lib/postgresql/ha \
    --auth trust \
    --ssl-self-signed \
    --dbname testapp \
    --hostname $HOSTNAME \
    --pgctl /usr/lib/postgresql/15/bin/pg_ctl \
    --monitor 'postgres://autoctl_node@pgmon/pg_auto_failover?sslmode=require'

# to systemd
pg_autoctl -q show systemd --pgdata /var/lib/postgresql/ha > pgautofailover.service
sudo mv pgautofailover.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable pgautofailover
sudo systemctl start pgautofailover

# не будем заморачиваться (это для подключения с клиентов)
echo "host all all all trust" | sudo tee -a /var/lib/postgresql/ha/pg_hba.conf
sudo -u postgres psql -c "SELECT pg_reload_conf();"


