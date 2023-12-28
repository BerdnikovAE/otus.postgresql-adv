# ДЗ 07. Постгрес в minikube


``` sh

# поставим в  windows minikude
choco install minikube
minikube start --vm-driver=virtualbox --no-vtx-check 
minikube status
minikube version 

# создадим namespace и переключимся в него 
kubectl create namespace pg
kubectl config set-context --current --namespace=pg

# пароль запомним и внесем в секреты 
echo -n 'password' | base64
cGFzc3dvcmQ=
```

yaml файлы:
- [postgresql-secret.yaml](my/postgresql-secret.yaml)
- [postgresql-statefulset.yaml](my/postgresql-statefulset.yaml)

``` sh
# разворачиваем 
kubectl apply -f my/postgresql-secret.yaml
kubectl apply -f my/postgresql-statefulset.yaml

# посмотрим порт 
minikube service postgres --url -n pg
#http://192.168.59.101:31571

# подключимся 
psql.exe -h 192.168.59.101 -p 31571 -d mydb -U myuser
mydb=#

# и чего-нибудь создадим
mydb=# create table T1 (i int);
CREATE TABLE
mydb=# insert into t1 (i) values (123);
INSERT 0 1

# удалим и новый сделаем 
kubectl delete -f my/postgresql-statefulset.yaml
kubectl apply -f my/postgresql-statefulset.yaml

# port?
minikube service postgres --url -n pg
#http://192.168.59.101:30714

# смотрим что все на месте 
.\psql.exe -h 192.168.59.101 -p 30714 -d mydb -U myuser
mydb=# select * from t1;
  i
-----
 123
(1 row)

# удалим всё
kubectl delete namespace pg
#kubectl delete -f my/postgresql-secret.yaml
#kubectl delete -f my/postgresql-statefulset.yaml

```




``` sh
choco install postgresql --ia '--enable-components commandlinetools'

```