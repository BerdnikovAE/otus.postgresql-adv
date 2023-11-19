# ДЗ 12. Работа c PostgreSQL в Kubernetes

Развернем в Yandex Managed Service for Kubernetes CitusDB 

```sh
# развернем кластер в YC

kubectl exec -it pod/citus-master-0 -- bash


# зайдем на master и скачаем данные 

kubectl exec -it pod/citus-master-0 -- bash
psql -U postgres 
```

``` sql
-- как обычно таблички сделаем 

-- сделаем табличку распределенной
SELECT create_distributed_table('sensors', 'sensor_id');

-- загрузим данные в БД
\copy sensors from 'file-100.csv.zip' WITH DELIMITER ',' CSV quote '"'

```


