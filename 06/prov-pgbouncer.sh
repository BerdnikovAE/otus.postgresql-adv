####################
# pgbouncer
####################
sudo apt install -y pgbouncer

cat << EOF | sudo tee /etc/pgbouncer/pgbouncer.ini
[databases]
* = host=localhost port=5432

[pgbouncer]
logfile = /var/log/postgresql/pgbouncer.log
pidfile = /var/run/postgresql/pgbouncer.pid

listen_addr = *
listen_port = 6432
unix_socket_dir = /var/run/postgresql

auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

pool_mode = transaction
max_client_conn = 1000
default_pool_size = 70
EOF

cat << EOF | sudo tee /etc/pgbouncer/userlist.txt
"admin" "admin-321"
EOF

# запустим 
sudo systemctl restart pgbouncer

# проверим 
export PGPASSWORD=admin-321
psql -U admin -d postgres -h localhost -p 6432 -c "select now()" -w

