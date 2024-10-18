# How to connect to docker container hosting on ecs

ecs exec --task <task id> --container redis-master --interactive --tty -- /bin/bash
aws ecs execute-command --region ap-east-1 --cluster prometheus-cluster --task <task id full> --container redis-master --interactive --command "/bin/sh"

command to check replicas in redis
INFO replication

aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 792248914698.dkr.ecr.ap-northeast-2.amazonaws.com