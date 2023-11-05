
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

# create monitor 
sudo -u postgres pg_autoctl create monitor \
    --auth trust \
    --ssl-self-signed \
    --pgdata /var/lib/postgresql/ha \
    --pgctl /usr/lib/postgresql/15/bin/pg_ctl

# monitor to systemd
pg_autoctl -q show systemd --pgdata /var/lib/postgresql/ha > pgautofailover.service
sudo mv pgautofailover.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable pgautofailover
sudo systemctl start pgautofailover

# что где ? 
sudo -u postgres pg_autoctl show state --pgdata /var/lib/postgresql/ha

