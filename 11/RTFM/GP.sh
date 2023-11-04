REPO="/etc/apt/sources.list.d/greenplum-ubuntu-db-bionic.list"
PIN="/etc/apt/preferences.d/99-greenplum"

echo "Add required repositories"
cat << EOF | sudo tee $REPO
deb http://ppa.launchpad.net/greenplum/db/ubuntu bionic main
deb http://ru.archive.ubuntu.com/ubuntu bionic main
EOF

echo "Configure repositories"
cat << EOF | sudo tee $PIN 
Package: *
Pin: release v=18.04
Pin-Priority: 1
EOF

sudo apt update && apt install greenplum-db-6 -y