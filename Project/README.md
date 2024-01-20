
Установка PostgreSQL Pro  в отказоусточивой конфигурации: etcd+Patroni

Делать будем на VirtualBox + Vagrant из под Windows

Вот [Vagrantfile](Vagrantfile) для развертывания всех виртуалок:
- 3 x etcd, провижинится скриптом [prov-etcd.sh](prov-etcd.sh)
- 3 x (postgresql + patroni), провижинится скриптом [prov-patroni.sh](prov-patroni.sh)  
- 1 x haproxy провижинится скриптом [prov-haproxy.sh](prov-haproxy.sh)
- 1 x client, там просто ставим ```postgresql-client```

``` ps1
# запустим vm для etcd
vagrant up etcd-01 etcd-02 etcd-03

# запустим etcd
1..3 | %{ vagrant ssh etcd-0$_ -c 'sudo systemctl start etcd --no-block'}

# помотрим что живое 
vagrant ssh etcd-01 -c 'etcdctl cluster-health && etcdctl member list'

#member 9f79bd8cbb090fed is healthy: got healthy result from http://192.168.0.13:2379
#member ab28f612fac9cd5e is healthy: got healthy result from http://192.168.0.12:2379
#member ccf520eb1d8aac51 is healthy: got healthy result from http://192.168.0.11:2379
#cluster is healthy
#9f79bd8cbb090fed: name=etcd-03 peerURLs=http://192.168.0.13:2380 clientURLs=http://192.168.0.13:2379 isLeader=false
#ab28f612fac9cd5e: name=etcd-02 peerURLs=http://192.168.0.12:2380 clientURLs=http://192.168.0.12:2379 isLeader=false
#ccf520eb1d8aac51: name=etcd-01 peerURLs=http://192.168.0.11:2380 clientURLs=http://192.168.0.11:2379 isLeader=true

# теперь стартуем posgtresql + patroni + pgbouncer
vagrant up pgsql-01 pgsql-02 pgsql-03

# проверить
vagrant ssh pgsql-01 -c 'patronictl -c /etc/patroni/postgres0.yml list'
#+ Cluster: pg_patroni (7292699511657715095) ----+----+-----------+
#| Member   | Host         | Role    | State     | TL | Lag in MB |
#+----------+--------------+---------+-----------+----+-----------+
#| pgsql-01 | 192.168.0.21 | Leader  | running   |  3 |           |
#| pgsql-02 | 192.168.0.22 | Replica | streaming |  3 |         0 |
#| pgsql-03 | 192.168.0.23 | Replica | streaming |  3 |         0 |
#+----------+--------------+---------+-----------+----+-----------+

# haproxy 
vagrant up haproxy-01 haproxy-02 

# посмотрим журнал - все правильно пишет: pgsql-02, pgsql-03 is DOWN
vagrant ssh haproxy-01 -c 'sudo journalctl -u haproxy.service --since today --no-pager'
#Oct 22 09:56:18 haproxy-01 systemd[1]: Starting HAProxy Load Balancer... --> -->
#Oct 22 09:56:18 haproxy-01 haproxy[5097]: [NOTICE]   (5097) : haproxy version is 2.5.14-1ppa1~focal
#Oct 22 09:56:18 haproxy-01 haproxy[5097]: [NOTICE]   (5097) : path to executable is /usr/sbin/haproxy
#Oct 22 09:56:18 haproxy-01 haproxy[5097]: [WARNING]  (5097) : config : proxy 'postgres_read' uses http-check rules without 'option httpchk', so the rules are ignored.
#Oct 22 09:56:18 haproxy-01 haproxy[5097]: [NOTICE]   (5097) : New worker (5109) forked
#Oct 22 09:56:18 haproxy-01 haproxy[5097]: [NOTICE]   (5097) : Loading success.
#Oct 22 09:56:18 haproxy-01 systemd[1]: Started HAProxy Load Balancer.
#Oct 22 09:56:20 haproxy-01 haproxy[5109]: [WARNING]  (5109) : Server postgres_write/pgsql-02 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable", check duration: 4ms. 2 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
#Oct 22 09:56:22 haproxy-01 haproxy[5109]: [WARNING]  (5109) : Server postgres_write/pgsql-03 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable", check duration: 4ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.

vagrant up client

# проверим куда подключаемся с client
vagrant ssh client
export PGPASSWORD=admin-321; psql -U admin -d postgres -h 192.168.0.31 -p 5000 -c "\conninfo"
#You are connected to database "postgres" as user "admin" on host "192.168.0.31" at port "5000".
# \conninfo показывает адрес haproxy, надо смотреть на 
export PGPASSWORD=admin-321; psql -U admin -d postgres -h 192.168.0.31 -p 5000 -c "SELECT reset_val FROM pg_settings WHERE name='listen_addresses'"
#        reset_val
#-------------------------
# 127.0.0.1, 192.168.0.21
#(1 row)

# Всё правильно видим 21 хост 

# Выглядит будто норм, но делаем switchover, успешно
vagrant ssh pgsql-01 -c 'patronictl -c /etc/patroni/postgres0.yml switchover'
#+ Cluster: pg_patroni (7292699511657715095) ----+----+-----------+
#| Member   | Host         | Role    | State     | TL | Lag in MB |
#+----------+--------------+---------+-----------+----+-----------+
#| pgsql-01 | 192.168.0.21 | Replica | streaming |  4 |         0 |
#| pgsql-02 | 192.168.0.22 | Replica | streaming |  4 |         0 |
#| pgsql-03 | 192.168.0.23 | Leader  | running   |  4 |           |
#+----------+--------------+---------+-----------+----+-----------+

# смотрим что заметил haproxy, да:  03 - UP, 01 - DOWN
vagrant ssh haproxy-01 -c 'sudo journalctl -u haproxy.service --since today --no-pager'
#Oct 22 10:02:42 haproxy-01 haproxy[5109]: [WARNING]  (5109) : Server postgres_write/pgsql-03 is UP, reason: Layer7 check passed, code: 200, check duration: 2ms. 2 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
#Oct 22 10:02:49 haproxy-01 haproxy[5109]: [WARNING]  (5109) : Server postgres_write/pgsql-01 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable", check duration: 6ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.

# смотрим с клиента где мы 
export PGPASSWORD=admin-321; psql -U admin -d postgres -h 192.168.0.31 -p 5000 -c "SELECT reset_val FROM pg_settings WHERE name='listen_addresses'"
#        reset_val
#-------------------------
# 127.0.0.1, 192.168.0.22
#(1 row)

# ПЕРЕКЛЮЧИЛОСЬ!
```




