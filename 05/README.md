# ДЗ 04. Бэкапы Постгреса



``` sh
# ставим postgres 15 
sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters


# установка pg_probackup 
sudo sh -c 'echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb/ $(lsb_release -cs) main-$(lsb_release -cs)" > /etc/apt/sources.list.d/pg_probackup.list'
sudo wget -O - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG_PROBACKUP | sudo apt-key add - && sudo apt-get update
sudo apt-get install -y pg-probackup-15
sudo apt-get install -y pg-probackup-15-dbg
sudo apt-get install -y postgresql-15-pg-checksums

# можно сразу на будущее включить checksum 
sudo systemctl stop postgresql@15-main
sudo /usr/lib/postgresql/15/bin/pg_checksums -D /var/lib/postgresql/15/main --enable
sudo systemctl start postgresql@15-main


# созданипе пользователя и настройка прав 
cat << EOL | sudo -u postgres psql
BEGIN;
CREATE ROLE backup WITH LOGIN;
GRANT USAGE ON SCHEMA pg_catalog TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_is_in_recovery() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_start(text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_stop(boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_create_restore_point(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_switch_wal() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_last_wal_replay_lsn() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current_snapshot() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_snapshot_xmax(txid_snapshot) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_checkpoint() TO backup;
COMMIT;
EOL

# создадим папку 
sudo mkdir /var/pg_backup && sudo chmod 777 /var/pg_backup

# инициализация 
sudo -u postgres pg_probackup-15 init -B /var/pg_backup
sudo -u postgres pg_probackup-15 add-instance --instance 'main' -D /var/lib/postgresql/15/main -B /var/pg_backup
sudo -u postgres pg_probackup-15 show-config --instance main -B /var/pg_backup


# создадим чего-нибудь 
cat << EOL |sudo -u postgres psql
CREATE DATABASE test;
\c test
CREATE TABLE t1 (id int, name char(10));
INSERT INTO t1 (id, name) values (1,'111');
INSERT INTO t1 (id, name) values (2,'222');
INSERT INTO t1 (id, name) values (3,'333');
EOL
sudo -u postgres psql -c "select * from t1;" -d test

# сделаем первый ПОЛНЫЙ бэкап
sudo -u postgres pg_probackup-15 backup --instance 'main' -b FULL --stream --temp-slot -B /var/pg_backup

# внесем изменения 
cat << EOL |sudo -u postgres psql -d test
INSERT INTO t1 (id, name) values (4,'444');
EOL
sudo -u postgres psql -c "select * from t1;" -d test

# сделаем первый ИНКРЕМЕНТ бэкап
sudo -u postgres pg_probackup-15 backup --instance 'main' -b DELTA --stream --temp-slot -B /var/pg_backup

# ПРОВЕРИМ/ВОССТАНОВИМ
# сделаем новый инстанс 
sudo pg_createcluster 15 main2
sudo rm -rf /var/lib/postgresql/15/main2
pg_lsclusters
#Ver Cluster Port Status Owner    Data directory               Log file
#15  main    5432 online postgres /var/lib/postgresql/15/main  /var/log/postgresql/postgresql-15-main.log
#15  main2   5433 down   postgres /var/lib/postgresql/15/main2 /var/log/postgresql/postgresql-15-main2.log

# восстановим FULL
sudo -u postgres pg_probackup-15 restore --instance 'main' -i 'S2OI2A' -D /var/lib/postgresql/15/main2 -B /var/pg_backup
sudo systemctl start postgresql@15-main2
sudo -u postgres psql -c "select * from t1;" -d test -p 5433
# id |    name
#----+------------
#  1 | 111
#  2 | 222
#  3 | 333
#(3 rows)

# восстановим DELTA
sudo systemctl stop postgresql@15-main2
sudo rm -rf /var/lib/postgresql/15/main2
sudo systemctl start postgresql@15-main2
sudo -u postgres psql -c "select * from t1;" -d test -p 5433
# id |    name
#----+------------
#  1 | 111
#  2 | 222
#  3 | 333
#  4 | 444
#(4 rows)
```

ВСЁ РАБОТАЕТ

