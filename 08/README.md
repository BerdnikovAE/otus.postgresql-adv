# ДЗ 07. Разворачиваем и настраиваем БД с большими данными

Буду делать всё на локальном компьютере в VirtualBox (CPU Ryzen 5 3600 + SATA Disk)

## Разворачиваем clickhouse 

``` sh
sudo apt-get install -y apt-transport-https ca-certificates dirmngr
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee \
    /etc/apt/sources.list.d/clickhouse.list
sudo apt-get update

sudo apt-get install -y clickhouse-server clickhouse-client

sudo service clickhouse-server start
clickhouse-client 
```

Заливаем в clickhouse данные из Environmental Sensors Data https://clickhouse.com/docs/en/getting-started/example-datasets/environmental-sensors

``` sql
-- готовим табличку 
CREATE TABLE sensors
(
    sensor_id UInt16,
    sensor_type Enum('BME280', 'BMP180', 'BMP280', 'DHT22', 'DS18B20', 'HPM', 'HTU21D', 'PMS1003', 'PMS3003', 'PMS5003', 'PMS6003', 'PMS7003', 'PPD42NS', 'SDS011'),
    location UInt32,
    lat real,
    lon real,
    timestamp DateTime,
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
    humidity real,
    date Date MATERIALIZED toDate(timestamp)
)
ENGINE = MergeTree
ORDER BY (timestamp, sensor_id);

-- копируем данные за 2023 год 
INSERT INTO sensors
    SELECT *
    FROM s3Cluster(
        'default',
        'https://clickhouse-public-datasets.s3.eu-central-1.amazonaws.com/sensors/monthly/2023-*.zst',
        'CSVWithNames',
        $$ sensor_id UInt16,
        sensor_type String,
        location UInt32,
        lat real,
        lon real,
        timestamp DateTime,
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
        humidity real $$
    )
SETTINGS
    format_csv_delimiter = ';',
    input_format_allow_errors_ratio = '0.5',
    input_format_allow_errors_num = 10000,
    input_format_parallel_parsing = 0,
    date_time_input_format = 'best_effort',
    max_insert_threads = 32,
    parallel_distributed_insert_select = 1;

-- ↙ Progress: 286.62 million rows, 3.48 GB (899.84 thousand rows/s., 10.92 MB/s.)   (1.1 CPU, 296.57 MB RAM) 34% 

-- 0 rows in set. Elapsed: 979.096 sec. Processed 730.24 million rows, 9.99 GB (745.83 thousand rows/s., 10.20 MB/s.)
-- Peak memory usage: 1.25 GiB.


-- сколько места занято ? 

SELECT
    disk_name,
    formatReadableSize(sum(data_compressed_bytes) AS size) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes) AS usize) AS uncompressed,
    round(usize / size, 2) AS compr_rate,
    sum(rows) AS rows,
    count() AS part_count
FROM system.parts
WHERE (active = 1) AND (table = 'sensors')
GROUP BY
    disk_name
ORDER BY size DESC;

-- ┌─disk_name─┬─compressed─┬─uncompressed─┬─compr_rate─┬──────rows─┬─part_count─┐
-- │ default   │ 13.76 GiB  │ 25.50 GiB    │       1.85 │ 730237511 │         25 │
-- └───────────┴────────────┴──────────────┴────────────┴───────────┴────────────┘

-- 730 млн.строк

-- со стороны файловой системы так же +-

-- $ sudo du -d 1 -h /var/lib/clickhouse
-- 36K     /var/lib/clickhouse/data
-- 4.0K    /var/lib/clickhouse/user_scripts
-- 4.0K    /var/lib/clickhouse/user_files
-- 4.0K    /var/lib/clickhouse/metadata_dropped
-- 4.0K    /var/lib/clickhouse/flags
-- 88K     /var/lib/clickhouse/preprocessed_configs
-- 4.0K    /var/lib/clickhouse/dictionaries_lib
-- 28K     /var/lib/clickhouse/metadata
-- 33G     /var/lib/clickhouse/store
-- 24K     /var/lib/clickhouse/access
-- 4.0K    /var/lib/clickhouse/named_collections
-- 62M     /var/lib/clickhouse/tmp
-- 4.0K    /var/lib/clickhouse/user_defined
-- 4.0K    /var/lib/clickhouse/format_schemas
-- 33G     /var/lib/clickhouse

-- запускаем зпрос 
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;

-- ответ готов за 8 секунд после ребута и за 0.8 сек. в повторе 

-- 14 rows in set. Elapsed: 0.900 sec. Processed 730.24 million rows, 730.24 MB (811.48 million rows/s., 811.48 MB/s.)
-- Peak memory usage: 4.22 MiB.

-- раз задача переносы данных - переносим 
-----------------------------------------

-- в CSV
SELECT * FROM sensors INTO OUTFILE '/home/ae/export.csv' TRUNCATE
-- ↑ Progress: 39.84 million rows, 1.51 GB (617.92 thousand rows/s., 23.39 MB/s.)             (0.1 CPU, 13.89 MB RAM) 5%

-- 730237511 rows in set. Elapsed: 1537.599 sec. Processed 730.24 million rows, 25.89 GB (474.92 thousand rows/s., 16.84 MB/s.)
-- Peak memory usage: 23.81 MiB.

ls -lah export.csv
-- -rwxrwxrwx 1 ae ae 61G Oct 28 19:53 export.csv

-- позже этот файл импортируем через copy в postgres 
```

## Приготовим postgresql

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

Делаем табличку в postgres 

``` sql
-- postgres 
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
)


-- импорт 
\copy sensors from '/home/ae/export.csv' WITH DELIMITER ',' CSV quote '"'
-- подглялываем за прогрессом в другом окне, сколько гигов обработано 
select bytes_processed/1000000000 from pg_stat_progress_copy;

-- включим время
\timing
-- после импорта обновим статистику 
ANALYZE;


SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;

-- дождаться было нереально, сделал заливку в postgres 100 млн. записей только 
SELECT * FROM sensors LIMIT 100000000 INTO OUTFILE '/home/ae/export-100.csv' TRUNCATE

-- объем БД на диске 12 Гигов
sudo du -d 0 -h /var/lib/postgresql
-- 12G     /var/lib/postgresql


-- только для 100 млн. записей (т.е. 1/7 от clickhouse)
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;

-- Time: 230131.601 ms (03:50.132)

-- может индекс как-то поможет
CREATE INDEX ix_sensort_type ON sensors (sensor_type);

-- повторяем запрос 
SELECT
    sensor_type,
    count(*)
FROM sensors
GROUP BY sensor_type;
-- Time: 3114.434 ms (00:03.114)
-- помним, что это только на 100 млн. 

-- чуть сложней запросик: 
SELECT
    sensor_type,
    avg(temperature)
FROM sensors
GROUP BY sensor_type;
-- и время улетает
-- Time: 220521.156 ms (03:40.521)
-- повторный запуск не лучше
-- Time: 219933.376 ms (03:39.933)

-- на clickhouse такой же запрос на 730 млн 
-- 14 rows in set. Elapsed: 43.014 sec. Processed 730.24 million rows, 3.02 GB (16.98 million rows/s., 70.15 MB/s.)
-- Peak memory usage: 9.87 MiB.

-- clickhouse - огонь
```

