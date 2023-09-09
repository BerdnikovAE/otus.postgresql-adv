# ДЗ 01: Работа с уровнями изоляции транзакции в PostgreSQL


## Подготовка облака 
``` sh
# install yc cli на debian  
sudo apt install curl -y
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
source ~/.bashrc

yc init

yc compute instance create \
  --cores 2 \
  --memory 4 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2204-lts \
  --network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
  --zone ru-central1-b \
  --metadata-from-file ssh-keys=.ssh/y \
  --name pg \
  --hostname pg

# коннектимся
# обратить внимание что имя пользователя все равно ubuntu, несмотря на содержимое файла .ssh/yc.txt
ssh -i ~/.ssh/y ubuntu@xx.xx.xx.xx

sudo -u postgres psql
```  

## Устанавливаем 15 postgresql
``` sh
sudo apt update && \
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && \
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet --no-check-certificate -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc && \
sudo apt-get update && \
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-15
# проверим 
pg_lsclusters
```

## Играемся с транзакциями 
``` sql
sudo -u postgres psql

-- session 1
\echo :AUTOCOMMIT
ON
\set AUTOCOMMIT OFF
create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov');
insert into persons(first_name, second_name) values('petr', 'petrov');
commit;
show transaction isolation level; 
 transaction_isolation
-----------------------
 read committed
 (1 row)
insert into persons(first_name, second_name) values('sergey', 'sergeev');


-- session 2
select * from persons;
 id | first_name | second_name
----+------------+-------------
  6 | ivan       | ivanov
  7 | petr       | petrov
(2 rows)
-- не видим, так и правильно "read committed"

-- session 1
commit;

-- session 2
select * from persons;
 id | first_name | second_name
----+------------+-------------
  6 | ivan       | ivanov
  7 | petr       | petrov
  9 | sergey     | sergeev
(3 rows)
-- видим, тоже ок. 

-- session 1
set transaction isolation level repeatable read;
commit;

-- session 2
set transaction isolation level repeatable read;
commit;

-- session 1
insert into persons(first_name, second_name) values('sveta', 'svetova');

-- session 2
select * from persons;
 id | first_name | second_name
----+------------+-------------
  6 | ivan       | ivanov
  7 | petr       | petrov
  9 | sergey     | sergeev
(3 rows)
-- не видим, т.к. в первой сессии нет коммита, да и тут мы в транзакции

-- session 1
commit;

-- session 2
select * from persons;
 id | first_name | second_name
----+------------+-------------
  6 | ivan       | ivanov
  7 | petr       | petrov
  9 | sergey     | sergeev
(3 rows)
-- не видим, т.к. у нас тут транзакция, а мы в "repeatable read"
commit;
select * from persons;
 id | first_name | second_name
----+------------+-------------
 11 | ivan       | ivanov
 12 | petr       | petrov
 13 | sergey     | sergeev
 14 | sveta      | svetova
(4 rows)
-- теперь видим!
-- Вывод: всё правильно - в режиме repeatable read мы НЕ видим "Неповторяемое чтение", т.е. видим в свой транзакции данные которые были зафиксированы до начала транзакции.

```

``` sh
# удалить виртуалку не забыть 
yc compute instance delete pg
```



>>>>>>> cbc9aa3d7cbc0cc702fbd1af8e5e9b3bdb246c38

