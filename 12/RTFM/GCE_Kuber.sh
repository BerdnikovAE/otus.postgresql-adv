-- создаем вручную кластер, смотрим на параметры
-- --cluster-version "1.21.5-gke.1302" (21/11/18)
-- need to update in time
-- ERROR: (gcloud.beta.container.clusters.create) ResponseError: code=400, message=Master version must be one of "REGULAR" channel supported versions [1.20.15-gke.8200, 1.21.12-gke.1500, 1.21.12-gke.1700, 1.22.8-gke.202, 1.23.5-gke.1501, 1.23.5-gke.1503].
-- --cluster-version "1.22.8-gke.202" (27/06/22)
-- --cluster-version "1.24.9-gke.3200" (22/03/23)
-- --cluster-version "1.25.7-gke.1000" (05/04/23)
-- "1.26.5-gke.1200" (08/23)
gcloud beta container --project "celtic-house-266612" clusters create "citus" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.27.3-gke.100" --release-channel "regular" --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "30" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --max-pods-per-node "110" --preemptible --num-nodes "3" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "projects/celtic-house-266612/global/networks/default" --subnetwork "projects/celtic-house-266612/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations "us-central1-c"

kubectl get all
-- error: The gcp auth plugin has been removed.
-- Please use the "gke-gcloud-auth-plugin" kubectl/client-go credential plugin instead.
-- See https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke for further details

-- посмотрим на портал с операторами
-- https://operatorhub.io/


gcloud container clusters list
kubectl get all
-- если делать через веб интерфейс ошибка, нужно переинициализировать кластер
-- так как мы делали кластер не через gcloud, доступ мы не получим
-- нужно прописать теперь контекст
-- https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl
gcloud container clusters get-credentials citus --zone us-central1-c

-- у ЯО
-- yc managed-kubernetes cluster get-credentials catnh4ppjut3hu3bofiv --external --force
-- приложил файл с разворачиванием кубика в ЯО

-- context switching
-- manual
-- https://linuxhint.com/kubectl-list-switch-context/
-- auto
-- https://github.com/alin-grecu/kubectlx

-- посмотрим дефолтный тип стораджа
kubectl get storageclasses
-- можем сделать свой - например для внешних дисков и т.д.

cd /mnt/d/download/pgGKE
-- создадим заявку на 1Gb
nano pvc-demo.yaml

kubectl apply -f pvc-demo.yaml
kubectl get pvc -o wide
kubectl get pv -o wide
kubectl describe pv pvc-demo

-- посмотрим диски в GCE
gcloud compute disks list


-- изменим на тип PV standard
kubectl delete -f pvc-demo.yaml

nano pvc-demo2.yaml

kubectl apply -f pvc-demo2.yaml

-- попробуем динамически увеличить размер до 10 Gb
nano pvc-demo2.yaml

-- kubectl create -f pvc-demo.yaml -- create на существующем манифесте не отработает, поэтому apply
kubectl apply -f pvc-demo2.yaml

kubectl get pvc -o wide
kubectl get pv -o wide
-- заявка на 1, а диск на 10 %)
-- почему так посмотрим дальше
kubectl delete -f pvc-demo.yaml


-- развернем кубик от Севералнайнс
-- https://severalnines.com/database-blog/using-kubernetes-deploy-postgresql

-- по умолчанию ReadWriteMany
-- не работает, поставим ReadWriteOnce и уберем маунт на локальный диск /mnt/data и убираем сторадж моде

nano postgres-configmap.yaml
-- диск на 1Gb
nano postgres-storage.yaml
-- 10.4 -> 14 postgres
nano postgres-deployment.yaml
nano postgres-service.yaml


kubectl apply -f postgres-configmap.yaml -f postgres-storage.yaml -f postgres-deployment.yaml -f postgres-service.yaml
-- не работает
-- error: unable to recognize "postgres-deployment.yaml": no matches for kind "Deployment" in version "extensions/v1beta1"
-- apiVersion: extensions/v1beta1  -> apps/v1
-- nano postgres-deployment.yaml
-- kubectl apply -f postgres-deployment.yaml

-- error: error validating "postgres-deployment.yaml": error validating data: ValidationError(Deployment.spec): 
-- missing required field "selector" in io.k8s.api.apps.v1.DeploymentSpec;
-- nano postgres-deployment.yaml

  selector:
    matchLabels:
      app: postgres

-- kubectl apply -f postgres-deployment.yaml

kubectl get all
-- почему под Постгреса имеет случайное имя?





kubectl exec -it pod/postgres-6f58774c8b-2rs5t bash
df
/dev/sdb 1гб
psql -U postgresadmin -d postgresdb
CREATE DATABASE test;

