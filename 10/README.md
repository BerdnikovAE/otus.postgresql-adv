# ДЗ 10. Multi master

Создадим CockroachDB на VM в Yandex Cloud, закачаем туда что-нибудь и сравним на таких же объемах с postgresql

``` sh

# сделаем несколько виртуалок 
for i in $(seq -f "%02g" 1 1); do \
yc compute instance create \
  --cores 2 \
  --memory 2 \
  --create-boot-disk size=15G,type=network-ssd,image-folder-id=standard-images,image-family=ubuntu-2004-lts \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --zone ru-central1-a \
  --preemptible \
  --metadata-from-file ssh-keys=/home/ae/.ssh/id_ed25519.txt \
  --name cdb$i \
  --hostname cdb$i \
  --async
    done;





```