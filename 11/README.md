# ДЗ 11. Parallel cluster

## Разворачиваем Greenplum. 
Буду делать всё на локальном компьютере в VirtualBox.

Готовим 7 виртуалок:
    - master 
    - standy 
    - 4 x server-segment
    - psql client 

Все виртуалки провижинятся скриптом [install_greenplum.sh](install_greenplum.sh) 

``` sh
# поднимаем всё
vagrant up 

# на всех хостах чтоб добавилось 
1..4 | %{ vagrant ssh gp-0$_ -c 'cat /vagrant/*.pub | sudo tee /home/gpadmin/.ssh/authorized_keys && sudo chown gpadmin:gpadmin /home/gpadmin/.ssh/authorized_keys' }


# подключимся к master-у 
vagrant ssh gp-01

#sudo -u gpadmin
mkdir /home/gpadmin/gpconfigs
cp $GPHOME/docs/cli_help/gpconfigs/gpinitsystem_config /home/gpadmin/gpconfigs/gpinitsystem_config

nano /home/gpadmin/gpconfigs/gpinitsystem_config

cd ~
# проверим что связь со всеми хостами есть 
gpssh -f hostfile_exkeys -e 'ls -la /opt/greenplum-db-*'

# инициируем greenplum
gpinitsystem -c gpconfigs/gpinitsystem_config -h hostfile_gpinitsystem -s gp-02 --mirror-mode=spread




```



