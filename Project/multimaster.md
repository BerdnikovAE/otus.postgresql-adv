multimaster — это расширение Postgres Pro Enterprise, которое в сочетании с набором доработок ядра превращает Postgres Pro Enterprise в синхронный кластер без разделения ресурсов, который обеспечивает масштабируемость OLTP для читающих транзакций, а также высокую степень доступности с автоматическим восстановлением после сбоев.

Операционная система Microsoft Windows не поддерживается.

Решения 1С по ряду причин не поддерживаются.

multimaster может реплицировать только одну базу данных в кластере. Если требуется реплицировать содержимое нескольких баз данных, вы можете либо перенести все данные в разные схемы одной базы данных, либо создать для каждой базы отдельный кластер и настроить multimaster в каждом из этих кластеров.

``` sh

shared_preload_libraries = 'multimaster'

wal_level = logical
max_connections = 100
max_prepared_transactions = 300 # max_connections * N
max_wal_senders = 10            # как минимум N
max_replication_slots = 10      # как минимум 2N
wal_sender_timeout = 0

max_worker_processes = 250 # (N - 1) * (max_connections + 3) + 3

#etcd
cluster is healthy
9f79bd8cbb090fed: name=etcd-03 peerURLs=http://192.168.0.13:2380 clientURLs=http://192.168.0.13:2379 isLeader=false
ab28f612fac9cd5e: name=etcd-02 peerURLs=http://192.168.0.12:2380 clientURLs=http://192.168.0.12:2379 isLeader=false
ccf520eb1d8aac51: name=etcd-01 peerURLs=http://192.168.0.11:2380 clientURLs=http://192.168.0.11:2379 isLeader=true

# patroni
+ Cluster: pg_patroni (7325984515973847232) ----+----+-----------+
| Member   | Host         | Role    | State     | TL | Lag in MB |
+----------+--------------+---------+-----------+----+-----------+
| pgsql-01 | 192.168.0.21 | Leader  | running   |  1 |           |
| pgsql-02 | 192.168.0.22 | Replica | streaming |  1 |         0 |
| pgsql-03 | 192.168.0.23 | Replica | streaming |  1 |         0 |
+----------+--------------+---------+-----------+----+-----------+

```

``` sql 
\c pooltest

CREATE EXTENSION multimaster;

SELECT mtm.init_cluster('dbname=pooltest user=pooltest host=b-pg-01',
'{"dbname=pooltest user=pooltest host=b-pg-02", "dbname=pooltest user=pooltest host=b-pg-03"}');

SELECT * FROM mtm.status();
SELECT * FROM mtm.nodes();


```
