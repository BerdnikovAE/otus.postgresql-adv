# ДЗ 12. Работа c PostgreSQL в Kubernetes

Развернем в Yandex Managed Service for Kubernetes CitusDB 

```sh
# создадим Kubernates в YC руками в GUI

# спросим реквизиты подключения 
yc managed-kubernetes cluster list
#+----------------------+------+---------------------+-----------+--------------+-------------------------+---------------------+
#|          ID          | NAME |     CREATED AT      |  HEALTH   |    STATUS    |    EXTERNAL ENDPOINT    |  INTERNAL ENDPOINT  |
#+----------------------+------+---------------------+-----------+--------------+-------------------------+---------------------+
#| cat6ah5f184i25sojota | kb2  | 2023-12-28 10:06:38 | UNHEALTHY | PROVISIONING | https://158.160.105.229 | https://10.128.0.29 |
#+----------------------+------+---------------------+-----------+--------------+-------------------------+---------------------+

yc managed-kubernetes cluster get-credentials kb2 --external --force

kubectl cluster-info
#Kubernetes control plane is running at https://51.250.79.158
#CoreDNS is running at https://51.250.79.158/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
#To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

kubectl get all
#NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
#service/kubernetes   ClusterIP   10.96.128.1   <none>        443/TCP   3m46s

cd citusdb
kubectl apply -f .
#configmap/entrypoint created
#persistentvolumeclaim/citus-master-pvc created
#service/citus-master created
#statefulset.apps/citus-master created
#secret/citus-secrets created
#service/citus-workers created
#statefulset.apps/citus-worker created

kubectl get all
# NAME                 READY   STATUS    RESTARTS   AGE
# pod/citus-master-0   1/1     Running   0          106s
# pod/citus-worker-0   1/1     Running   0          105s
# pod/citus-worker-1   1/1     Running   0          71s
# pod/citus-worker-2   1/1     Running   0          42s

# NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
# service/citus-master    ClusterIP   10.96.152.34   <none>        5432/TCP   106s
# service/citus-workers   ClusterIP   None           <none>        5432/TCP   106s
# service/kubernetes      ClusterIP   10.96.128.1    <none>        443/TCP    11m

# NAME                            READY   AGE
# statefulset.apps/citus-master   1/1     106s
# statefulset.apps/citus-worker   3/3     105s

# подключимся к мастеру
kubectl exec -it pod/citus-master-0 -- bash

# проверим, что рабочие ноды добавились к мастеру
psql -U postgres
SELECT * FROM master_get_active_worker_nodes();
#          node_name           | node_port
#------------------------------+-----------
# citus-worker-2.citus-workers |      5432
# citus-worker-0.citus-workers |      5432
# citus-worker-1.citus-workers |      5432
#(3 rows)


# зайдем на master и скачаем данные 
kubectl exec -it pod/citus-master-0 -- bash

apt update
apt install -y awscli

aws configure
# AWS Access Key ID [****************HjV9]:
# AWS Secret Access Key [****************laI2]:
# Default region name [None]: ru-central1
# Default output format [None]:

alias ycs3='aws s3 --endpoint-url=https://storage.yandexcloud.net'

ycs3 cp s3://sensors-db/file-100.csv.zip file-100.csv
#download: s3://sensors-db/file-100.csv.zip to ./file-100.csv

psql -U postgres 
```

``` sql
-- как обычно таблички сделаем 

CREATE TYPE t_sensor AS ENUM ('BME280', 'BMP180', 'BMP280', 'DHT22', 'DS18B20', 'HPM', 'HTU21D', 'PMS1003', 'PMS3003', 'PMS5003', 'PMS6003', 'PMS7003', 'PPD42NS', 'SDS011');
CREATE TABLE sensors
(
    sensor_id integer,
    sensor_type t_sensor,
    location integer,
    lat real,
    lon real,
    timestamp timestamp,
    P1 real,
    P2 real,
    P0 real,
    durP1 real,
    ratioP1 real,
    durP2 real,
    ratioP2 real,
    pressure real,
    altitude real,
    pressure_sealevel real,
    temperature real,
    humidity real    
);

-- сделаем табличку распределенной
SELECT create_distributed_table('sensors', 'sensor_id');

-- загрузим данные в БД
\copy sensors from 'file-100.csv' WITH DELIMITER ',' CSV quote '"'
--COPY 100000000

-- включим тайминг
\timing

-- первый уже привычный запрос + все предыдущие резуультаты для сравнения
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
# postgres       -- Time: 216423.353 ms (03:36.423)
# CockroachDB    -- Time: 142.412s total (execution 142.412s / network 0.000s)
# Greenplum      -- Time: 5401.526 ms
# CitusDB YC k8s -- Time: 109026.862 ms (01:49.027)

SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
# postgres       -- Time: 128721.572 ms (02:08.722)
# CockroachDB    -- Time: 102.802s total (execution 102.801s / network 0.000s)
# Greenplum      -- Time: 7142.630 ms
# CitusDB YC k8s -- Time: 62055.982 ms (01:02.056)

-- что там происходит на самом деле ? 
postgres=# explain
postgres-# SELECT
postgres-#     sensor_type,
postgres-#     avg(temperature)
postgres-# FROM sensors
postgres-# GROUP BY sensor_type;
                                                            QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=750.00..753.50 rows=200 width=12)
   Group Key: remote_scan.sensor_type
   ->  Custom Scan (Citus Adaptive)  (cost=0.00..0.00 rows=100000 width=16)
         Task Count: 32
         Tasks Shown: One of 32
         ->  Task
               Node: host=citus-worker-0.citus-workers port=5432 dbname=postgres
               ->  Finalize GroupAggregate  (cost=62613.87..62616.45 rows=10 width=16)
                     Group Key: sensor_type
                     ->  Gather Merge  (cost=62613.87..62616.20 rows=20 width=16)
                           Workers Planned: 2
                           ->  Sort  (cost=61613.85..61613.87 rows=10 width=16)
                                 Sort Key: sensor_type
                                 ->  Partial HashAggregate  (cost=61613.58..61613.68 rows=10 width=16)
                                       Group Key: sensor_type
                                       ->  Parallel Seq Scan on sensors_102008 sensors  (cost=0.00..52278.19 rows=1244719 width=8)
(16 rows)
Time: 103.204 ms

```

``` sh
yc managed-kubernetes cluster delete kb2
```