nano postgres-storage.yaml
-- увеличиваем до 10 Гб
-- cd /mnt/d/download/pgGKE

kubectl apply -f postgres-storage.yaml
kubectl get pvc -o wide
kubectl get pv -o wide
-- посмотрим, что изменилось
kubectl exec -it pod/postgres-6f58774c8b-2rs5t bash


df
-- раньше диск не автопровижнлся (октябрь 2021)
-- mount -f 
-- df

psql -U postgresadmin -d postgresdb
\l


-- для получения доступа
kubectl port-forward pod/postgres-6f6889c689-99ld9 5432:5432
-- или
kubectl port-forward service/postgres 5432:5432

-- пароль admin123 
-- psql -h localhost -U postgresadmin --password -p 5432 postgresdb
psql -U postgresadmin -d postgresdb -h localhost

-- посотрим на какую ноду уехал Постгрес
kubectl get nodes -o wide
kubectl get pods -o wide

-- посмотрим в GUI


-- Для доступа извне нужно юзать LoadBalancer. NodePort только для доступа изнутри GKE
kubectl get all
-- видим нет внешнего ip
-- посмотрим СТАРЫЙ сервис
nano postgres-service.yaml

-- посмотрим лоад балансер
nano postgres-service2.yaml
kubectl apply -f postgres-service2.yaml
kubectl get services
-- admin123
psql -h 34.172.216.203 -U postgresadmin --password -p 5432 postgresdb


kubectl delete all --all
-- не забываем про:
kubectl get pvc -o wide
kubectl get pv -o wide
kubectl get cm -o wide
kubectl get secrets -o wide
kubectl delete pvc --all
kubectl delete cm --all
kubectl delete secrets --all

kubectl delete all --all && kubectl delete ing --all && kubectl delete secrets --all && kubectl delete pvc --all && kubectl delete pv --all
-- ну или так)
kubectl delete all,ing,secrets,pvc,pv --all


-- настроим Citus руками в кубере
-- вспоминаем, что с нодами кластера
kubectl cluster-info
kubectl get nodes


-- Citus в кубере нет, но один китаец таки смог:
-- https://www.google.com/search?client=firefox-b-d&q=citus+kubernetes
-- https://github.com/aeuge/citus-k8s
-- образ старый 7.3.0, но не бесполезный
-- посмотрим скрипты
cd citus
nano secrets.yaml
nano master.yaml
nano workers.yaml

!!! не забываем указывать -n для переноса строки - посмотрим разницу
!!! echo 'otus321$' | base64
!!! echo -n 'otus321$' | base64
kubectl create -f secrets.yaml
kubectl create -f master.yaml
-- чуть позже запускаем, после создания мастера
-- есть вероятность, что kubectl apply -f . не отработает
kubectl get all
kubectl create -f workers.yaml

-- обратите внимание, что мастер имеет случайное название, на воркеры строго определенное
kubectl get all

kubectl exec -it pod/citus-master-796b6486b7-rghz7 -- bash
psql -U postgres
SELECT * FROM master_get_active_worker_nodes(); 
create database test;

-- Заапргейдим наш цитус, добавив лоад балансер и еще 1 ноду
kubectl delete -f .
kubectl get pvc
kubectl get secrets
gcloud compute disks list
cd ../citus_LB
kubectl create -f secrets.yaml
nano master.yaml
kubectl create -f master.yaml

kubectl apply -f workers.yaml

kubectl get all

-- посмотреть секреты
kubectl get secret citus-secrets -o yaml

-- пароль otus321$
-- посмотреть 
echo 'b3R1czMyMSQ=' | base64 -d


kubectl get service
psql -h 34.172.216.203 -U postgres --password -p 5432
-- почему нет БД test?

SELECT * FROM master_get_active_worker_nodes();


-- добавим еще 1 ноду, для этого просто отредактируем стейтфул сет
nano workers.yaml
kubectl apply -f workers.yaml


kubectl get all
psql -h 35.192.66.109 -U postgres --password -p 5432
SELECT * FROM master_get_active_worker_nodes();

-- удалим все
kubectl delete all,ing,secrets,pvc,pv --all


-- посмотрим на сборки Цитуса
-- https://hub.docker.com/r/citusdata/citus/

