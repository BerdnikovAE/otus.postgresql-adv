####################
# HAProxy
####################

sudo apt install -y --no-install-recommends software-properties-common && sudo add-apt-repository -y ppa:vbernat/haproxy-2.5 && sudo apt install -y haproxy=2.5.\*

# мастер ответит 200, другеи 503
# curl -v http://192.168.0.21:8008/master
# curl -v http://192.168.0.22:8008/master
# curl -v http://192.168.0.23:8008/master

cat << EOF | sudo tee /etc/haproxy/haproxy.cfg
defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s    

listen postgres_write
    bind *:5000
    mode            tcp
    option httpchk
    http-check connect
    http-check send meth GET uri /master
    http-check expect status 200
    default-server inter 10s fall 3 rise 3 on-marked-down shutdown-sessions
    server pgsql-01 192.168.0.21:6432 check port 8008
    server pgsql-02 192.168.0.22:6432 check port 8008
    server pgsql-03 192.168.0.23:6432 check port 8008

listen postgres_read
    bind *:5001
    mode            tcp
    http-check connect
    http-check send meth GET uri /replica
    http-check expect status 200
    default-server inter 10s fall 3 rise 3 on-marked-down shutdown-sessions
    server pgsql-01 192.168.0.21:6432 check port 8008
    server pgsql-02 192.168.0.22:6432 check port 8008
    server pgsql-03 192.168.0.23:6432 check port 8008
EOF

sudo systemctl restart haproxy.service
sudo systemctl status haproxy.service

#sudo cat /var/log/haproxy.log

