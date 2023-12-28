sudo apt install -y awscli

aws configure
# AWS Access Key ID [****************HjV9]:
# AWS Secret Access Key [****************laI2]:
# Default region name [None]: ru-central1
# Default output format [None]:

alias ycs3='aws s3 --endpoint-url=https://storage.yandexcloud.net'

ycs3 ls
ycs3 ls sensors-db
ycs3 cp test-file s3://sensors-db/test-file

ycs3 ls sensors-db
# 2023-11-05 21:01:36          5 test-file