/* описание проблем

-- если мы просто удалим наш деплоймент kubectl delete -f . , pvc все равно остануться

-- после попыток развернуть 9.4.0 вернулся к 7.3.0
-- kubectl logs pod/citus-master-68959cc849-btn9l
-- 2020-08-18 10:26:24.838 UTC [1] FATAL:  DATABASE files are incompatible with server
-- 2020-08-18 10:26:24.838 UTC [1] DETAIL:  The data directory was initialized by PostgreSQL version 12, which is not compatible with this version 10.3 (Debian 10.3-1.pgdg90+1).
-- обязательно чистим pvc

-- 8.0 у меня собрана нормально

-- проблема в версии > 8.0.0 идет добавление по HOSTNAME, а там добавляется в образ хуки на постсоздание
-- и они не видят кластер, а так как контенер без хуков не заканчивает сборку, hostname тоже не получается
 if [ ${POD_IP} ]; then psql --host=citus-master --username=postgres 
 --command="SELECT * FROM master_add_node('${HOSTNAME}.citus-workers', 5432);" ; fi 

-- версия 9.3
-- поэтому сделал версию с заменой HOSTNAME на POD_IP
-- но нужно потом решить проблему со сменой ip - поменять имена нод


*/

-- потраим 10.1-pg12
cd ../citus_10.1pg12
kubectl create -f secrets.yaml
-- версия мастера - старый образ citusdata/citus:7.3.0 
nano master.yaml
kubectl create -f master.yaml
nano workers.yaml
kubectl apply -f workers.yaml

kubectl get all

kubectl exec -it pod/citus-master-796b6486b7-p6gvt -- bash
psql -U postgres
SELECT * FROM master_get_active_worker_nodes();
-- psql (10.3 (Debian 10.3-1.pgdg90+1))



-- варианты загрузки в citus - внутри контейнера
mkdir /home/1
chmod 777 /home/1
cd /home/1
apt-get update
apt-get install wget
wget https://storage.googleapis.com/postgres13/1000000SalesRecords.csv

psql -U postgres
CREATE TABLE test (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    Region VARCHAR(50),
    Country VARCHAR(50),
    ItemType VARCHAR(50),
    SalesChannel VARCHAR(20),
    OrderPriority VARCHAR(10),
    OrderDate VARCHAR(10),
    OrderID int,
    ShipDate VARCHAR(10),
    UnitsSold int,
    UnitPrice decimal(12,2),
    UnitCost decimal(12,2),
    TotalRevenue decimal(12,2),
    TotalCost decimal(12,2),
    TotalProfit decimal(12,2)
);
-- 2 вариант -- до версии 9.5 (версия citus)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE test (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v1(),
    Region VARCHAR(50),
    Country VARCHAR(50),
    ItemType VARCHAR(50),
    SalesChannel VARCHAR(20),
    OrderPriority VARCHAR(10),
    OrderDate VARCHAR(10),
    OrderID int,
    ShipDate VARCHAR(10),
    UnitsSold int,
    UnitPrice decimal(12,2),
    UnitCost decimal(12,2),
    TotalRevenue decimal(12,2),
    TotalCost decimal(12,2),
    TotalProfit decimal(12,2)
);

\timing
SELECT create_distributed_table('test', 'id');
-- ERROR:  function public.uuid_generate_v1() does not exist
kubectl exec -it pod/citus-worker-0 -- psql -U postgres -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
kubectl exec -it pod/citus-worker-1 -- psql -U postgres -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
kubectl exec -it pod/citus-worker-2 -- psql -U postgres -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

copy test (Region,Country,ItemType,SalesChannel,OrderPriority,OrderDate,OrderID,ShipDate,UnitsSold,UnitPrice,UnitCost,TotalRevenue,TotalCost,TotalProfit) FROM '/home/1/1000000SalesRecords.csv' DELIMITER ',' CSV HEADER;
-- или клиент сайд 
-- \copy test (Region,Country,ItemType,SalesChannel,OrderPriority,OrderDate,OrderID,ShipDate,UnitsSold,UnitPrice,UnitCost,TotalRevenue,TotalCost,TotalProfit) FROM '/home/1/1000000SalesRecords.csv' DELIMITER ',' CSV HEADER;

-- вариант с координатором на 10.1
nano master2.yaml
kubectl delete -f master.yaml
kubectl apply -f master2.yaml

kubectl get all

kubectl exec -it pod/citus-master-9f8945476-tgkrl -- bash
psql -U postgres
SELECT * FROM master_get_active_worker_nodes();
SELECT * from master_add_node('citus-worker-0.citus-workers', 5432);
SELECT * from master_add_node('citus-worker-1.citus-workers', 5432);
SELECT * from master_add_node('citus-worker-2.citus-workers', 5432);
SELECT rebalance_table_shards('test');

SELECT * FROM pg_dist_shard;

-- зайдем на сегменты
kubectl exec -it pod/citus-worker-0 -- bash
psql -U postgres
select * from test;
\dt

-- удалим все
kubectl delete all,ing,secrets,pvc,pv --all


-- посмотрим на версию от Алексея
cd ../Alexey10.1pg12
ls -l




gcloud container clusters delete citus --zone us-central1-c
--посмотрим, что осталось от кластера
gcloud compute disks list

