# How to connect to docker container hosting on ecs

ecs exec --task <task id> --container redis-master --interactive --tty -- /bin/bash
aws ecs execute-command --region ap-east-1 --cluster prometheus-cluster --task <task id full> --container redis-master --interactive --command "/bin/bash"

command to check replicas in redis
INFO replication