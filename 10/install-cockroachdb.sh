
# установка на всех нодах
for i in $(seq -f "cdb%02g" 1 3); do \
    v=$i 
cat << EOF | ssh ubuntu@${!v}
wget -qO- https://binaries.cockroachdb.com/cockroach-v23.1.11.linux-amd64.tgz | \
tar  xvz && sudo cp -i cockroach-v23.1.11.linux-amd64/cockroach /usr/local/bin/ && \
sudo mkdir -p /opt/cockroach && \
sudo chown ubuntu:ubuntu /opt/cockroach
EOF
done;


# генерим сертификаты на cdb01
ssh ubuntu@$cdb01
mkdir certs my-safe-directory
cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key 
cockroach cert create-node $(seq -f "cdb%02g" 1 3) --certs-dir=certs --ca-key=my-safe-directory/ca.key --overwrite
cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key --overwrite
cockroach cert list --certs-dir=certs

# скопируем везде 
cd ~
mkdir certs-for-cdb
scp ubuntu@$cdb01:/home/ubuntu/certs/* /home/ae/certs-for-cdb/
for i in $(seq -f "cdb%02g" 1 3); do \
    v=$i    
    ssh ubuntu@${!v} mkdir /home/ubuntu/certs
    scp certs-for-cdb/* ubuntu@${!v}:/home/ubuntu/certs
    done;

# стартанем везде
for i in $(seq -f "cdb%02g" 1 3); do \
    v=$i    
cat << EOF | ssh ubuntu@${!v}
cockroach start --certs-dir=certs --advertise-addr=$i --join=$i --cache=.25 --max-sql-memory=.25 --background
cockroach init --certs-dir=certs --host=$i
EOF
    done;

for i in $(seq -f "cdb%02g" 1 3); do \
    v=$i    
cat << EOF 
cockroach start --certs-dir=certs --advertise-addr=$i --join=$i --cache=.25 --max-sql-memory=.25 --background
cockroach init --certs-dir=certs --host=$i
EOF
    done;



ssh ubuntu@$cdb01 cockroach node status --host=cdb01 --certs-dir=certs

# далее руками подключаемся к первой ноде 
ssh ubuntu@$cdb01
cockroach sql --certs-dir=certs --host=cdb01 


CREATE TABLE if not exists items (itemname varchar(128) primary key, price decimal(19,4), quantity int);
import INTO items (itemname, price, quantity) CSV DATA ('gs://postgres13/cockroachdb.csv') WITH DELIMITER = E'\t';

-- ERROR: Get "https://storage.googleapis.com/postgres13/cockroachdb.csv": metadata: GCE metadata "instance/service-accounts/default/token?scopes=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdevstorage.read_write" not defined
-- https://www.cockroachlabs.com/docs/v21.2/import-into.html
-- https://www.cockroachlabs.com/docs/v21.2/use-cloud-storage-for-bulk-operations
-- enable ?AUTH=implicit
import INTO items (itemname, price, quantity) CSV DATA ('gs://postgres13/cockroachdb.csv?AUTH=implicit') WITH DELIMITER = E'\t';

-- не работает
IMPORT INTO test (Region,Country,ItemType,SalesChannel,OrderPriority,OrderDate,OrderID,ShipDate,UnitsSold,UnitPrice,UnitCost,TotalRevenue,TotalCost,TotalProfit) CSV DATA ('gs://postgres13/1000000SalesRecords.csv?AUTH=implicit') WITH DELIMITER = ',', SKIP = '1';

-- вот так работает)
IMPORT INTO 
sensors
   ( sensor_id ,
    sensor_type ,
    location ,
    lat ,
    lon ,
    timestamp ,
    P1 ,
    P2 ,
    P0 ,
    durP1 ,
    ratioP1 ,
    durP2 ,
    ratioP2 ,
    pressure ,
    altitude ,
    pressure_sealevel ,
    temperature ,
    humidity)    
CSV DATA ('https://clickhouse-public-datasets.s3.eu-central-1.amazonaws.com/sensors/monthly/2019-06_bmp180.csv.zst') WITH DELIMITER = ',', SKIP = '1';


x
https://clickhouse-public-datasets.s3.eu-central-1.amazonaws.com/sensors/monthly/2023-*.zst

CREATE TABLE test (
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
    TotalProfit decimal(12,2));
